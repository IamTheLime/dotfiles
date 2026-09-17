--- Neovim client for terminal_workflows.
---
--- Talks to the app's control socket (one JSON `HostCommand` per line) and
--- mirrors LSP hover (`K`) into the app's sidebar, next to the usual popup.
---
--- Setup with lazy.nvim:
---   { dir = "~/Documents/personal/dotfiles/terminal_workflows/clients/nvim",
---     name = "terminal_workflows", event = "LspAttach", opts = {} }
---
--- Commands: `:TW hover` (mirror once), `:TW tab`, `:TW send <text>`,
--- `:TW md <file>` (show a markdown file), `:TW json <json>` (raw command).
local M = {}

local uv = vim.uv

---@class TWConfig
---@field socket string|nil  Path of the app's socket; defaults to $TW_SOCKET or $TMPDIR/terminal_workflows.sock
---@field wrap_hover boolean Replace vim.lsp.buf.hover with a version that also mirrors (default true)
M.config = { socket = nil, wrap_hover = true }

--- Where the app listens. `:checkhealth terminal_workflows` shows it.
function M.socket_path()
  if M.config.socket then return M.config.socket end
  if vim.env.TW_SOCKET then return vim.env.TW_SOCKET end
  local tmp = (vim.env.TMPDIR or "/tmp"):gsub("/$", "")
  return tmp .. "/terminal_workflows.sock"
end
local socket_path = M.socket_path

--- Send one command. Each call opens its own connection, so there is no
--- state to reconnect; the app answers one line per command, which is read
--- only to report errors.
---@param command table  A HostCommand, e.g. { type = "newTab" }
function M.send(command)
  local path = socket_path()
  local pipe = uv.new_pipe(false)
  pipe:connect(path, function(err)
    if err then
      pipe:close()
      vim.schedule(function()
        vim.notify(("terminal_workflows: %s (%s). Is the app running?"):format(err, path), vim.log.levels.WARN)
      end)
      return
    end
    pipe:write(vim.json.encode(command) .. "\n")
    pipe:read_start(function(read_err, chunk)
      if read_err or not chunk then
        pipe:close()
        return
      end
      local ok, reply = pcall(vim.json.decode, chunk)
      if ok and type(reply) == "table" and reply.type == "error" then
        vim.schedule(function() vim.notify("terminal_workflows: " .. tostring(reply.message), vim.log.levels.ERROR) end)
      end
      pipe:close()
    end)
  end)
end

--- Join every server's hover contents into one markdown document.
---@param results table<integer, { result: table|nil, error: table|nil }>
local function hover_markdown(results)
  local chunks = {}
  for _, response in pairs(results) do
    local result = response.result
    if result and result.contents then
      local lines = vim.lsp.util.convert_input_to_markdown_lines(result.contents)
      if #lines > 0 then chunks[#chunks + 1] = table.concat(lines, "\n") end
    end
  end
  return table.concat(chunks, "\n\n---\n\n")
end

--- Request hover for the word under the cursor and send it to the sidebar.
--- Does nothing (quietly) when no attached server supports hover.
function M.mirror_hover()
  local bufnr = vim.api.nvim_get_current_buf()
  if #vim.lsp.get_clients({ bufnr = bufnr, method = "textDocument/hover" }) == 0 then return end
  local row = vim.api.nvim_win_get_cursor(0)[1]
  local title = ("%s:%d  %s"):format(vim.fn.expand("%:t"), row, vim.fn.expand("<cword>"))
  vim.lsp.buf_request_all(bufnr, "textDocument/hover", function(client)
    return vim.lsp.util.make_position_params(0, client.offset_encoding)
  end, function(results)
    local markdown = hover_markdown(results)
    if markdown ~= "" then M.send({ type = "showMarkdown", title = title, markdown = markdown }) end
  end)
end

--- The usual hover popup plus the sidebar mirror. Map `K` to this, or let
--- `setup` swap it in for `vim.lsp.buf.hover`.
function M.hover(opts)
  M.mirror_hover()
  return (M._original_hover or vim.lsp.buf.hover)(opts)
end

--- Put the wrapper in front of whatever `vim.lsp.buf.hover` is right now.
--- Plugins like noice replace that function when they load, so this runs
--- again on every LspAttach and keeps their version as the one to call.
function M.wrap_hover()
  if vim.lsp.buf.hover == M.hover then return end
  M._original_hover = vim.lsp.buf.hover
  vim.lsp.buf.hover = M.hover
end

--- Show a markdown file (or the current buffer when `path` is nil) in the sidebar.
function M.show_file(path)
  local lines
  if path and path ~= "" then
    lines = vim.fn.readfile(vim.fn.expand(path))
  else
    lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    path = vim.fn.expand("%:t")
  end
  M.send({ type = "showMarkdown", title = vim.fn.fnamemodify(path, ":t"), markdown = table.concat(lines, "\n") })
end

local subcommands = {
  status = function() vim.cmd("checkhealth terminal_workflows") end,
  hover = function() M.mirror_hover() end,
  tab = function() M.send({ type = "newTab" }) end,
  send = function(rest) M.send({ type = "writeToTerminal", text = rest .. "\n" }) end,
  md = function(rest) M.show_file(rest) end,
  json = function(rest)
    local ok, command = pcall(vim.json.decode, rest)
    if ok then M.send(command) else vim.notify("terminal_workflows: not JSON: " .. rest, vim.log.levels.ERROR) end
  end,
}

---@param opts TWConfig|nil
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
  if M.config.wrap_hover then
    M.wrap_hover()
    vim.api.nvim_create_autocmd({ "LspAttach", "VimEnter" }, {
      group = vim.api.nvim_create_augroup("terminal_workflows_hover", { clear = true }),
      callback = M.wrap_hover,
    })
  end
  vim.api.nvim_create_user_command("TW", function(cmd)
    local name, rest = cmd.args:match("^(%S+)%s*(.*)$")
    local handler = subcommands[name or ""]
    if not handler then
      vim.notify("terminal_workflows: :TW " .. table.concat(vim.tbl_keys(subcommands), " | "), vim.log.levels.INFO)
      return
    end
    handler(rest)
  end, {
    nargs = "+",
    complete = function() return vim.tbl_keys(subcommands) end,
    desc = "terminal_workflows control",
  })
end

return M
