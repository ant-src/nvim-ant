local M = {}

function M.eq(want, got, what)
  if not vim.deep_equal(want, got) then
    error(('%s: want %s, got %s'):format(what or 'value', vim.inspect(want), vim.inspect(got)), 2)
  end
end

-- buffer opens a scratch file with the given lines as an Ant buffer and returns it.
function M.buffer(lines, name)
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, 'p')
  local file = vim.fs.joinpath(dir, name or 'test.ant')
  vim.fn.writefile(lines, file)
  vim.cmd.edit(vim.fn.fnameescape(file))
  return vim.api.nvim_get_current_buf(), file
end

-- group returns the syntax group at the first occurrence of text on line lnum, at offset off in it.
function M.group(lnum, text, off)
  local line = vim.fn.getline(lnum)
  local col = assert(line:find(text, 1, true), ('%q not on line %d'):format(text, lnum))
  return vim.fn.synIDattr(vim.fn.synID(lnum, col + (off or 0), 1), 'name')
end

-- corpus returns the .ant files under ANT_CORPUS, or ../ant, that parse, and whether each is
-- formatted, as ant fmt says, with its path relative to the directory.
function M.corpus()
  local dir = os.getenv('ANT_CORPUS') or '../ant'
  local ant = M.ant()
  if vim.fn.isdirectory(dir) == 0 or not ant then
    return {}
  end
  local files = vim.fs.find(function(name)
    return name:match('%.ant$')
  end, { path = dir, type = 'file', limit = math.huge })
  local out = {}
  for _, f in ipairs(files) do
    local code = vim.system({ ant, 'fmt', '--check', f }):wait().code
    if code ~= 2 then
      table.insert(out, { file = f, rel = f:sub(#dir + 2), formatted = code == 0 })
    end
  end
  return out
end

function M.ant()
  local path = os.getenv('ANT_PATH')
  if path and path ~= '' then
    return path
  end
  return vim.fn.exepath('ant') ~= '' and vim.fn.exepath('ant') or nil
end

return M
