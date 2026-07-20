local h = require("test.helper")

return function()
	local fake = h.fake_sops()
	local sops = h.setup()
	sops.disable()

	local encrypted = h.temp_file("secret.yml", h.marker_lines())
	vim.cmd.edit(vim.fn.fnameescape(encrypted))

	h.assert_eq(vim.api.nvim_buf_get_name(0), encrypted)
	h.assert_eq(vim.fn.filereadable(vim.fs.joinpath(vim.fs.dirname(encrypted), ".decrypted~secret.yml")), 0)
	h.assert_eq(h.read_calls(fake), { "filestatus " .. encrypted })
	fake.cleanup()
end
