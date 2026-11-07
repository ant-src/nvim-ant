-- Apache Ant's build.xml has the filetype ant as well; its own ftplugin loads after this one.
if vim.b.did_ftplugin or require('ant').is_build_xml(0) then
  return
end
vim.b.did_ftplugin = 1

-- ant fmt indents with two spaces (fmt.md).
vim.bo.expandtab = true
vim.bo.shiftwidth = 2
vim.bo.softtabstop = 2
vim.bo.commentstring = '// %s'
vim.bo.comments = 's1:/*,mb:*,ex:*/,://!,://'
vim.bo.formatoptions = vim.bo.formatoptions:gsub('t', '') .. 'croql'
vim.bo.suffixesadd = '.ant'
vim.bo.include = [[^\s*import\s\+"\zs[^"]\+\ze"]]
vim.bo.makeprg = 'ant check %:S'
vim.bo.errorformat = '%f:%l:%c: %m,%-G%.%#'

vim.b.undo_ftplugin = 'setl et< sw< sts< cms< com< fo< sua< inc< mp< efm<'
