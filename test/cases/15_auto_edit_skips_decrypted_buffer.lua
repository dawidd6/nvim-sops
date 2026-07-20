local h = require("test.helper")

return function()
	local fake = h.fake_sops()
	h.setup()

	local decrypted = h.temp_file(".decrypted~secret.yml", { "plain" })
	vim.cmd.edit(vim.fn.fnameescape(decrypted))

	h.assert_eq(vim.api.nvim_buf_get_name(0), decrypted)
	h.assert_eq(vim.b.sops, "decrypted")
	h.assert_eq(h.read_calls(fake), {})
	fake.cleanup()
end
