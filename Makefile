.PHONY: style style-check test

style:
	@stylua .

style-check:
	@stylua --check .

test:
	@nvim --headless --noplugin -l tests/sops.lua
