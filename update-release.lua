#!/usr/bin/env luajit
local ffi = require 'ffi'
local path = require 'ext.path'
local table = require 'ext.table'
local assert = require 'ext.assert'
local os = require 'ext.os'

-- update files from install to here
local cp = ffi.os == 'Windows' and 'copy' or 'cp'
local soext = ffi.os == 'Windows' and '.dll' or (ffi.os == 'OSX' and '.dylib' or '.so')
local libprefix = ffi.os == 'Windows' and '' or 'lib'
local binext = ffi.os == 'Windows' and '.exe' or ''

local homeDir = os.getenv'HOME' or os.getenv'USERPROFILE'

local exec = os.exec
--local exec = require 'make.exec'

local function copy(src, dst, mode)
	dst:getdir():mkdir(true)
	exec(table{
		cp,
		src:escape(),
		dst:escape(),
	}
	:append(ffi.os == 'Windows' and {'/Y'} or {})
	:concat' ')
	if ffi.os ~= 'Windows' then
		exec(table{
			'chmod',
			mode or '644',
			dst:escape(),
		}:concat' ')
	end
end

--[[
args:
	filename
	srcs
	dst
	mode
--]]
local function copyFirst(args)
	local found
	for _,srcdir in ipairs(assert.index(args, 'srcs')) do
		local srcpath = path(srcdir)/f
		if srcpath:exists() then
			copy(srcpath, assert.index(args, 'dst')/f, args.mode)
			found = true
			break
		end
	end
	-- if none found then complain
	if not found then
		print("couldn't find "..f)
	end
	return found
end

-- should I be putting luarocks libraries and normie libraries in the same place?
local dstbinpath = path'release/bin'/ffi.os/ffi.arch

-- copy luarocks libraries
-- these are .so even in osx ... hmm ...
for _,f in ipairs{
	-- luasocket
	'mime/core.so',
	'serial.so',
	'socket/core.so',
	'unix.so',
	-- luasec
	'ssl.so',
} do
	copy(
		path'/usr/local/lib/lua/5.1'/f,
		dstbinpath/f
	)
end

-- copy luarocks lua files
local dstluapath = path'release'
for _,f in ipairs{
	-- luasocket
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
	copy(
		-- src
		path(assert.index({
			OSX = function() return '/usr/local/share/luajit-2.1/' end,
			Linux = function() return '/usr/local/share/lua/5.1/' end,
			Windows = function() error'TODO' end,
		}, ffi.os)()) / f,
		-- dest
		dstluapath / f)
end

-- copy luajit executable
do
	copy(
		-- src
		assert.index({
			OSX = (path'/usr/local/bin/') / 'luajit',
			Linux = (path'/usr/local/bin/') / 'luajit-2.1.1737090214',
			Windows = homeDir..'\\bin\\'..ffi.arch..'\\luajit.exe',
		}, ffi.os),
		-- dest
		dstbinpath / ('luajit'..binext),
		'755'
	)
end

-- copy libraries
for _,f in ipairs{
	'SDL2',
	'cimgui_sdl',
	'clip',
	'ogg',
	'png',
	'tiff',
	'vorbis',
	'vorbisfile',
	'z',
} do
	local f = libprefix .. f .. soext
	copyFirst{
		filename = f,
		srcs = assert.index({
			OSX = {
				'/usr/local/lib',
			},
			Linux = {
				'/usr/local/lib',
				'/usr/lib/x86_64-linux-gnu',
			},
			Windows = {
				homeDir..'\\bin\\'..ffi.arch,
				'C:\\Windows\\System32',
			},
		}, ffi.os),
		dst = dstbinpath,
	}
end
