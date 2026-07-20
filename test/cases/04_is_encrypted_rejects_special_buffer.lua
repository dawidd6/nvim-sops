local h = require("test.helper")

return function()
	local sops = h.setup()

	local path = h.temp_file("secret.yml", h.marker_lines())
	vim.cmd.edit(vim.fn.fnameescape(path))
	vim.bo.buftype = "nofile"

	h.assert_eq(sops.is_encrypted(), false)
end
