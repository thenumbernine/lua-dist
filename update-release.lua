#!/usr/bin/env luajit
local ffi = require 'ffi'
local path = require 'ext.path'
local table = require 'ext.table'
local os = require 'ext.os'

-- update files from install to here
local cp = ffi.os == 'Windows' and 'copy' or 'cp'
local soext = ffi.os == 'Windows' and '.dll' or (ffi.os == 'OSX' and '.dylib' or '.so')
local libprefix = ffi.os == 'Windows' and '' or 'lib'
local binext = ffi.os == 'Windows' and '.exe' or ''

local exec = os.exec
--local exec = require 'make.exec'

local function copy(src, dst, mode)
	dst:getdir():mkdir(true)
	exec(table{
		cp,
		src:escape(),
		dst:escape(),
	}:concat' ')
	if ffi.os ~= 'Windows' then
		exec(table{
			'chmod',
			mode or '644',
			dst:escape(),
		}:concat' ')
	end
end

-- these are .so even in osx ... hmm ...
local srcsopath = path'/usr/local/lib/lua/5.1/'
local dstsopath = path'release/bin/'/ffi.os/ffi.arch
for _,f in ipairs{
	-- luasocket
	'mime/core.so',
	'serial.so',
	'socket/core.so',
	'unix.so',
	-- luasec
	'ssl.so',
} do
	copy(srcsopath/f, dstsopath/f)
end

local srcluapath = path'/usr/local/share/luajit-2.1/'
local dstluapath = path'release/'
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
	copy(srcluapath/f, dstluapath/f)
end

local srcbinpath = path'/usr/local/bin/'
local dstbinpath = dstsopath
for _,f in ipairs{
	'luajit',
} do
	local f = f..binext
	local srcf = ffi.os == 'Linux' and 'luajit-2.1.1737090214' or f
	copy(srcbinpath/srcf, dstbinpath/f, '755')
end

local srclibpath = path'/usr/local/lib/'
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
	copy(srclibpath/f, dstlibpath/f)
end
