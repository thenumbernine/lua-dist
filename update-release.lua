#!/usr/bin/env luajit

local srcsopath = '/usr/local/lib/lua/5.1/'
local dstsopath = 'release/bin/'..ffi.os..'/'..ffi.arch..'/'

-- update files from install to here
for _,f in ipairs{
	-- luasocket
	'mime/core.so',
	'serial.so',
	'socket/core.so',
	'unix.so',
	-- luasec
	'ssl.so',
} do
	os.exec(('cp %q %q'):format(srcsopath..f, dstsopath..f))
end

local srcluapath = '/usr/local/share/luajit-2.1/'
local dstluapath = 'release'
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
	os.exec(('cp %q %q'):format(srcluapath..f, dstluapath..f))
end
