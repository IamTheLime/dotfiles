--- `:checkhealth terminal_workflows`: is the app reachable, is K wrapped, is an LSP attached?
local M = {}

local function can_connect(path)
  local uv = vim.uv
  local pipe = uv.new_pipe(false)
  local done, result = false, nil
  pipe:connect(path, function(err)
    result = err
    done = true
    pipe:close()
  end)
  vim.wait(500, function() return done end, 10)
  if not done then return false, "timed out" end
  return result == nil, result
end

function M.check()
  vim.health.start("terminal_workflows")
  local tw = require("terminal_workflows")

  local path = tw.socket_path()
  if not vim.uv.fs_stat(path) then
    vim.health.error("socket missing: " .. path, {
      "Start the app (`cargo run` in terminal_workflows); the socket file exists only while it runs.",
      "If the app uses another path, set TW_SOCKET in both processes or `socket` in setup().",
    })
  else
    local ok, err = can_connect(path)
    if ok then
      vim.health.ok("app reachable at " .. path)
    else
      vim.health.error("socket exists but refuses connections: " .. tostring(err), { "Restart the app." })
    end
  end

  if vim.lsp.buf.hover == tw.hover then
    vim.health.ok("vim.lsp.buf.hover is wrapped; K mirrors into the sidebar")
  else
    vim.health.warn("vim.lsp.buf.hover is not wrapped; K will only show the popup", {
      "Call require('terminal_workflows').setup() (lazy does this with opts = {}).",
      "Or map K to require('terminal_workflows').hover yourself.",
    })
  end

  local clients = vim.lsp.get_clients({ bufnr = 0, method = "textDocument/hover" })
  if #clients == 0 then
    vim.health.info("no LSP client with hover attached to this buffer; open a file with one and press K")
  else
    local names = vim.tbl_map(function(c) return c.name end, clients)
    vim.health.ok("hover-capable clients here: " .. table.concat(names, ", "))
  end
end

return M
