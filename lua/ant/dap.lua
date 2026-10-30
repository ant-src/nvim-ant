-- `ant dap` (spec/dap.md) for nvim-dap: the adapter and a configuration that debugs the current
-- file. Nothing here runs without nvim-dap.
local M = {}

local function resolve(base, file)
  if type(file) ~= 'string' or file == '' or vim.fn.isabsolutepath(file) == 1 then
    return file
  end
  return vim.fs.normalize(vim.fs.joinpath(base, file))
end

-- enrich makes a relative program, cwd, or stdin absolute against Neovim's working directory, as
-- a launch.json path is read against the workspace folder; ant dap would read it against its own.
local function enrich(config, on_config)
  config = vim.deepcopy(config)
  local base = vim.fn.getcwd()
  config.program = resolve(base, config.program)
  config.cwd = resolve(base, config.cwd)
  config.stdin = resolve(base, config.stdin)
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
