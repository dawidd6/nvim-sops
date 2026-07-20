FROM docker.io/library/alpine:edge

# hadolint ignore=DL3018
RUN apk add --no-cache make sops stylua neovim
