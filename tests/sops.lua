vim.opt.rtp:append(".")

local sops = require("sops")

local function test(name, fn)
	local ok, err = xpcall(fn, debug.traceback)
	if not ok then
		error(("FAILED %s\n%s"):format(name, err))
	end
end

local function same(expected, actual)
	assert(vim.deep_equal(expected, actual), ("expected %s, got %s"):format(vim.inspect(expected), vim.inspect(actual)))
end

local function with_buf(lines, fn)
	local bufnr = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
	local ok, err = xpcall(function()
		fn(bufnr)
	end, debug.traceback)
	if vim.api.nvim_buf_is_valid(bufnr) then
		vim.api.nvim_buf_delete(bufnr, { force = true })
	end
	assert(ok, err)
end

local function make_tmpdir()
	local tmpdir = vim.fn.tempname()
	vim.fn.mkdir(tmpdir, "p")
	return tmpdir
end

local function write_executable(path, lines)
	vim.fn.writefile(lines, path)
	vim.fn.setfperm(path, "rwx------")
end

local function sops_lines()
	return {
		"sops:",
		"  mac: ENC[AES256_GCM,data:example]",
		"  version: 3.10.2",
		"  lastmodified: 2026-07-20T00:00:00Z",
		"  unencrypted_suffix: _unencrypted",
		"  age:",
		"    - recipient: age1example",
	}
end

test("uses defaults", function()
	sops.setup()

	same(true, sops.config.auto_edit)
	same("sops", sops.config.command)
	same(".decrypted~", sops.config.decrypted_prefix)
end)

test("accepts custom config", function()
	sops.setup({
		auto_edit = false,
		command = "custom-sops",
		decrypted_prefix = ".plain~",
	})

	same(false, sops.config.auto_edit)
	same("custom-sops", sops.config.command)
	same(".plain~", sops.config.decrypted_prefix)
end)

test("enables and disables automatic editing without changing the buffer", function()
	sops.setup({
		auto_edit = false,
	})

	vim.cmd.SopsEnable()
	same(true, sops.config.auto_edit)

	vim.cmd.SopsDisable()
	same(false, sops.config.auto_edit)
end)

test("detects encrypted sops content", function()
	local tmpdir = make_tmpdir()
	local encrypted = tmpdir .. "/secret.yaml"
	local command = tmpdir .. "/sops"

	write_executable(command, {
		"#!/bin/sh",
		'if [ "$1" = "filestatus" ]; then',
		"  exit 0",
		"fi",
		"exit 1",
	})
	vim.fn.writefile(sops_lines(), encrypted)

	local ok, err = xpcall(function()
		sops.setup({
			auto_edit = false,
			command = command,
		})

		vim.cmd.edit(encrypted)
		same(true, sops.is_decryptable(0, encrypted))
	end, debug.traceback)

	vim.cmd.enew({ bang = true })
	vim.fs.rm(tmpdir, { force = true, recursive = true })
	assert(ok, err)
end)

test("rejects ordinary content", function()
	with_buf({
		"password: plain-text",
		"metadata: value",
	}, function(bufnr)
		same(false, sops.is_decryptable(bufnr, ""))
	end)
end)

test("rejects source files that mention sops fixtures", function()
	with_buf({
		'local fixture = "password: ENC[AES256_GCM,data:example]"',
		'local metadata = "sops:"',
	}, function(bufnr)
		same(false, sops.is_decryptable(bufnr, ""))
	end)
end)

test("rejects marker match when filestatus fails", function()
	local tmpdir = make_tmpdir()
	local encrypted = tmpdir .. "/secret.yaml"
	local command = tmpdir .. "/sops"

	write_executable(command, {
		"#!/bin/sh",
		'if [ "$1" = "filestatus" ]; then',
		"  exit 1",
		"fi",
		"exit 1",
	})
	vim.fn.writefile(sops_lines(), encrypted)

	local ok, err = xpcall(function()
		sops.setup({
			auto_edit = false,
			command = command,
		})

		vim.cmd.edit(encrypted)
		same(false, sops.is_decryptable(0, encrypted))
	end, debug.traceback)

	vim.cmd.enew({ bang = true })
	vim.fs.rm(tmpdir, { force = true, recursive = true })
	assert(ok, err)
end)

