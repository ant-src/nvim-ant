if vim.g.loaded_ant then
  return
end
vim.g.loaded_ant = true

if vim.fn.has('nvim-0.11') == 0 then
  vim.notify_once('ant: Neovim 0.11 or later is needed', vim.log.levels.WARN)
  return
end

local ant = require('ant')

if ant.options().lsp then
  vim.lsp.enable('ant')
end

vim.api.nvim_create_user_command('Ant', function(opts)
  require('ant.commands').command(opts)
end, {
  nargs = '*',
  complete = function(arglead, line)
    return require('ant.commands').complete(arglead, line)
  end,
  desc = 'Ant: run, debug, test, restart, log',
})

local group = vim.api.nvim_create_augroup('ant', {})

vim.api.nvim_create_autocmd('BufReadCmd', {
  group = group,
  pattern = 'ant:/*',
  callback = function(args)
    require('ant.source').read(args.buf)
  end,
})

-- A server that starts, after a restart, takes over the ant: documents open from the one before;
-- the code lenses of a test file are shown.
vim.api.nvim_create_autocmd('LspAttach', {
  group = group,
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if client and client.name == 'ant' then
      require('ant.source').adopt(client)
      require('ant.test').codelens(args.buf, client)
    end
  end,
})

-- nvim-dap is registered at the first Ant buffer, so that a lazily loaded nvim-dap has loaded.
vim.api.nvim_create_autocmd('FileType', {
  group = group,
  pattern = 'ant',
  once = true,
  callback = function()
    if ant.options().dap then
      require('ant.dap').setup()
    end
  end,
})

-- The server's semantic tokens include markup elements and attributes, which have no default
-- highlight.
local function highlights()
  vim.api.nvim_set_hl(0, '@lsp.type.element.ant', { link = '@tag', default = true })
  vim.api.nvim_set_hl(0, '@lsp.type.attribute.ant', { link = '@tag.attribute', default = true })
end
highlights()
vim.api.nvim_create_autocmd('ColorScheme', { group = group, callback = highlights })
