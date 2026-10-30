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
