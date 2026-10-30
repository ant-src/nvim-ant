-- The :Ant command: run, debug, restart, and the server's log.
local M = {}

-- save_current saves the current Ant buffer and returns its file, or nil after saying why not.
function M.save_current()
  local buf = vim.api.nvim_get_current_buf()
  if vim.bo[buf].filetype ~= 'ant' or require('ant').is_build_xml(buf) then
    vim.notify('Open an Ant file first.', vim.log.levels.INFO)
    return nil
  end
  local file = vim.api.nvim_buf_get_name(buf)
  if file == '' or vim.bo[buf].buftype ~= '' then
    vim.notify('Save the file first.', vim.log.levels.INFO)
    return nil
  end
  if vim.bo[buf].modified then
    vim.cmd('silent write')
  end
  return vim.fn.fnamemodify(file, ':p')
end

-- run runs the current file with ant run in a terminal below, with args after the file.
function M.run(args)
  local file = M.save_current()
  if not file then
    return
  end
  local ant = require('ant').find()
  if not ant then
    vim.notify(require('ant').install_hint, vim.log.levels.ERROR)
    return
  end
  vim.cmd('botright new')
  vim.fn.jobstart(vim.list_extend({ ant, 'run', file }, args), { term = true })
  vim.bo.bufhidden = 'wipe'
end

-- restart stops the language servers and, once they have exited, starts them again for the open
-- Ant buffers, looking for ant afresh; a server still running would be reused.
function M.restart()
  require('ant').forget()
  local clients = vim.lsp.get_clients({ name = 'ant' })
  for _, c in ipairs(clients) do
    c:stop()
  end
  local waited = 0
  local timer = assert(vim.uv.new_timer())
  timer:start(0, 50, vim.schedule_wrap(function()
    waited = waited + 50
    local running = vim.tbl_filter(function(c)
      return not c:is_stopped()
    end, clients)
    if #running > 0 and waited < 5000 then
      return
    end
    for _, c in ipairs(running) do
      c:stop(true)
    end
    timer:stop()
    timer:close()
    if not vim.lsp.is_enabled('ant') then
      return
    end
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].filetype == 'ant' then
        vim.api.nvim_exec_autocmds('FileType', { group = 'nvim.lsp.enable', buffer = buf })
      end
    end
  end))
end

local subcommands = {
  run = M.run,
  debug = function(args)
    require('ant.dap').debug_file(args)
  end,
  restart = M.restart,
  log = function()
    vim.cmd.tabnew(vim.lsp.log.get_filename())
  end,
}

function M.command(opts)
  local name = opts.fargs[1] or 'run'
  local sub = subcommands[name]
  if not sub then
    vim.notify('Ant: unknown subcommand ' .. name, vim.log.levels.ERROR)
    return
  end
  sub(vim.list_slice(opts.fargs, 2))
end

function M.complete(arglead, line)
  if line:match('^%s*%S+%s+%S+%s') then
    return vim.fn.getcompletion(arglead, 'file')
  end
  return vim.tbl_filter(function(name)
    return vim.startswith(name, arglead)
  end, vim.tbl_keys(subcommands))
end

return M
