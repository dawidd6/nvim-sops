---@class SopsConfig
---@field auto_edit boolean Automatically decrypt SOPS files after reading them.
---@field command string SOPS executable name or path.
---@field decrypted_prefix string Prefix used for temporary decrypted files.

---@class Sops
---@field config SopsConfig
local M = {}

---@type SopsConfig
local defaults = {
	auto_edit = true,
	command = "sops",
	decrypted_prefix = ".decrypted~",
}

M.config = vim.tbl_extend("force", {}, defaults)

---@param path string
---@return boolean
function M.is_decrypted(path)
	return M.config.decrypted_prefix ~= "" and vim.startswith(vim.fs.basename(path), M.config.decrypted_prefix)
end

---@param bufnr integer
---@param path string
---@return boolean
function M.is_decryptable(bufnr, path)
	local seen = {}
	local sops_markers = { "lastmodified", "mac", "unencrypted_suffix", "version", "sops", "recipient" }

	if path == "" then
		return false
	end

	if vim.bo[bufnr].buftype ~= "" then
		return false
	end

	if M.is_decrypted(path) then
		return false
	end

	for _, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
		for _, marker in ipairs(sops_markers) do
			if not seen[marker] and line:find(marker, 1, true) then
				seen[marker] = true

				if vim.tbl_count(seen) == #sops_markers then
					local file_status = vim.system(
						{ M.config.command, "filestatus", path },
						{ stdout = false, stderr = false }
					)
						:wait()
					return file_status.code == 0
				end
			end
		end
	end

	return false
end

---@param bufnr integer?
---@param path string?
function M.edit(bufnr, path)
	if not bufnr then
		bufnr = vim.api.nvim_get_current_buf()
	end

	if not path then
		path = vim.api.nvim_buf_get_name(bufnr)
	end

	local path_decrypted = vim.fs.joinpath(
		vim.fs.dirname(path),
		("%s%s.%s.%s"):format(M.config.decrypted_prefix, vim.fs.basename(path), vim.uv.os_getpid(), vim.uv.hrtime())
	)
	local decrypt_result = vim.system({ M.config.command, "-d", "--output", path_decrypted, path }, { text = true })
		:wait()
	if decrypt_result.code ~= 0 then
		vim.notify(decrypt_result.stderr, vim.log.levels.ERROR)
		return
	end

	vim.cmd.edit(vim.fn.fnameescape(path_decrypted))

	local bufnr_decrypted = vim.api.nvim_get_current_buf()
	vim.b[bufnr_decrypted].sops_encrypted_path = path

	local group = vim.api.nvim_create_augroup("SopsDecryptedBuffer" .. bufnr_decrypted, { clear = true })
	local modified = false
	local cleanup = function()
		vim.fs.rm(path_decrypted, { force = true })
		pcall(vim.api.nvim_del_augroup_by_id, group)
	end

	vim.api.nvim_buf_delete(bufnr, {})

	vim.api.nvim_create_autocmd("BufWritePre", {
		group = group,
		buffer = bufnr_decrypted,
		callback = function()
			modified = vim.bo[bufnr_decrypted].modified
		end,
	})

	vim.api.nvim_create_autocmd("BufWritePost", {
		group = group,
		buffer = bufnr_decrypted,
		callback = function()
			if not modified then
				return
			end

			local encrypt_result = vim.system({ M.config.command, path }, {
				text = true,
				env = {
					SOPS_EDITOR = 'sh -c \'cat "$NVIM_SOPS_DECRYPTED_FILE_PATH" > "$1"\' sh',
					NVIM_SOPS_DECRYPTED_FILE_PATH = path_decrypted,
				},
			}):wait()

			if encrypt_result.code ~= 0 then
				vim.notify(encrypt_result.stderr, vim.log.levels.ERROR)
				return
			end

			modified = false
		end,
	})

	vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
		group = group,
		buffer = bufnr_decrypted,
		callback = cleanup,
	})

	vim.api.nvim_create_autocmd("QuitPre", {
		group = group,
		callback = function()
			if vim.bo[bufnr_decrypted].modified and vim.v.cmdbang ~= 1 then
				return
			end

			pcall(vim.api.nvim_buf_delete, bufnr_decrypted, { force = vim.v.cmdbang == 1 })
			cleanup()
		end,
	})
end

function M.enable()
	M.config.auto_edit = true

	local bufnr = vim.api.nvim_get_current_buf()
	local path = vim.api.nvim_buf_get_name(bufnr)
	if M.is_decryptable(bufnr, path) then
		M.edit(bufnr, path)
	end
end

function M.disable()
	local bufnr = vim.api.nvim_get_current_buf()
	local path = vim.api.nvim_buf_get_name(bufnr)
	if path == "" or not M.is_decrypted(path) then
		M.config.auto_edit = false
		return
	end

	if vim.bo[bufnr].modified then
		vim.notify("Cannot close modified sops decrypted buffer", vim.log.levels.WARN)
		return
	end

	M.config.auto_edit = false

	local encrypted = vim.b[bufnr].sops_encrypted_path
		or vim.fs.joinpath(vim.fs.dirname(path), vim.fs.basename(path):sub(#M.config.decrypted_prefix + 1))
	vim.cmd.enew()
	vim.cmd.edit(vim.fn.fnameescape(encrypted))
	vim.api.nvim_buf_delete(bufnr, { force = true })
end

---@param opts SopsConfig?
function M.setup(opts)
	M.config = vim.tbl_extend("force", {}, defaults, opts or {})

	vim.api.nvim_create_user_command("SopsEdit", function()
		M.edit()
	end, {
		desc = "Edit current sops file via temporary decrypted file",
	})

	vim.api.nvim_create_user_command("SopsEnable", M.enable, {
		desc = "Enable sops automatic decryption",
	})

	vim.api.nvim_create_user_command("SopsDisable", M.disable, {
		desc = "Disable sops automatic decryption",
	})

	vim.api.nvim_create_autocmd("BufReadPost", {
		nested = true,
		group = vim.api.nvim_create_augroup("SopsAutoEdit", { clear = true }),
		callback = function(args)
			if M.config.auto_edit and M.is_decryptable(args.buf, args.file) then
				M.edit(args.buf, args.file)
			end
		end,
		desc = "Open sops files decrypted automatically",
	})
end

return M
