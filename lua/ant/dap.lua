-- `ant dap` (spec/dap.md) for nvim-dap: the adapter and a configuration that debugs the current
-- file. Nothing here runs without nvim-dap.
local M = {}

local function resolve(base, file)
  if type(file) ~= 'string' or file == '' or vim.fn.isabsolutepath(file) == 1 then
    return file
  end
  return vim.fs.normalize(vim.fs.joinpath(base, file))
end

-- enrich makes a relative cwd absolute against Neovim's working directory, as a launch.json path
-- is read against the workspace folder, and a relative program against cwd, as ant dap reads it
-- (dap.md), or against Neovim's working directory without one, since the adapter runs in the
-- program's directory. A relative stdin is left to ant dap, which reads it against cwd.
local function enrich(config, on_config)
  config = vim.deepcopy(config)
  config.cwd = resolve(vim.fn.getcwd(), config.cwd)
  local has_cwd = type(config.cwd) == 'string' and config.cwd ~= ''
  config.program = resolve(has_cwd and config.cwd or vim.fn.getcwd(), config.program)
  on_config(config)
end

-- setup registers the adapter and, unless the user has their own, the configuration; it returns
-- false when nvim-dap is not installed.
function M.setup()
  local ok, dap = pcall(require, 'dap')
  if not ok then
    return false
  end
  dap.adapters.ant = function(callback, config)
    local ant = require('ant').find()
    if not ant then
      vim.notify(require('ant').install_hint, vim.log.levels.ERROR)
      return
    end
    local cwd = config.cwd or (type(config.program) == 'string' and vim.fs.dirname(config.program)) or nil
    callback({
      type = 'executable',
      command = ant,
      args = { 'dap' },
      options = { cwd = cwd },
      enrich_config = enrich,
    })
  end
  dap.configurations.ant = dap.configurations.ant
    or {
      {
        type = 'ant',
        request = 'launch',
        name = 'Debug Ant file',
        program = '${file}',
      },
    }
  return true
end

-- debug_file saves the current Ant file and debugs it.
function M.debug_file(args)
  local ok, dap = pcall(require, 'dap')
  if not ok then
    vim.notify('Debugging Ant needs nvim-dap: https://github.com/mfussenegger/nvim-dap', vim.log.levels.ERROR)
    return
  end
  M.setup()
  local file = require('ant.commands').save_current()
  if not file then
    return
  end
  dap.run({
    type = 'ant',
    request = 'launch',
    name = vim.fs.basename(file),
    program = file,
    args = args,
  })
end

return M