test("writes the decrypted buffer back through sops", function()
	vim.opt.swapfile = false

	local tmpdir = make_tmpdir()
	local encrypted = tmpdir .. "/secret.yaml"
	local command = tmpdir .. "/sops"

	write_executable(command, {
		"#!/bin/sh",
		'if [ "$1" = "filestatus" ]; then',
		"  exit 0",
		"fi",
		'if [ "$1" = "-d" ]; then',
		'  cp "$4" "$3"',
		"  exit 0",
		"fi",
		'eval "$SOPS_EDITOR \\"$1\\""',
	})
	vim.fn.writefile(sops_lines(), encrypted)

	local ok, err = xpcall(function()
		sops.setup({
			auto_edit = false,
			command = command,
		})

		vim.cmd.edit(encrypted)
		vim.cmd.SopsEdit()
		vim.api.nvim_buf_set_lines(0, 0, -1, false, { "password: changed" })
		vim.cmd.write()

		same({ "password: changed" }, vim.fn.readfile(encrypted))
	end, debug.traceback)

	vim.cmd.enew({ bang = true })
	vim.fs.rm(tmpdir, { force = true, recursive = true })
	assert(ok, err)
end)

test("enable decrypts the current encrypted buffer", function()
	local tmpdir = make_tmpdir()
	local encrypted = tmpdir .. "/secret.yaml"
	local command = tmpdir .. "/sops"

	write_executable(command, {
		"#!/bin/sh",
		'if [ "$1" = "filestatus" ]; then',
		"  exit 0",
		"fi",
		'if [ "$1" = "-d" ]; then',
		'  cp "$4" "$3"',
		"  exit 0",
		"fi",
		"exit 1",
	})
	vim.fn.writefile(sops_lines(), encrypted)

	local ok, err = xpcall(function()
		sops.setup({
			auto_edit = false,
			command = command,
		})

		vim.cmd.edit(encrypted)
		vim.cmd.SopsEnable()
		same(encrypted, vim.api.nvim_buf_get_name(0))

		vim.cmd.SopsEnable({ bang = true })

		same(true, sops.config.auto_edit)
		same(true, vim.startswith(vim.api.nvim_buf_get_name(0), tmpdir .. "/.decrypted~secret.yaml."))
	end, debug.traceback)

	vim.cmd.enew({ bang = true })
	vim.fs.rm(tmpdir, { force = true, recursive = true })
	assert(ok, err)
end)

test("disable closes decrypted buffer and opens encrypted file", function()
	local tmpdir = make_tmpdir()
	local encrypted = tmpdir .. "/secret.yaml"
	local decrypted
	local command = tmpdir .. "/sops"

	write_executable(command, {
		"#!/bin/sh",
		'if [ "$1" = "filestatus" ]; then',
		"  exit 0",
		"fi",
		'if [ "$1" = "-d" ]; then',
		'  cp "$4" "$3"',
		"  exit 0",
		"fi",
		"exit 1",
	})
	vim.fn.writefile(sops_lines(), encrypted)

	local ok, err = xpcall(function()
		sops.setup({
			auto_edit = false,
			command = command,
		})

		vim.cmd.edit(encrypted)
		vim.cmd.SopsEdit()
		decrypted = vim.api.nvim_buf_get_name(0)
		vim.cmd.SopsDisable()
		same(decrypted, vim.api.nvim_buf_get_name(0))

		vim.cmd.SopsDisable({ bang = true })

		same(false, sops.config.auto_edit)
		same(encrypted, vim.api.nvim_buf_get_name(0))
		same(0, vim.fn.filereadable(decrypted))
	end, debug.traceback)

	vim.cmd.enew({ bang = true })
	vim.fs.rm(tmpdir, { force = true, recursive = true })
	assert(ok, err)
end)

