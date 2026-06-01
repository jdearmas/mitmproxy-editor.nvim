local M = {}

local config = {}

local defaults = {
  open_cmd = "split",
  auto_return = true,
  set_editor = false,
}

local function write_script(path)
  local f = io.open(path, "w")
  if not f then
    return false
  end
  -- Shell script invoked by mitmproxy as $MITMPROXY_EDITOR.
  -- When $NVIM is set (inside a Neovim terminal), it asks the parent Neovim
  -- to open the file in a real buffer via RPC, then blocks until editing is
  -- done.  Outside Neovim it falls back to a normal editor.
  f:write([=[#!/bin/sh
set -e

if [ -z "$NVIM" ]; then
  exec "${NVIM_PARENT_EDITOR_FALLBACK:-vi}" "$@"
fi

FIFO=$(mktemp -u "${TMPDIR:-/tmp}/mitm-edit.XXXXXX")
mkfifo "$FIFO"
trap 'rm -f "$FIFO"' EXIT

esc() { printf '%s' "$1" | sed "s/\\\\/\\\\\\\\/g; s/'/\\\\'/g"; }
F=$(esc "$1")
D=$(esc "$FIFO")

nvim --server "$NVIM" --remote-expr \
  "v:lua.require('mitmproxy_editor')._open('$F','$D')" \
  >/dev/null 2>&1 || {
  rm -f "$FIFO"
  exec "${NVIM_PARENT_EDITOR_FALLBACK:-vi}" "$@"
}

read _ < "$FIFO"
]=])
  f:close()
  local uv = vim.uv or vim.loop
  uv.fs_chmod(path, tonumber("755", 8))
  return true
end

function M.setup(opts)
  config = vim.tbl_deep_extend("force", defaults, opts or {})

  local dir = vim.fn.stdpath("data") .. "/mitmproxy-editor"
  vim.fn.mkdir(dir, "p")
  local script = dir .. "/editor.sh"

  if not write_script(script) then
    vim.notify("mitmproxy-editor: cannot write " .. script, vim.log.levels.ERROR)
    return
  end

  vim.env.MITMPROXY_EDITOR = script

  if config.set_editor then
    vim.env.NVIM_PARENT_EDITOR_FALLBACK = vim.env.EDITOR or "vi"
    vim.env.EDITOR = script
    vim.env.VISUAL = script
  end

  vim.api.nvim_create_user_command("Mitmproxy", function(cmd)
    vim.cmd("terminal mitmproxy " .. cmd.args)
    vim.cmd("startinsert")
  end, { nargs = "*", desc = "Launch mitmproxy in terminal" })
end

--- Called from the helper script via --remote-expr RPC.
--- Opens `file` in a split and signals completion by writing to a FIFO.
function M._open(file, done_file)
  vim.schedule(function()
    local term_win = vim.api.nvim_get_current_win()
    local term_buf = vim.api.nvim_get_current_buf()

    vim.cmd(config.open_cmd .. " " .. vim.fn.fnameescape(file))
    local buf = vim.api.nvim_get_current_buf()
    vim.bo[buf].bufhidden = "wipe"

    vim.api.nvim_create_autocmd("BufWipeout", {
      buffer = buf,
      once = true,
      callback = function()
        local fd = io.open(done_file, "w")
        if fd then
          fd:write("\n")
          fd:close()
        end
        if config.auto_return then
          vim.schedule(function()
            if
              vim.api.nvim_win_is_valid(term_win)
              and vim.api.nvim_buf_is_valid(term_buf)
              and vim.bo[term_buf].buftype == "terminal"
            then
              vim.api.nvim_set_current_win(term_win)
              vim.cmd("startinsert")
            end
          end)
        end
      end,
    })
  end)
  return "ok"
end

return M
