-- Indentation as ant fmt lays code out (fmt.md section 4): one level inside each bracket and each
-- element of markup, and one level for the continuation lines of a statement, which do not grow
-- with each continuation, so a pipeline's stages line up.
local M = {}

-- Syntax groups whose text holds no code: brackets and operators in them mean nothing.
local function is_text(name)
  return name:find('String', 1, true)
    or name:find('Regex', 1, true)
    or name:find('Comment', 1, true)
    or name:find('Escape', 1, true)
    or name:find('Todo', 1, true)
    or name:find('Shebang', 1, true)
    or name:find('ModuleDoc', 1, true)
    or name:find('Entity', 1, true)
    or name == 'antElement'
    or name == 'antElementNested'
    or name == 'antFragment'
    or name == 'antRaw'
end

local openers = { ['('] = true, ['['] = true, ['{'] = true }
local closers = { [')'] = true, [']'] = true, ['}'] = true }

-- Tokens that cannot end an expression, so that the next line continues the statement (spec
-- section 2, Line endings); a , continues only a list, whose items are not continuations.
local continuing = {
  '&&', '||', '??', '==', '!=', '<=', '>=', '+=', '-=', '*=', '/=', '%=',
  '+', '-', '*', '/', '%', '=', '<', '>', '!', '|', '...',
}

-- scan reads a line into its brackets and its first and last tokens. A bracket is ( [ { or the
-- start tag of an element, and its closer ) ] } or an end tag or />. Unmatched closers come
-- before unmatched openers, since a closer after an opener closes it.
local function scan(lnum)
  local line = vim.fn.getline(lnum)
  local synon = vim.b.current_syntax == 'ant'
  local opens, closes = 0, 0
  local code = {}
  local i, n = 1, #line
  while i <= n do
    local c = line:sub(i, i)
    local name = synon and vim.fn.synIDattr(vim.fn.synID(lnum, i, 0), 'name') or ''
    if name == 'antTag' then
      -- a run of tag characters: <name, </name>, <>, </>, />, or the > that ends a start tag
      local j = i
      while j < n and vim.fn.synIDattr(vim.fn.synID(lnum, j + 1, 0), 'name') == 'antTag' do
        j = j + 1
      end
      local run = line:sub(i, j)
      for k = 1, #run do
        local two = run:sub(k, k + 1)
        if two == '</' or two == '/>' then
          if opens > 0 then
            opens = opens - 1
          else
            closes = closes + 1
          end
        elseif run:sub(k, k) == '<' then
          opens = opens + 1
        end
      end
      table.insert(code, 'x')
      i = j + 1
    elseif synon and is_text(name) then
      if not name:find('Comment', 1, true) and not name:find('Todo', 1, true) and name ~= 'antModuleDoc' then
        table.insert(code, 'x')
      end
      i = i + 1
    elseif not synon and line:sub(i, i + 1) == '//' then
      break
    else
      if openers[c] then
        opens = opens + 1
      elseif closers[c] then
        if opens > 0 then
          opens = opens - 1
        else
          closes = closes + 1
        end
      end
      table.insert(code, c)
      i = i + 1
    end
  end
  local text = vim.trim(table.concat(code))
  return { opens = opens, closes = closes, code = text }
end

local cache = { tick = -1, buf = -1, lines = {} }

local function info(lnum)
  local buf = vim.api.nvim_get_current_buf()
  local tick = vim.b.changedtick
  if cache.buf ~= buf or cache.tick ~= tick then
    cache = { tick = tick, buf = buf, lines = {} }
  end
  local hit = cache.lines[lnum]
  if not hit then
    hit = scan(lnum)
    cache.lines[lnum] = hit
  end
  return hit
end

-- in_kept tells whether the position is in a string, a raw string, or a block comment, whose lines
-- are kept as written, the code of a string's interpolations included (fmt.md 4.9).
local kept = { antString = true, antRawString = true, antComment = true }
local function in_kept(lnum, col)
  for _, id in ipairs(vim.fn.synstack(lnum, col)) do
    if kept[vim.fn.synIDattr(id, 'name')] then
      return true
    end
  end
  return false
end