test("uses unique decrypted file names", function()
	local tmpdir = make_tmpdir()
	local encrypted = tmpdir .. "/secret.yaml"
	local command = tmpdir .. "/sops"

	write_executable(command, {
		"#!/bin/sh",
		'if [ "$1" = "-d" ]; then',
		'  cp "$4" "$3"',
		"  exit 0",
		"fi",
		"exit 1",
	})
	vim.fn.writefile(sops_lines(), encrypted)

	local ok, err = xpcall(function()
		sops.setup({
			auto_edit = false,
			command = command,
		})

		vim.cmd.edit(encrypted)
		vim.cmd.SopsEdit()
		local first = vim.api.nvim_buf_get_name(0)

		vim.cmd.edit(encrypted)
		vim.cmd.SopsEdit()

		same(false, first == vim.api.nvim_buf_get_name(0))
	end, debug.traceback)

	vim.cmd.enew({ bang = true })
	vim.fs.rm(tmpdir, { force = true, recursive = true })
	assert(ok, err)
end)

test("disable keeps modified decrypted buffer open and automatic editing enabled", function()
	local tmpdir = make_tmpdir()
	local encrypted = tmpdir .. "/secret.yaml"
	local command = tmpdir .. "/sops"

	write_executable(command, {
		"#!/bin/sh",
		'if [ "$1" = "filestatus" ]; then',
		"  exit 0",
		"fi",
		'if [ "$1" = "-d" ]; then',
		'  cp "$4" "$3"',
		"  exit 0",
		"fi",
		"exit 1",
	})
	vim.fn.writefile(sops_lines(), encrypted)

	local ok, err = xpcall(function()
		sops.setup({
			command = command,
		})

		vim.cmd.edit(encrypted)
		local decrypted = vim.api.nvim_buf_get_name(0)
		vim.api.nvim_buf_set_lines(0, 0, -1, false, { "password: changed" })
		vim.cmd.SopsDisable()

		same(true, sops.config.auto_edit)
		same(decrypted, vim.api.nvim_buf_get_name(0))
		same(true, vim.bo.modified)
	end, debug.traceback)

	vim.cmd.enew({ bang = true })
	vim.fs.rm(tmpdir, { force = true, recursive = true })
	assert(ok, err)
end)

test("manual edit decrypts without validation", function()
	local tmpdir = make_tmpdir()
	local encrypted = tmpdir .. "/secret.yaml"
	local command = tmpdir .. "/sops"
	local marker = tmpdir .. "/decrypt-called"

	write_executable(command, {
		"#!/bin/sh",
		'if [ "$1" = "filestatus" ]; then',
		"  exit 1",
		"fi",
		'if [ "$1" = "-d" ]; then',
		'  echo called > "' .. marker .. '"',
		"  exit 0",
		"fi",
		"exit 1",
	})
	vim.fn.writefile(sops_lines(), encrypted)

	local ok, err = xpcall(function()
		sops.setup({
			auto_edit = false,
			command = command,
		})

		vim.cmd.edit(encrypted)
		sops.edit()

		same(1, vim.fn.filereadable(marker))
	end, debug.traceback)

	vim.cmd.enew({ bang = true })
	vim.fs.rm(tmpdir, { force = true, recursive = true })
	assert(ok, err)
end)

test("automatic edit validates before decrypting", function()
	local tmpdir = make_tmpdir()
	local encrypted = tmpdir .. "/secret.yaml"
	local command = tmpdir .. "/sops"
	local marker = tmpdir .. "/decrypt-called"

	write_executable(command, {
		"#!/bin/sh",
		'if [ "$1" = "filestatus" ]; then',
		"  exit 1",
		"fi",
		'if [ "$1" = "-d" ]; then',
		'  echo called > "' .. marker .. '"',
		"  exit 0",
		"fi",
		"exit 1",
	})
	vim.fn.writefile(sops_lines(), encrypted)

	local ok, err = xpcall(function()
		sops.setup({
			command = command,
		})

		vim.cmd.edit(encrypted)

		same(0, vim.fn.filereadable(marker))
		same(encrypted, vim.api.nvim_buf_get_name(0))
	end, debug.traceback)

	vim.cmd.enew({ bang = true })
	vim.fs.rm(tmpdir, { force = true, recursive = true })
	assert(ok, err)
end)
