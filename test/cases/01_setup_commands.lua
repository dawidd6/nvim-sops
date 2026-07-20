local h = require("test.helper")

return function()
	local sops = h.setup()

	h.assert_eq(sops.auto_edit, true)
	h.assert_eq(vim.fn.exists(":SopsEdit"), 2)
	h.assert_eq(vim.fn.exists(":SopsEnable"), 2)
	h.assert_eq(vim.fn.exists(":SopsDisable"), 2)
end
