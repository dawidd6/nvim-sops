local h = require("test.helper")

return function()
	local sops = h.setup()

	vim.cmd.enew({ bang = true })

	h.assert_eq(sops.is_encrypted(), false)
end
