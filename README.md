# nvim-sops

Edit [SOPS](https://github.com/getsops/sops) encrypted files in Neovim through a temporary decrypted buffer.

Inspired by [vscode-sops](https://github.com/signageos/vscode-sops).

## Requirements

- Neovim 0.12 (might work on older versions, it just wasn't tested)
- `sops` available on `$PATH`

## Installation

Install with your preferred plugin manager:

```lua
vim.pack.add({{ src = "https://github.com/dawidd6/nvim-sops" }})
```

## Setup

```lua
require("sops").setup()
```

## Commands

- `:SopsEdit` decrypts the current file into a temporary sibling file, opens it, and re-encrypts the original file after writes.
- `:SopsEnable` enables automatic decrypt-on-open. `:SopsEnable!` also decrypts the current file, like `:SopsEdit`.
- `:SopsDisable` disables automatic decrypt-on-open. `:SopsDisable!` also closes a decrypted buffer and opens the encrypted file.

Automatic decrypt-on-open checks the last 50 lines for SOPS encryption markers, then confirms with `sops filestatus <file>`.

Temporary decrypted files are named `.decrypted~<original-name>` and are removed when their buffer is deleted or Neovim exits.

## API

- `require("sops").setup()` creates commands and automatic decrypt-on-open autocmds.
- `require("sops").edit()` decrypts the current file into a temporary sibling file and wires writes back through SOPS.
- `require("sops").enable(opts)` enables automatic decrypt-on-open. With `{ bang = true }`, it also decrypts the current buffer.
- `require("sops").disable(opts)` disables automatic decrypt-on-open. With `{ bang = true }`, it closes a decrypted buffer and opens the encrypted file.
- `require("sops").is_decrypted()` checks whether the current buffer is a temporary decrypted file and sets `vim.b.sops = "decrypted"` when true.
- `require("sops").is_encrypted()` checks the current buffer for SOPS encryption markers, then confirms with `sops filestatus` and sets `vim.b.sops = "encrypted"` when true.
- `require("sops").auto_edit` contains the active automatic decrypt-on-open state.

Example lualine component:

```lua
sections = {
  lualine_x = {
    {
      function()
        return "󰿇 SOPS"
      end,
      cond = function()
        return vim.b["sops"] == "decrypted"
      end,
    },
    {
      function()
        return "󰍁 SOPS"
      end,
      cond = function()
        return vim.b["sops"] == "encrypted"
      end,
    },
  },
}
```
