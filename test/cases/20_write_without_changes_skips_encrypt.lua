local h = require("test.helper")

return function()
	local fake = h.fake_sops()
	local sops = h.setup()

	sops.disable()
	local encrypted = h.temp_file("secret.yml", h.marker_lines())
	vim.cmd.edit(vim.fn.fnameescape(encrypted))
	sops.edit()
	vim.cmd("silent write")

	h.assert_eq(h.read_calls(fake), {
		"filestatus " .. encrypted,
		"-d --output " .. vim.fs.dirname(encrypted) .. "/.decrypted~secret.yml " .. encrypted,
	})
	fake.cleanup()
end
