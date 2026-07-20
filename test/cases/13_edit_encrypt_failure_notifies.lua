local h = require("test.helper")

return function()
	local fake = h.fake_sops()
	vim.env.NVIM_FAKE_ENCRYPT_FAIL = "1"
	local messages, restore_notify = h.capture_notify()
	local sops = h.setup()
	sops.disable()

	local encrypted = h.temp_file("secret.yml", h.marker_lines())
	vim.cmd.edit(vim.fn.fnameescape(encrypted))
	sops.edit()
	vim.api.nvim_buf_set_lines(0, 0, -1, false, { "changed" })
	vim.cmd("silent write")

	h.assert_eq(messages[1].message, "encrypt failed\n")
	restore_notify()
	fake.cleanup()
end
