---@class Sops
local M = {
	auto_edit = true,
}

local sops_markers = { "ENC[AES256_GCM", "lastmodified", "mac", "version" }

---@return boolean
function M.is_decrypted()
	local bufnr = vim.api.nvim_get_current_buf()
	return vim.b[bufnr].sops == "d"
end

---@return boolean
function M.is_encrypted()
	local bufnr = vim.api.nvim_get_current_buf()
	local path = vim.api.nvim_buf_get_name(bufnr)
	local seen = {}

	if vim.b[bufnr].sops == "e" then
		vim.b[bufnr].sops = nil
	end

	if path == "" then
		return false
	end

	if vim.bo[bufnr].buftype ~= "" then
		return false
	end

	for _, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, -51, -1, false)) do
		for _, marker in ipairs(sops_markers) do
			if not seen[marker] and line:find(marker, 1, true) then
				seen[marker] = true

				if vim.tbl_count(seen) == #sops_markers then
					local file_status = vim.system({ "sops", "filestatus", path }, { text = true, stderr = false })
						:wait()
					local ok, status = pcall(vim.json.decode, file_status.stdout or "")
					if file_status.code == 0 and ok and type(status) == "table" and status.encrypted == true then
						vim.b[bufnr].sops = "e"
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
	if M.is_decrypted() then
		return
	end

	local bufnr = vim.api.nvim_get_current_buf()
	local path = vim.api.nvim_buf_get_name(bufnr)
	local decrypt_result = vim.system({ "sops", "-d", path }, { text = true }):wait()
	if decrypt_result.code ~= 0 then
		vim.notify(decrypt_result.stderr, vim.log.levels.ERROR)
		return
	end

	local endofline = vim.endswith(decrypt_result.stdout, "\n")
	local lines = vim.split(decrypt_result.stdout:gsub("\n$", ""), "\n", { plain = true })
	if #lines == 0 then
		lines = { "" }
	end

	local swapfile = vim.bo[bufnr].swapfile
	local undofile = vim.bo[bufnr].undofile

	local group = vim.api.nvim_create_augroup("SopsDecryptedBuffer" .. bufnr, { clear = true })

	vim.b[bufnr].sops = "d"

	vim.bo[bufnr].endofline = endofline
	vim.bo[bufnr].swapfile = false
	vim.bo[bufnr].undofile = false
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
	vim.bo[bufnr].modified = false

	vim.api.nvim_create_autocmd("BufWriteCmd", {
		group = group,
		buffer = bufnr,
		callback = function()
			local plaintext = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n")
				.. (vim.bo[bufnr].endofline and "\n" or "")

			local encrypt_result = vim.system({ "sops", path }, {
				text = true,
				stdin = plaintext,
				env = {
					SOPS_EDITOR = "sh -c 'cat > \"$1\"' sh",
				},
			}):wait()

			if encrypt_result.code ~= 0 and encrypt_result.code ~= 200 then
				vim.bo[bufnr].modified = true
				vim.notify(encrypt_result.stderr, vim.log.levels.ERROR)
				return
			end

			vim.bo[bufnr].modified = false
		end,
	})

	vim.api.nvim_create_autocmd("BufUnload", {
		group = group,
		buffer = bufnr,
		callback = function()
			vim.b[bufnr].sops = nil
			vim.bo[bufnr].swapfile = swapfile
			vim.bo[bufnr].undofile = undofile
			pcall(vim.api.nvim_del_augroup_by_id, group)
		end,
	})
end

---@param opts table?
function M.enable(opts)
	M.auto_edit = true

	if opts and opts.bang and M.is_encrypted() then
		M.edit()
	end
end

---@param opts table?
function M.disable(opts)
	M.auto_edit = false

	if opts and opts.bang and M.is_decrypted() then
		local bufnr = vim.api.nvim_get_current_buf()
		local path = vim.api.nvim_buf_get_name(bufnr)
		vim.api.nvim_buf_delete(bufnr, { force = true })
		vim.cmd.edit(vim.fn.fnameescape(path))
	end
end

function M.setup()
	vim.api.nvim_create_user_command("SopsEdit", M.edit, {
		desc = "Edit current sops file in a decrypted buffer",
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
