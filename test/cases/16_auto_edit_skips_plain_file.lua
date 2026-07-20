local h = require("test.helper")

return function()
	local fake = h.fake_sops()
	h.setup()

	local plain = h.temp_file("plain.yml", { "plain" })
	vim.cmd.edit(vim.fn.fnameescape(plain))

	h.assert_eq(vim.api.nvim_buf_get_name(0), plain)
	h.assert_eq(h.read_calls(fake), {})
	fake.cleanup()
end
