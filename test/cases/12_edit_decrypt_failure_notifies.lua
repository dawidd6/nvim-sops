local h = require("test.helper")

return function()
	local fake = h.fake_sops()
	vim.env.NVIM_FAKE_DECRYPT_FAIL = "1"
	local messages, restore_notify = h.capture_notify()
	local sops = h.setup()
	sops.disable()

	local encrypted = h.temp_file("secret.yml", h.marker_lines())
	vim.cmd.edit(vim.fn.fnameescape(encrypted))
	sops.edit()

	h.assert_eq(vim.api.nvim_buf_get_name(0), encrypted)
	h.assert_eq(messages[1].message, "decrypt failed\n")
	restore_notify()
	fake.cleanup()
end
