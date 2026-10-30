local h = dofile('tests/helpers.lua')

-- reindent sets the lines, unindented unless as_written, reindents them all, and compares with the
-- lines as given.
local function reindent(lines, what, as_written)
  local buf = h.buffer(lines)
  if not as_written then
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.tbl_map(vim.trim, lines))
  end
  vim.cmd('silent normal! gg=G')
  h.eq(lines, vim.api.nvim_buf_get_lines(buf, 0, -1, false), what)
  vim.cmd('silent! bwipeout!')
end

reindent({
  'func main() {',
  '  if x {',
  '    println(1)',
  '  } else {',
  '    println(2)',
  '  }',
  '}',
}, 'blocks')

reindent({
  'var names = users',
  '  | Array.filter({ x.age >= 18 })',
  '  | Array.map({',
  '    x.name',
  '  })',
  '  | Array.sort()',
  'var total = subtotal +',
  '  shipping +',
  '  tax',
  'var p = point',
  '  .x',
}, 'continuations')

reindent({
  'var xs = [',
  '  first,',
  '  ...rest',
  ']',
  'call(a,',
  '  b)',
  'next()',
}, 'lists')

reindent({
  'func page(): Html {',
  '  <div class="a">',
  '    <br />',
  '    <p>{if x { <b>y</b> } else { "z" }}</p>',
  '    <textarea required></textarea>',
  '  </div>',
  '}',
}, 'markup')

reindent({
  'if x {',
  '  /* a block',
  '     comment */',
  '  var s = `multi',
  'line`',
  '  println(s)',
  '}',
}, 'text', true)

-- Every formatted file of the corpus but those whose markup or template text fmt keeps as
-- written reindents to itself.
local kept = {
  ['tests/run/html.ant'] = true,
  ['internal/format/testdata/blocks.out.ant'] = true,
  ['internal/format/testdata/html.out.ant'] = true,
  ['internal/format/testdata/templates.out.ant'] = true,
}
local bad, total = {}, 0
for _, f in ipairs(h.corpus()) do
  if f.formatted and not kept[f.rel] then
    total = total + 1
    vim.cmd('silent! edit! ' .. vim.fn.fnameescape(f.file))
    local before = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    vim.cmd('silent normal! gg=G')
    local after = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    for i = 1, #before do
      if before[i] ~= after[i] then
        table.insert(bad, ('%s:%d: want %q, got %q'):format(f.file, i, before[i], after[i]))
        break
      end
    end
    vim.cmd('silent! bwipeout!')
  end
end
if #bad > 0 then
  error(('%d of %d files reindent differently:\n%s'):format(#bad, total, table.concat(bad, '\n')))
end
