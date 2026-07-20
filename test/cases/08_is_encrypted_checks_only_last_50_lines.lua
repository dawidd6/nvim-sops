local h = require("test.helper")

return function()
	local sops = h.setup()
	local lines = h.marker_lines()
	for _ = 1, 60 do
		table.insert(lines, "plain")
	end

	local path = h.temp_file("secret.yml", lines)
	vim.cmd.edit(vim.fn.fnameescape(path))

	h.assert_eq(sops.is_encrypted(), false)
end
