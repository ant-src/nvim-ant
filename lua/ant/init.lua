-- ant: Neovim support for the Ant language. The language server is `ant lsp` (spec/lsp.md) and
-- the debugger `ant dap` (spec/dap.md); this module finds the ant executable and holds the options.
local M = {}

M.install_hint =
  'The ant executable was not found. Set vim.g.ant.path, or install it with: go install github.com/ant-src/ant/cmd/ant@latest'

local defaults = {
  -- The ant executable. nil means ant on PATH, then in $GOBIN, then in the bin directory of
  -- `go env GOPATH`, then ~/go/bin.
  path = nil,
  -- Start `ant lsp` for Ant buffers.
  lsp = true,
  -- Register `ant dap` with nvim-dap, when it is installed.
  dap = true,
}

-- options returns vim.g.ant over the defaults.
function M.options()
  return vim.tbl_extend('force', defaults, vim.g.ant or {})
end

-- setup sets the options, for plugin managers that call it; the plugin works without it.
function M.setup(opts)
  vim.g.ant = vim.tbl_extend('force', vim.g.ant or {}, opts or {})
  M.forget()
  local o = M.options()
  if vim.fn.has('nvim-0.11') == 1 then
    vim.lsp.enable('ant', o.lsp)
  end
  if o.dap then
    require('ant.dap').setup()
  end
end

-- found caches where ant was found, until the options change; a miss is not cached, so that an
-- ant installed later is found by the next restart.
local found

local function executable(file)
  local stat = vim.uv.fs_stat(file)
  return stat ~= nil and stat.type == 'file' and vim.fn.executable(file) == 1
end

local function locate()
  local configured = M.options().path
  if configured and configured ~= '' then
    return vim.fn.expand(configured)
  end
  local exe = vim.fn.has('win32') == 1 and 'ant.exe' or 'ant'
  local onpath = vim.fn.exepath(exe)
  if onpath ~= '' then
    return onpath
  end
  local gobin = vim.env.GOBIN
  if gobin and gobin ~= '' and executable(vim.fs.joinpath(gobin, exe)) then
    return vim.fs.joinpath(gobin, exe)
  end
  if vim.fn.executable('go') == 1 then
    local ok, res = pcall(function()
      return vim.system({ 'go', 'env', 'GOPATH' }, { text = true }):wait(5000)
    end)
    local gopath = ok and res.code == 0 and vim.trim(res.stdout or '') or ''
    if gopath ~= '' and executable(vim.fs.joinpath(gopath, 'bin', exe)) then
      return vim.fs.joinpath(gopath, 'bin', exe)
    end
  end
  local home = vim.fs.joinpath(vim.uv.os_homedir(), 'go', 'bin', exe)
  if executable(home) then
    return home
  end
  return nil
end

-- find returns the ant executable, or nil when there is none.
function M.find()
  if not found then
    found = locate()
  end
  return found
end

-- forget drops the cached executable, so that the next find looks again.
function M.forget()
  found = nil
end

-- is_build_xml tells an Apache Ant build file, which Neovim gives the filetype ant as well, from
-- an Ant source file, so that this plugin leaves it alone.
function M.is_build_xml(buf)
  return vim.api.nvim_buf_get_name(buf or 0):lower():match('%.xml$') ~= nil
end

return M
