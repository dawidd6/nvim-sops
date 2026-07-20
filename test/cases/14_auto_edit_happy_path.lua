local h = require("test.helper")

return function()
	vim.env.SOPS_AGE_KEY_FILE = vim.fs.joinpath(h.fixtures, "age.key")
	h.setup()

	local encrypted, tmpdir = h.copy_fixture("secret.txt")
	local decrypted = vim.fs.joinpath(tmpdir, ".decrypted~secret.txt")
	vim.cmd.edit(vim.fn.fnameescape(encrypted))

	h.assert_eq(vim.api.nvim_buf_get_name(0), decrypted)
	h.assert_eq(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "secret text" })

	vim.api.nvim_buf_set_lines(0, 0, -1, false, { "SECRET TEXT" })
	vim.cmd("silent write")

	local decrypt = vim.system({ "sops", "--decrypt", encrypted }, { text = true }):wait()
	h.assert_eq(decrypt.code, 0)
	h.assert_eq(decrypt.stdout, "SECRET TEXT\n")

	vim.api.nvim_buf_delete(0, { force = true })
	h.assert_eq(vim.fn.filereadable(decrypted), 0)
	vim.fs.rm(tmpdir, { force = true, recursive = true })
end
