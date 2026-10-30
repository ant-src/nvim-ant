-- Documents with the URI scheme ant:, such as ant:/prelude.d.ant, which definition opens for a
-- prelude declaration. Their text comes from the server's ant/source request (spec/lsp.md
-- section 4), and the server serves them as it serves a file, so the client attaches to them.
local M = {}

local function client()
  for _, c in ipairs(vim.lsp.get_clients({ name = 'ant' })) do
    if c.initialized then
      return c
    end
  end
end

-- read fills the buffer of an ant: URI; it is the BufReadCmd of ant:*.
function M.read(buf)
  local uri = vim.api.nvim_buf_get_name(buf)
  local c = client()
  if not c then
    vim.notify(uri .. ': the Ant language server is not running', vim.log.levels.ERROR)
    return
  end
  local res, err = c:request_sync('ant/source', { uri = uri }, 5000, buf)
  if not res or res.err then
    local msg = res and res.err and res.err.message or err or 'no answer'
    vim.notify(uri .. ': ' .. msg, vim.log.levels.ERROR)
    return
  end
  local bo = vim.bo[buf]
  bo.modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(res.result or '', '\r?\n'))
  bo.buftype = 'nofile'
  bo.swapfile = false
  bo.modifiable = false
  bo.readonly = true
  bo.modified = false
  bo.filetype = 'ant'
  vim.lsp.buf_attach_client(buf, c.id)
end

-- adopt attaches the client to the loaded ant: buffers that have no server.
function M.adopt(c)
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if
      vim.api.nvim_buf_is_loaded(buf)
      and vim.api.nvim_buf_get_name(buf):match('^ant:')
      and #vim.lsp.get_clients({ bufnr = buf, name = 'ant' }) == 0
    then
      vim.lsp.buf_attach_client(buf, c.id)
    end
  end
end

return M
