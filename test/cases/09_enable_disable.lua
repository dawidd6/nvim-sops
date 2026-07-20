local h = require("test.helper")

return function()
	local sops = h.setup()

	sops.disable()
	h.assert_eq(sops.auto_edit, false)

	sops.enable()
	h.assert_eq(sops.auto_edit, true)
end
