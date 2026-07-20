local h = require("test.helper")

return function()
	local sops = h.setup()

	local plain = h.temp_file("secret.yml", { "secret" })
	vim.cmd.edit(vim.fn.fnameescape(plain))
	h.assert_eq(sops.is_decrypted(), false)

	local decrypted = h.temp_file(".decrypted~secret.yml", { "secret" })
	vim.cmd.edit(vim.fn.fnameescape(decrypted))
	h.assert_eq(sops.is_decrypted(), true)
	h.assert_eq(vim.b.sops, "decrypted")
end
