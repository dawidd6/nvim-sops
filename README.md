# nvim-sops

Edit [SOPS](https://github.com/getsops/sops) encrypted files in Neovim through a temporary decrypted buffer.

## Requirements

- Neovim with `vim.system`
- `sops` available on `$PATH`

## Installation

Install with your preferred plugin manager:

```lua
{
  "dawidd6/nvim-sops",
  opts = {},
}
```

## Configuration

```lua
require("sops").setup({
  auto_edit = true,
  command = "sops",
  decrypted_prefix = ".decrypted~",
})
```

## Commands

- `:SopsEdit` decrypts the current file into a temporary sibling file, opens it, and re-encrypts the original file after writes.
- `:SopsEnable` enables automatic decrypt-on-open and decrypts the current file if it validates as SOPS.
- `:SopsDisable` disables automatic decrypt-on-open. From a decrypted buffer, it closes the temporary buffer and opens the encrypted file.

Automatic decrypt-on-open validates SOPS metadata markers, then confirms with `sops filestatus <file>`.

Temporary decrypted files use `decrypted_prefix` plus a unique suffix and are removed when their buffer is deleted or Neovim exits.

## API

`require("sops").is_decryptable(bufnr, path)` checks for SOPS metadata markers, then confirms with `sops filestatus`. This is useful for statusline components such as lualine.
