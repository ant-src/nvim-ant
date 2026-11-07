# Ant for Neovim

Support for the [Ant](https://github.com/ant-src/ant) programming language in Neovim 0.11+:
highlighting, indentation as `ant fmt` lays code out, the language features of `ant lsp`, including
diagnostics, completion, hover, go to definition (into the prelude too), references, rename,
formatting, inlay hints, semantic highlighting, and code lenses to run or debug a test, and
debugging through `ant dap` with [nvim-dap](https://github.com/mfussenegger/nvim-dap).

## Install ant

The plugin does not bundle `ant`:

```sh
go install github.com/ant-src/ant/cmd/ant@latest
```

It finds `ant` on `PATH` or in your Go bin directory. Set `vim.g.ant = { path = "..." }` to use
another one. `:checkhealth ant` says what it found.

## Install the plugin

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{ "ant-src/nvim-ant" }
```

With Neovim's packages:

```sh
git clone https://github.com/ant-src/nvim-ant ~/.local/share/nvim/site/pack/ant/start/nvim-ant
```

The plugin needs no `setup()`. The language server starts for every `.ant` file. Use the usual
Neovim mappings for its features: `K` for hover, `CTRL-]` for definition, `grn` to rename, `grr` for
references, `gra` for code actions, and `vim.lsp.buf.format()` to format.

## Options

```lua
vim.g.ant = {
  path = nil,  -- the ant executable; nil looks on PATH and in the Go bin directories
  lsp = true,  -- start ant lsp for Ant files
  dap = true,  -- register ant dap with nvim-dap, when it is installed
  completion = true,  -- enable vim.lsp.completion, so CTRL-X CTRL-O expands snippets
}
```

With lazy.nvim, `opts = { ... }` takes the same fields. The server's configuration is a normal
`vim.lsp.config`, so any field can be changed:

```lua
vim.lsp.config("ant", { on_attach = function(client, buf) ... end })
```

To format on save:

```lua
vim.api.nvim_create_autocmd("BufWritePre", {
  pattern = "*.ant",
  callback = function(args) vim.lsp.buf.format({ bufnr = args.buf }) end,
})
```

## Commands

- `:Ant run [args]` runs the current file with `ant run` in a terminal
- `:Ant debug [args]` debugs the current file with `ant dap` (needs nvim-dap)
- `:Ant test [pattern]` runs the tests of the current file, or of `name_test.ant` from `name.ant`,
  with `ant test`; the pattern is passed as `-run`
- `:Ant test-all [pattern]` runs every test under Neovim's working directory
- `:Ant test-nearest` runs the test the cursor is in, and `:Ant debug-nearest` debugs it
- `:Ant restart` restarts the language server
- `:Ant log` opens the LSP log

`:make` runs `ant check` on the current file and fills the quickfix list.

## Debugging

With nvim-dap installed, `:Ant debug`, or `:lua require("dap").continue()` and the "Debug Ant file"
configuration, debugs the current file. Breakpoints with conditions, hit counts, and log messages,
stepping, every goroutine's stack and variables, and the REPL work as `ant dap` serves them. A
configuration of your own takes the program and, optionally, its arguments, working directory,
environment, a file for its standard input, and whether to stop on entry; a relative path is
resolved against Neovim's working directory:

```lua
require("dap").configurations.ant = {
  { type = "ant", request = "launch", name = "Debug main", program = "main.ant", args = { "-v" } },
}
```

## Tests

In a test file (`*_test.ant`), the language server puts "run test" and "debug test" code lenses
above each test and each subtest with a literal name. Run the one on the cursor's line with
`vim.lsp.codelens.run()`, for example mapped:

```lua
vim.keymap.set("n", "<leader>l", vim.lsp.codelens.run)
```

"run test" runs `ant test -run <pattern> <file>` in a terminal; "debug test" launches `ant dap` with
`test = <pattern>`, which a configuration of your own can set too. `:Ant debug` in a test file
debugs all its tests.

## Apache Ant

Neovim gives Apache Ant's `build.xml` the filetype `ant` too. This plugin leaves `.xml` files alone,
so they keep their XML highlighting and get no Ant language server. When looking on `PATH`, it
passes over Apache Ant's `ant` launcher.

## Development

```sh
tests/run.sh               # all tests; needs ant, and ../ant for the corpus sweeps
tests/run.sh test_lsp      # one test
```

`ANT_PATH` names the `ant` to test with, `ANT_CORPUS` the directory of `.ant` files the syntax and
indentation tests sweep, and `NVIM_DAP` a checkout of nvim-dap for a real debug session.
