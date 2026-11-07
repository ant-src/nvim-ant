local h = dofile('tests/helpers.lua')

local ant = h.ant()
if not ant then
  io.stdout:write('skipped: no ant; set ANT_PATH\n')
  return
end
vim.g.ant = { path = ant }

local function wait(what, cond, ms)
  if not vim.wait(ms or 10000, cond, 20) then
    error('timed out waiting for ' .. what, 2)
  end
end

local function client(buf)
  return vim.lsp.get_clients({ bufnr = buf, name = 'ant' })[1]
end

-- Diagnostics: the errors of ant check, as the file is typed.
local buf, file = h.buffer({
  'func main() {',
  '  var x: int = "a"',
  '  println(x)',
  '}',
})
h.eq('ant', vim.bo[buf].filetype, 'filetype')
wait('the client', function()
  return client(buf) ~= nil and client(buf).initialized
end)
h.eq(vim.uv.fs_realpath(vim.fs.dirname(file)), vim.uv.fs_realpath(client(buf).root_dir), 'root directory without .git')
wait('diagnostics', function()
  return #vim.diagnostic.get(buf) > 0
end)
local d = vim.diagnostic.get(buf)[1]
h.eq(1, d.lnum, 'diagnostic line')
h.eq('cannot use string where int is expected', d.message, 'diagnostic message')

vim.api.nvim_buf_set_lines(buf, 1, 2, false, { '  var x: int = 1' })
wait('diagnostics to clear', function()
  return #vim.diagnostic.get(buf) == 0
end)

-- Hover.
local res = vim.lsp.buf_request_sync(buf, 'textDocument/hover', {
  textDocument = { uri = vim.uri_from_bufnr(buf) },
  position = { line = 2, character = 3 },
}, 5000)
local hover = vim.inspect(res)
assert(hover:find('println', 1, true), 'hover names println: ' .. hover)

-- Semantic tokens: println is a prelude function.
wait('semantic tokens', function()
  local toks = vim.lsp.semantic_tokens.get_at_pos(buf, 2, 3) or {}
  return #toks > 0
end)
local tok = vim.lsp.semantic_tokens.get_at_pos(buf, 2, 3)[1]
h.eq('function', tok.type, 'token type')
assert(tok.modifiers.defaultLibrary, 'println is from the prelude')

-- Definition of a prelude name opens ant:/prelude.d.ant, served by the server.
vim.api.nvim_win_set_cursor(0, { 3, 3 })
vim.lsp.buf.definition()
wait('the prelude', function()
  return vim.api.nvim_buf_get_name(0):match('^ant:') ~= nil
end)
local prelude = vim.api.nvim_get_current_buf()
assert(vim.api.nvim_buf_line_count(prelude) > 100, 'the prelude has text')
h.eq('ant', vim.bo[prelude].filetype, 'prelude filetype')
h.eq(false, vim.bo[prelude].modifiable, 'prelude is read-only')
local line = vim.api.nvim_get_current_line()
assert(line:find('println', 1, true), 'cursor on println: ' .. line)
wait('the client on the prelude', function()
  return client(prelude) ~= nil
end)
vim.cmd.buffer(buf)

-- Formatting is ant fmt.
vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'func main()   {', 'println( 1 )', '}' })
vim.lsp.buf.format({ bufnr = buf, timeout_ms = 5000 })
h.eq({ 'func main() {', '  println(1)', '}' }, vim.api.nvim_buf_get_lines(buf, 0, -1, false), 'formatted')

-- An Apache Ant build file has the filetype ant too, and gets no server.
local xml = h.buffer({ '<project name="x"></project>' }, 'build.xml')
h.eq('ant', vim.bo[xml].filetype, 'build.xml filetype')
vim.wait(300)
h.eq(nil, client(xml), 'no client for build.xml')
h.eq(nil, vim.fn.execute('syntax list'):find('antRawString%s+xxx start='), 'build.xml has no Ant syntax')
h.eq(nil, vim.bo[xml].indentexpr:match('ant%.indent'), 'build.xml keeps its indent')

-- :Ant restart starts a new server for the open buffers.
local old = client(buf).id
vim.cmd('Ant restart')
wait('a new client', function()
  local c = client(buf)
  return c ~= nil and c.id ~= old and c.initialized
end)
wait('the new client on the prelude', function()
  return client(prelude) ~= nil and client(prelude).id ~= old
end)

-- Completion: accepting an item from the omnifunc expands its snippet, so xs | filt becomes
-- xs | Array.filter(), and without the completion option inserts the item's filter text alone.
-- Insert mode is driven in a child Neovim, whose input does not block this one.
local function complete(enabled)
  local cfile = vim.fs.joinpath(vim.fn.tempname(), 'complete.ant')
  vim.fn.mkdir(vim.fs.dirname(cfile), 'p')
  vim.fn.writefile({ 'func main() {', '  var xs = [1, 2]', '  var ys = xs | filt', '}' }, cfile)
  local opts = ('vim.g.ant = { path = %q, completion = %s }'):format(ant, tostring(enabled))
  local chan = vim.fn.jobstart({
    vim.v.progpath, '--embed', '--headless', '--clean', '--cmd', 'set rtp^=' .. vim.fn.getcwd(),
    '--cmd', 'lua ' .. opts, '-c', 'syntax on', '-c', 'filetype plugin indent on', cfile,
  }, { rpc = true })
  local function eval(code)
    return vim.rpcrequest(chan, 'nvim_exec_lua', code, {})
  end
  local ok, res = pcall(function()
    wait('the client in the child', function()
      return eval("local c = vim.lsp.get_clients({ bufnr = 0, name = 'ant' })[1] return c ~= nil and c.initialized")
    end)
    vim.rpcrequest(chan, 'nvim_win_set_cursor', 0, { 3, 0 })
    vim.rpcrequest(chan, 'nvim_input', 'A<C-x><C-o>')
    wait('completion items', function()
      return eval("return #vim.fn.complete_info({ 'items' }).items") > 0
    end)
    vim.rpcrequest(chan, 'nvim_input', '<C-y>')
    local want = enabled and 'Array.filter(' or 'xs | filter'
    vim.wait(2000, function()
      return eval('return vim.api.nvim_get_current_line()'):find(want, 1, true) ~= nil
    end, 20)
    return eval('return vim.api.nvim_get_current_line()')
  end)
  vim.fn.jobstop(chan)
  assert(ok, res)
  return res
end
h.eq('  var ys = xs | Array.filter()', complete(true), 'completion expands a snippet')
h.eq('  var ys = xs | filter', complete(false), 'completion = false leaves the omnifunc alone')
