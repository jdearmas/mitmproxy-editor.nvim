# mitmproxy-editor.nvim

When mitmproxy runs inside a Neovim `:terminal` and you edit a flow, it normally
spawns a nested editor *inside* the terminal buffer. This plugin intercepts that
and opens the file in a real Neovim buffer instead.

## How it works

1. The plugin sets `$MITMPROXY_EDITOR` to a helper script.
2. When mitmproxy triggers an edit (e.g. pressing `e` on a request body), it
   invokes the helper script instead of a nested `vim`.
3. The helper script detects the parent Neovim via the `$NVIM` socket and uses
   `nvim --server --remote-expr` to open the temp file in a split.
4. The script blocks until you save and close the buffer (`:wq`), then mitmproxy
   reads back the edited content.

## Requirements

- Neovim >= 0.7 (needs `--server` / `--remote-expr` support)
- mitmproxy

## Install

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "jdearmas/mitmproxy-editor.nvim",
  opts = {},
}
```

### Local clone

```lua
{
  dir = "~/git/mitmproxy-editor.nvim",
  opts = {},
}
```

### Manual

```lua
require("mitmproxy_editor").setup()
```

## Configuration

These are the defaults:

```lua
require("mitmproxy_editor").setup({
  -- How to open the editor buffer: "split", "vsplit", "tabedit"
  open_cmd = "split",

  -- Jump back to the terminal buffer and enter insert mode after editing
  auto_return = true,

  -- Also override $EDITOR/$VISUAL (applies to git, crontab, etc.)
  -- When false, only $MITMPROXY_EDITOR is set (mitmproxy-specific)
  set_editor = false,
})
```

## Usage

### `:Mitmproxy [args]`

Launch mitmproxy in a terminal buffer with optional arguments:

```
:Mitmproxy
:Mitmproxy -p 8888
:Mitmproxy --mode reverse:http://localhost:3000
```

You can also just run mitmproxy manually in any Neovim terminal &mdash;
`$MITMPROXY_EDITOR` is set process-wide so it's inherited automatically.

### Editing flows

1. Open mitmproxy in a terminal (`:Mitmproxy` or `:terminal mitmproxy`)
2. Select a flow and press `e` to edit the request/response
3. The temp file opens in a Neovim split instead of a nested editor
4. Edit, then `:wq` to send changes back to mitmproxy
5. Cursor returns to the mitmproxy terminal automatically

### Using with other tools

Set `set_editor = true` to also redirect `$EDITOR` and `$VISUAL`. This makes
`git commit`, `kubectl edit`, `crontab -e`, and anything else that spawns an
editor open in the parent Neovim when run inside a `:terminal`.

## License

MIT
