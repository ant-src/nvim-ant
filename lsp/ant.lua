-- The configuration of `ant lsp` for vim.lsp.config (Neovim 0.11+). Override any field with
-- vim.lsp.config('ant', { ... }).
local warned = false

---@type vim.lsp.Config
return {
  cmd = function(dispatchers, config)
    local ant = require('ant').find() or 'ant'
    return vim.lsp.rpc.start({ ant, 'lsp' }, dispatchers, { cwd = config.root_dir })
  end,
  filetypes = { 'ant' },
  root_dir = function(buf, on_dir)
    if require('ant').is_build_xml(buf) then
      return
    end
    if not require('ant').find() then
      if not warned then
        warned = true
        vim.notify(require('ant').install_hint, vim.log.levels.ERROR)
      end
      return
    end
    local name = vim.api.nvim_buf_get_name(buf)
    on_dir(vim.fs.root(buf, { '.git' }) or vim.fs.dirname(name))
  end,
}
