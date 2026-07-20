---@class Sops
local M = {
	auto_edit = true,
}

local decrypted_prefix = ".decrypted~"
local sops_markers = { "ENC[AES256_GCM", "lastmodified", "mac", "version" }

---@return boolean
function M.is_decrypted()
	local bufnr = vim.api.nvim_get_current_buf()
	local path = vim.api.nvim_buf_get_name(bufnr)
	if vim.startswith(vim.fs.basename(path), decrypted_prefix) then
		vim.b[bufnr].sops = "decrypted"
		return true
	end
	return false
end

---@return boolean
function M.is_encrypted()
	local bufnr = vim.api.nvim_get_current_buf()
	local path = vim.api.nvim_buf_get_name(bufnr)
	local seen = {}

	if path == "" then
		return false
	end

	if vim.bo[bufnr].buftype ~= "" then
		return false
	end

	for _, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, -50, -1, false)) do
		for _, marker in ipairs(sops_markers) do
			if not seen[marker] and line:find(marker, 1, true) then
				seen[marker] = true

				if vim.tbl_count(seen) == #sops_markers then
					local file_status = vim.system({ "sops", "filestatus", path }, { stdout = false, stderr = false })
						:wait()
					if file_status.code == 0 then
						vim.b[bufnr].sops = "encrypted"
						return true
					end
					return false
				end
			end
		end
	end

	return false
end

function M.edit()
	local bufnr_encrypted = vim.api.nvim_get_current_buf()
	local path_encrypted = vim.api.nvim_buf_get_name(bufnr_encrypted)

	local path_decrypted = vim.fs.joinpath(
		vim.fs.dirname(path_encrypted),
		("%s%s"):format(decrypted_prefix, vim.fs.basename(path_encrypted))
	)
	local decrypt_result = vim.system({ "sops", "-d", "--output", path_decrypted, path_encrypted }, { text = true })
		:wait()
	if decrypt_result.code ~= 0 then
		vim.notify(decrypt_result.stderr, vim.log.levels.ERROR)
		return
	end

	vim.cmd.edit(vim.fn.fnameescape(path_decrypted))

	local bufnr_decrypted = vim.api.nvim_get_current_buf()
	local group = vim.api.nvim_create_augroup("SopsDecryptedBuffer" .. bufnr_decrypted, { clear = true })

	vim.b[bufnr_decrypted].sops_encrypted_path = path_encrypted
	vim.b[bufnr_decrypted].sops_modified = false

	vim.api.nvim_buf_delete(bufnr_encrypted, {})

	vim.api.nvim_create_autocmd("BufWritePre", {
		group = group,
		buffer = bufnr_decrypted,
		callback = function()
			vim.b[bufnr_decrypted].sops_modified = vim.bo[bufnr_decrypted].modified
		end,
	})

	vim.api.nvim_create_autocmd("BufWritePost", {
		group = group,
		buffer = bufnr_decrypted,
		callback = function()
			if not vim.b[bufnr_decrypted].sops_modified then
				return
			end

			local encrypt_result = vim.system({ "sops", path_encrypted }, {
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

			vim.b[bufnr_decrypted].sops_modified = false
		end,
	})

	vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
		group = group,
		buffer = bufnr_decrypted,
		callback = function()
			vim.fs.rm(path_decrypted, { force = true })
			pcall(vim.api.nvim_del_augroup_by_id, group)
		end,
	})

	vim.api.nvim_create_autocmd("QuitPre", {
		group = group,
		callback = function()
			if vim.bo[bufnr_decrypted].modified and vim.v.cmdbang ~= 1 then
				return
			end

			vim.fs.rm(path_decrypted, { force = true })
			pcall(vim.api.nvim_del_augroup_by_id, group)
			pcall(vim.api.nvim_buf_delete, bufnr_decrypted, { force = vim.v.cmdbang == 1 })
		end,
	})
end

---@param opts table?
function M.enable(opts)
	M.auto_edit = true

	if opts and opts.bang then
		M.edit()
	end
end

---@param opts table?
function M.disable(opts)
	M.auto_edit = false

	if opts and opts.bang then
		local bufnr = vim.api.nvim_get_current_buf()
		local path_encrypted = vim.b[bufnr].sops_encrypted_path
		vim.api.nvim_buf_delete(bufnr, { force = true })
		vim.cmd.edit(vim.fn.fnameescape(path_encrypted))
	end
end

function M.setup()
	vim.api.nvim_create_user_command("SopsEdit", M.edit, {
		desc = "Edit current sops file via temporary decrypted file",
	})

	vim.api.nvim_create_user_command("SopsEnable", M.enable, {
		bang = true,
		desc = "Enable sops automatic decryption",
	})

	vim.api.nvim_create_user_command("SopsDisable", M.disable, {
		bang = true,
		desc = "Disable sops automatic decryption",
	})

	vim.api.nvim_create_autocmd("BufReadPost", {
		nested = true,
		group = vim.api.nvim_create_augroup("SopsAutoEdit", { clear = true }),
		callback = function()
			if M.is_decrypted() then
				return
			end

			if not M.is_encrypted() then
				return
			end

			if not M.auto_edit then
				return
			end

			M.edit()
		end,
		desc = "Open sops files decrypted automatically",
	})
end

return M
