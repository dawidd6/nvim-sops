local M = {}

M.root = vim.fn.getcwd()
M.fixtures = vim.fs.joinpath(M.root, "test", "fixtures")

function M.assert_eq(actual, expected, message)
	if not vim.deep_equal(actual, expected) then
		error((message or "assertion failed") .. ": " .. vim.inspect(actual) .. " ~= " .. vim.inspect(expected), 2)
	end
end

function M.setup()
	vim.opt.rtp:append(M.root)
	package.loaded.sops = nil

	local sops = require("sops")
	sops.setup()
	return sops
end

function M.reset()
	for _, command in ipairs({ "SopsEdit", "SopsEnable", "SopsDisable" }) do
		pcall(vim.api.nvim_del_user_command, command)
	end

	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_valid(bufnr) then
			pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
		end
	end
	vim.cmd.enew({ bang = true })
end

function M.tmpdir()
	local tmpdir = vim.fn.tempname()
	vim.fn.mkdir(tmpdir, "p")
	return tmpdir
end

function M.temp_file(name, lines)
	local tmpdir = M.tmpdir()
	local path = vim.fs.joinpath(tmpdir, name)
	vim.fn.writefile(lines, path)
	return path, tmpdir
end

function M.copy_fixture(name)
	local tmpdir = M.tmpdir()
	local path = vim.fs.joinpath(tmpdir, name)
	vim.fn.writefile(vim.fn.readfile(vim.fs.joinpath(M.fixtures, name)), path)
	return path, tmpdir
end

function M.marker_lines()
	return { "ENC[AES256_GCM", "lastmodified", "mac", "version" }
end

function M.capture_notify()
	local old_notify = vim.notify
	local messages = {}
	vim.notify = function(message, level)
		table.insert(messages, { message = message, level = level })
	end
	return messages, function()
		vim.notify = old_notify
	end
end

function M.fake_sops()
	local tmpdir = M.tmpdir()
	local bindir = vim.fs.joinpath(tmpdir, "bin")
	local calls = vim.fs.joinpath(tmpdir, "calls")
	local exe = vim.fs.joinpath(bindir, "sops")
	vim.fn.mkdir(bindir, "p")
	vim.fn.writefile({
		"#!/bin/sh",
		"printf '%s\\n' \"$*\" >> " .. vim.fn.shellescape(calls),
		'if [ "$1" = filestatus ]; then',
		'  [ "$NVIM_FAKE_FILESTATUS_FAIL" = 1 ] && exit 1',
		"  exit 0",
		"fi",
		'if [ "$1" = -d ]; then',
		'  [ "$NVIM_FAKE_DECRYPT_FAIL" = 1 ] && echo decrypt failed >&2 && exit 2',
		'  printf \'%s\\n\' "${NVIM_FAKE_DECRYPT_TEXT:-decrypted}" > "$3"',
		"  exit 0",
		"fi",
		'[ "$NVIM_FAKE_ENCRYPT_FAIL" = 1 ] && echo encrypt failed >&2 && exit 3',
		'cat "$NVIM_SOPS_DECRYPTED_FILE_PATH" > "$1"',
	}, exe)
	vim.fn.setfperm(exe, "rwxr-xr-x")

	local old_path = vim.env.PATH
	vim.env.PATH = bindir .. ":" .. vim.env.PATH

	return {
		calls = calls,
		cleanup = function()
			vim.env.PATH = old_path
			vim.env.NVIM_FAKE_FILESTATUS_FAIL = nil
			vim.env.NVIM_FAKE_DECRYPT_FAIL = nil
			vim.env.NVIM_FAKE_ENCRYPT_FAIL = nil
			vim.env.NVIM_FAKE_DECRYPT_TEXT = nil
			vim.fs.rm(tmpdir, { force = true, recursive = true })
		end,
	}
end

function M.read_calls(fake)
	if vim.fn.filereadable(fake.calls) == 0 then
		return {}
	end
	return vim.fn.readfile(fake.calls)
end

return M
