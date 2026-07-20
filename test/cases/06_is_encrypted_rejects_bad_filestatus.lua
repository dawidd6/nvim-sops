local h = require("test.helper")

return function()
	local fake = h.fake_sops()
	vim.env.NVIM_FAKE_FILESTATUS_FAIL = "1"
	local sops = h.setup()

	local path = h.temp_file("secret.yml", h.marker_lines())
	vim.cmd.edit(vim.fn.fnameescape(path))

	h.assert_eq(sops.is_encrypted(), false)
	h.assert_eq(vim.b.sops, nil)
	fake.cleanup()
end
