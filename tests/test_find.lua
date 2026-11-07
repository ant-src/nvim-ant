local h = dofile('tests/helpers.lua')
local ant = require('ant')

-- Apache Ant's launcher on PATH is passed over for the Ant executable after it.
local dir = vim.fn.tempname()
local apache, real = vim.fs.joinpath(dir, 'apache'), vim.fs.joinpath(dir, 'real')
vim.fn.mkdir(apache, 'p')
vim.fn.mkdir(real, 'p')
vim.fn.writefile({ '#!/usr/bin/env bash', 'ANT_HOME=/usr/share/ant', 'exec java "$@"' }, vim.fs.joinpath(apache, 'ant'))
vim.fn.writefile({ '#!/bin/sh', 'exec true' }, vim.fs.joinpath(real, 'ant'))
vim.fn.setfperm(vim.fs.joinpath(apache, 'ant'), 'rwxr-xr-x')
vim.fn.setfperm(vim.fs.joinpath(real, 'ant'), 'rwxr-xr-x')
vim.env.PATH = apache .. ':' .. real .. ':' .. vim.env.PATH
vim.g.ant = nil
ant.forget()
h.eq(vim.fs.joinpath(real, 'ant'), ant.find(), 'Apache Ant skipped')

-- Setting the path option takes effect at the next find, with no restart.
vim.g.ant = { path = '/somewhere/ant' }
h.eq('/somewhere/ant', ant.find(), 'path option')
vim.g.ant = nil
h.eq(vim.fs.joinpath(real, 'ant'), ant.find(), 'path option removed')

-- Of a GOPATH with several entries, ant is looked for in the bin directory of the first.
local gopath1, gopath2, godir = vim.fs.joinpath(dir, 'gp1'), vim.fs.joinpath(dir, 'gp2'), vim.fs.joinpath(dir, 'go')
vim.fn.mkdir(vim.fs.joinpath(gopath1, 'bin'), 'p')
vim.fn.mkdir(gopath2, 'p')
vim.fn.mkdir(godir, 'p')
vim.fn.writefile({ '#!/bin/sh', 'exec true' }, vim.fs.joinpath(gopath1, 'bin', 'ant'))
vim.fn.setfperm(vim.fs.joinpath(gopath1, 'bin', 'ant'), 'rwxr-xr-x')
vim.fn.writefile({ '#!/bin/sh', 'echo ' .. gopath1 .. ':' .. gopath2 }, vim.fs.joinpath(godir, 'go'))
vim.fn.setfperm(vim.fs.joinpath(godir, 'go'), 'rwxr-xr-x')
vim.env.PATH = godir
vim.env.GOBIN = nil
ant.forget()
h.eq(vim.fs.joinpath(gopath1, 'bin', 'ant'), ant.find(), 'first GOPATH entry')