-- inside_text tells whether a line starts inside a string, a raw string, or a block comment that
-- began on a line above: the line above ends inside it too.
local function inside_text(lnum)
  if vim.b.current_syntax ~= 'ant' or lnum <= 1 then
    return false
  end
  local line = vim.fn.getline(lnum)
  if line:match('^%s*/[/*]') then
    return false
  end
  local first = vim.fn.match(line, '\\S') + 1
  return in_kept(lnum, math.max(first, 1)) and in_kept(lnum - 1, #vim.fn.getline(lnum - 1) + 1)
end

-- starts_tag_end tells whether a line starts with the > that ends a start tag begun on a line above.
local function starts_tag_end(lnum)
  local line = vim.fn.getline(lnum)
  local first = vim.fn.match(line, '\\S') + 1
  return first > 0 and line:sub(first, first) == '>' and vim.b.current_syntax == 'ant'
    and vim.fn.synIDattr(vim.fn.synID(lnum, first, 0), 'name') == 'antTag'
end

local function prev(lnum)
  return vim.fn.prevnonblank(lnum - 1)
end

-- ends_open tells whether a line ends with a token that continues the statement on the next line.
local function ends_open(lnum)
  local code = info(lnum).code
  for _, tok in ipairs(continuing) do
    if vim.endswith(code, tok) then
      return true
    end
  end
  return false
end

-- starts_continuation tells whether a line starts with . ?. or | (but not ||), which continue the
-- statement above.
local function starts_continuation(lnum)
  local code = info(lnum).code
  -- A lone . or | is one being typed: the line is reindented again if it turns out to be ... or ||.
  return code:match('^%.[^.]') ~= nil or code == '.' or code:match('^%?%.') ~= nil or code:match('^|[^|]') ~= nil or code == '|'
end

-- is_continuation tells whether a line continues the statement of the line above it.
local function is_continuation(lnum)
  if starts_continuation(lnum) then
    return true
  end
  local p = prev(lnum)
  return p > 0 and info(p).opens == 0 and ends_open(p)
end

-- opener finds the line that opens the n-th bracket closed after the start of line lnum.
local function opener(lnum, n)
  local depth = n
  local k = prev(lnum)
  while k > 0 do
    local i = info(k)
    depth = depth - i.opens
    if depth <= 0 then
      return k
    end
    depth = depth + i.closes
    k = prev(k)
  end
  return 0
end

-- start finds the line where the statement or list item holding the start of line lnum begins.
local function start(lnum)
  local seen = 0
  while lnum > 0 and seen < 1000 do
    seen = seen + 1
    local i = info(lnum)
    if i.closes > 0 then
      local k = opener(lnum, i.closes)
      if k == 0 then
        return lnum
      end
      lnum = k
    elseif inside_text(lnum) or is_continuation(lnum) then
      local p = prev(lnum)
      if p == 0 then
        return lnum
      end
      lnum = p
    else
      return lnum
    end
  end
  return lnum
end

function M.get(lnum)
  local p = prev(lnum)
  if p == 0 then
    return 0
  end
  -- the lines of a string, of a raw string, and of a block comment are kept as written (fmt.md 4.9)
  if inside_text(lnum) then
    return -1
  end
  local sw = vim.fn.shiftwidth()
  local cur = vim.trim(vim.fn.getline(lnum))

  -- a line that starts with a closer lines up with the line that opened it, and so does one that
  -- starts with the > that ends a start tag, with the line of its < (fmt.md 4.10)
  if cur:match('^[%)%]}]') or cur:match('^</') or cur:match('^/>') or starts_tag_end(lnum) then
    local k = opener(lnum, 1)
    if k > 0 then
      return info(k).closes > 0 and vim.fn.indent(start(k)) or vim.fn.indent(k)
    end
  end

  local pi = info(p)
  -- the content after a line that is the > ending a start tag is one level deeper than it
  if pi.opens == 0 and pi.closes == 0 and starts_tag_end(p) then
    return vim.fn.indent(p) + sw
  end
  if pi.opens > 0 then
    local base = pi.closes > 0 and start(p) or p
    return vim.fn.indent(base) + sw
  end
  local ind = vim.fn.indent(start(p))
  if starts_continuation(lnum) or ends_open(p) then
    ind = ind + sw
  end
  return ind
end

return M
