.PHONY: all test style

all: build test style

build:
	podman build -t nvim-sops .

test:
	podman run --rm -v .:/wd -w /wd nvim-sops nvim --headless --noplugin -l test/run.lua

style:
	podman run --rm -v .:/wd -w /wd nvim-sops stylua --check .
