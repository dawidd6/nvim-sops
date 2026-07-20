local h = require("test.helper")

return function()
	local sops = h.setup()

	local path = h.temp_file("secret.yml", { "ENC[AES256_GCM" })
	vim.cmd.edit(vim.fn.fnameescape(path))

	h.assert_eq(sops.is_encrypted(), false)
end
