#!/usr/bin/env luajit
local ffi = require 'ffi'

-- update files from install to here
local cp = ffi.os == 'Windows' and 'copy' or 'cp'
local soext = ffi.os == 'Windows' and '.dll' or (ffi.os == 'OSX' and '.dylib' or '.so')
local libprefix = ffi.os == 'Windows' and '' or 'lib'
local binext = ffi.os == 'Windows' and '.exe' or ''

--local exec = require 'ext.os'.exec
local exec = require 'make.exec'

local function copy(src, dst)
	exec((cp..' %q %q'):format(src, dst))
end

-- these are .so even in osx ... hmm ...
local srcsopath = '/usr/local/lib/lua/5.1/'
local dstsopath = 'release/bin/'..ffi.os..'/'..ffi.arch..'/'
for _,f in ipairs{
	-- luasocket
	'mime/core.so',
	'serial.so',
	'socket/core.so',
	'unix.so',
	-- luasec
	'ssl.so',
} do
	copy(srcsopath..f, dstsopath..f)
end

local srcluapath = '/usr/local/share/luajit-2.1/'
local dstluapath = 'release/'
for _,f in ipairs{
	'ltn12.lua',
	'mbox.lua',
	'mime.lua',
	'socket.lua',
	'socket/ftp.lua',
	'socket/headers.lua',
	'socket/http.lua',
	'socket/smtp.lua',
	'socket/tp.lua',
	'socket/url.lua',
	-- luasec
	'ssl.lua',
	'ssl/https.lua',
} do
	copy(srcluapath..f, dstluapath..f)
end

local srcbinpath = '/usr/local/bin/'
local dstbinpath = dstsopath
for _,f in ipairs{
	'luajit'
} do
	local f = f..binext
	copy(srcbinpath..f, dstbinpath..f)
end

local srclibpath = '/usr/local/lib/'
local dstlibpath = dstsopath
for _,f in ipairs{
	'SDL2',
	'cimgui_sdl',
	'clip',
	'ogg',
	'png',
	'tiff',
	'vorbis',
	'vorbisfile',
} do
	local f = libprefix .. f .. soext
	copy(srclibpath..f, dstlibpath..f)
end
