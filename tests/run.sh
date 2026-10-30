#!/bin/sh
# Runs the tests in a clean Neovim: tests/run.sh [test_name ...]. ANT_PATH names the ant to use
# (default: ant on PATH); ANT_CORPUS a directory of .ant files to sweep (default: ../ant); NVIM_DAP
# a checkout of nvim-dap, without which the debugger test checks only what the plugin registers.
set -u
cd "$(dirname "$0")/.."
root=$PWD
fail=0
dap=
if [ -n "${NVIM_DAP:-}" ]; then
  dap="set rtp+=$NVIM_DAP"
fi
# Every test uses ANT_PATH, so that an ant elsewhere on PATH, or none, does not matter.
path=
if [ -n "${ANT_PATH:-}" ]; then
  path="lua vim.g.ant = { path = vim.env.ANT_PATH }"
fi
if [ $# -eq 0 ]; then
  set -- tests/test_*.lua
fi
for t in "$@"; do
  case $t in tests/*) ;; *) t=tests/$t.lua ;; esac
  printf '%s ' "$t"
  if nvim --headless --clean --cmd "set rtp^=$root" --cmd "$dap" --cmd "$path" \
    -c 'syntax on' -c 'filetype plugin indent on' \
    -c "lua local ok, err = xpcall(dofile, debug.traceback, '$t'); if not ok then io.stderr:write(err .. '\n'); vim.cmd('cquit 1') end; vim.cmd('qall!')" </dev/null; then
    echo ok
  else
    echo FAIL
    fail=1
  fi
done
exit $fail
