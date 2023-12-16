--shortcut for -ldist
-- if we did use lua -ldist, then in order to determine where 'dist' is, we must search through package.path
local path = require 'ext.path'
local fn = package.searchpath('dist', package.path)
fn = fn:gsub('\\', '/')
local dir = path(fn):getdir()
dofile(dir..'/run.lua')
os.exit()
