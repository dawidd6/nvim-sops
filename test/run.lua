vim.opt.rtp:append(".")
package.path = vim.fn.getcwd() .. "/?.lua;" .. vim.fn.getcwd() .. "/?/init.lua;" .. package.path

local helper = require("test.helper")
local target = vim.uv.fs_realpath("lua/sops.lua")
local hits = {}
local sources = {}

debug.sethook(function(_, line)
	local source = debug.getinfo(2, "S").source
	if sources[source] == nil then
		sources[source] = source:sub(1, 1) == "@" and vim.uv.fs_realpath(source:sub(2)) == target
	end
	if sources[source] then
		hits[line] = true
	end
end, "l")

local cases = {}
for name in vim.fs.dir("test/cases") do
	if name:match("%.lua$") then
		table.insert(cases, vim.fs.joinpath("test/cases", name))
	end
end
table.sort(cases)

local failures = {}
for _, case in ipairs(cases) do
	helper.reset()
	local ok, err = xpcall(function()
		dofile(case)()
	end, debug.traceback)
	helper.reset()

	if ok then
		io.stdout:write("ok " .. case .. "\n")
	else
		table.insert(failures, case .. "\n" .. err)
		io.stdout:write("not ok " .. case .. "\n")
	end
end

debug.sethook()

local target_lines = vim.fn.readfile("lua/sops.lua")
local countable = {}
for line_number, line in ipairs(target_lines) do
	local stripped = line:match("^%s*(.-)%s*$")
	if
		stripped ~= ""
		and not stripped:match("^%-%-")
		and not stripped:match("^[%},%)]+$")
		and not stripped:match("^[%w_]+%s*=")
		and stripped ~= "end"
	then
		countable[line_number] = true
	end
end

local hit, total = 0, 0
for line_number in pairs(countable) do
	total = total + 1
	if hits[line_number] then
		hit = hit + 1
	end
end

io.stdout:write(("coverage: %.1f%% (%d/%d lines)\n"):format(hit / total * 100, hit, total))

if #failures > 0 then
	error(table.concat(failures, "\n\n"))
end
