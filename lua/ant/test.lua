-- ant test (spec/test.md): run or debug the tests of a file, as the code lenses of `ant lsp` and
-- the :Ant test commands ask.
local M = {}

-- is_test_file tells a test file, whose name ends in _test.ant.
function M.is_test_file(file)
  return file:match('_test%.ant$') ~= nil
end

-- quote quotes a test name as a regular expression matching it alone, as ant lsp quotes one:
-- each / escaped too, so it does not split the -run pattern, and for a subtest the name also with
-- " #2", " #3" appended, which repeats of it are named.
function M.quote(name, subtest)
  local q = name:gsub('[\\.+*?()|%[%]{}^$/]', '\\%0')
  return '^' .. q .. (subtest and '( #[0-9]+)?' or '') .. '$'
end

-- command returns the command line that runs the tests of path matching pattern, if any.
function M.command(ant, path, pattern)
  local cmd = { ant, 'test' }
  if pattern and pattern ~= '' then
    vim.list_extend(cmd, { '-run', pattern })
  end
  table.insert(cmd, path)
  return cmd
end

-- run runs the tests of path matching pattern in a terminal below.
function M.run(path, pattern)
  local ant = require('ant').find()
  if not ant then
    vim.notify(require('ant').install_hint, vim.log.levels.ERROR)
    return
  end
  require('ant.commands').terminal(M.command(ant, path, pattern))
end

-- config returns the nvim-dap configuration that debugs the tests of file matching pattern.
function M.config(file, pattern)
  return {
    type = 'ant',
    request = 'launch',
    name = pattern and pattern ~= '' and vim.fs.basename(file) .. ': ' .. pattern or vim.fs.basename(file),
    program = file,
    test = pattern ~= '' and pattern or nil,
  }
end

-- debug debugs the tests of file matching pattern with nvim-dap.
function M.debug(file, pattern)
  local ok, dap = pcall(require, 'dap')
  if not ok then
    vim.notify('Debugging Ant needs nvim-dap: https://github.com/mfussenegger/nvim-dap', vim.log.levels.ERROR)
    return
  end
  require('ant.dap').setup()
  dap.run(M.config(file, pattern))
end

-- The client side of the code lens commands: both take the document's URI and a -run pattern.
local function lens(fn)
  return function(command)
    local args = command.arguments or {}
    local file = vim.uri_to_fname(args[1])
    local buf = vim.fn.bufnr(file)
    if buf ~= -1 and vim.bo[buf].modified then
      vim.api.nvim_buf_call(buf, function()
        vim.cmd('silent write')
      end)
    end
    fn(file, args[2])
  end
end

-- codelens shows the code lenses of buf, a test file, from client: Neovim 0.12 keeps them up to
-- date once enabled, and 0.11 refreshes them when asked.
function M.codelens(buf, client)
  if not M.is_test_file(vim.api.nvim_buf_get_name(buf)) then
    return
  end
  if vim.lsp.codelens.enable then
    vim.lsp.codelens.enable(true, { bufnr = buf, client_id = client.id })
    return
  end
  local function refresh()
    vim.lsp.codelens.refresh({ bufnr = buf })
  end
  refresh()
  vim.api.nvim_create_autocmd({ 'BufEnter', 'InsertLeave', 'BufWritePost' }, {
    group = vim.api.nvim_create_augroup('ant.codelens.' .. buf, {}),
    buffer = buf,
    callback = refresh,
  })
end

M.lsp_commands = {
  ['ant.test.run'] = lens(M.run),
  ['ant.test.debug'] = lens(M.debug),
}

-- target returns the test file of the current file, or nil after saying why not: the file itself,
-- or name_test.ant beside name.ant.
function M.target()
  local file = require('ant.commands').save_current()
  if not file then
    return nil
  end
  if M.is_test_file(file) then
    return file
  end
  local companion = file:gsub('%.ant$', '_test.ant')
  if vim.uv.fs_stat(companion) then
    return companion
  end
  vim.notify('No tests: ' .. vim.fs.basename(companion) .. ' does not exist.', vim.log.levels.INFO)
  return nil
end

-- in_text tells, for each of lines, the first lines of buf, whether it starts inside a string, a
-- raw string, or a comment, whose lines, at whatever indent, say nothing of the tests around them.
-- Without syntax highlighting, a scan for quotes and comments tells.
local function in_text(buf, lines)
  local skip = {}
  if vim.b[buf].current_syntax == 'ant' then
    local in_kept = require('ant.indent').in_kept
    vim.api.nvim_buf_call(buf, function()
      for i, line in ipairs(lines) do
        local first = line:find('%S')
        skip[i] = first ~= nil and in_kept(i, first)
      end
    end)
    return skip
  end
  local open -- the ", ` or /* the scan is inside, if any
  for i, line in ipairs(lines) do
    local first = line:find('%S')
    skip[i] = first ~= nil and (open ~= nil or line:find('^/[/*]', first) ~= nil)
    local j = 1
    while j <= #line do
      local c, two = line:sub(j, j), line:sub(j, j + 1)
      if open == '"' then
        if c == '\\' then
          j = j + 1
        elseif c == '"' then
          open = nil
        end
      elseif open == '`' then
        if c == '`' then
          open = nil
        end
      elseif open == '/*' then
        if two == '*/' then
          open, j = nil, j + 1
        end
      elseif c == '"' or c == '`' then
        open = c
      elseif two == '/*' then
        open, j = two, j + 1
      elseif two == '//' then
        break
      end
      j = j + 1
    end
  end
  return skip
end

-- nearest returns the -run pattern of the test or subtest the cursor is in, from the lines above
-- it, or nil. A subtest whose name is not a literal is passed over for its parent, and lines in
-- strings and comments are passed over.
function M.nearest(buf, lnum)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, lnum, false)
  local skip = in_text(buf, lines)
  local names = {}
  local limit = math.huge
  for i = #lines, 1, -1 do
    local line = lines[i]
    local indent, rest = line:match('^(%s*)(%S.*)$')
    if indent and not skip[i] then
      local width = #indent
      if i == #lines then
        -- The cursor's own line counts, if it declares a test; on a closing brace, the cursor is
        -- in the block it closes.
        limit = width + 1
        if rest:match('^}') then
          width = limit
        end
      end
      if width < limit then
        limit = width
        local quoted = rest:match('^test%s+"(.-)"%s*{')
        if quoted then
          if quoted:find('[\\$"]') then
            names = {}
          else
            table.insert(names, 1, quoted)
          end
        else
          names = rest:match('^test%s') and {} or names
        end
        if width == 0 then
          if quoted and #names > 0 then
            for j, name in ipairs(names) do
              names[j] = M.quote(name, j > 1)
            end
            return table.concat(names, '/')
          end
          return nil
        end
      end
    end
  end
  return nil
end

return M
