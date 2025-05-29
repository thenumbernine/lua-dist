#!/usr/bin/env luajit
local ffi = require 'ffi'
local string = require 'ext.string'
local assert = require 'ext.assert'
local io = require 'ext.io'
local op = require 'ext.op'

local archdir = 'release/bin/'..ffi.os..'/'..ffi.arch
local binext = ffi.os == 'Windows' and '.exe' or ''
local luajit = 'luajit'..binext

--[[ use a local copy instead of whatever system location is in ffi.load
-- specify it manually here since a few of the windows dll names dont match up
local ffiload = require 'ffi.load'
ffiload.png = {Windows=archdir..'/libpng6.dll'}
ffiload.tiff = {Windows=archdir..'/tiff.dll'}
ffiload.SDL2 = {Windows=archdir..'/SDL2.dll'}
ffiload.cimgui_sdl = {Windows=archdir..'/cimgui_sdl.dll'}
ffiload.vorbis = {Windows=archdir..'/vorbisfile.dll'}

luajit = archdir..'/'..luajit
--]]

local function matchif(s, pat)
	return s:match(pat) or s
end

-- [[ luajit
local luajitVer = string.trim(io.readproc(luajit..' -v'))
print('luajit version:', matchif(luajitVer, '^LuaJIT (.*) %-%- Copyright'))
--]]

-- [[ luasocket
local socket = op.land(pcall(require, 'socket'))
print('luasocket version:', not socket and 'not found' or matchif(socket._VERSION, '^LuaSocket (.*)'))
local ssl = op.land(pcall(require, 'ssl'))
print('luasec version:', not ssl and 'not found' or ssl._VERSION)
--]]

-- [[ zlib ... used by png ... linked within png
local zlib = require 'ffi.req' 'zlib'
print('zlib header version:', zlib.ZLIB_VERSION)
print('zlib library version:', ffi.string(zlib.zlibVersion()))
--]]

-- [[ png
local png = require 'ffi.req' 'png'
print('png header version:', png.PNG_LIBPNG_VER_STRING)
print('png library version:', ffi.string(png.png_libpng_ver()))
--]]

-- [[ turbojpeg's jpeglib
local jpeg = require 'ffi.req' 'jpeg'	-- TODO rename to jpegturbo ?
print('turbojpeg header version:', jpeg.LIBJPEG_TURBO_VERSION)	-- also LIBJPEG_TURBO_VERSION_NUMBER
print('turbojpeg library version ... missing a test!')
print('turbojpeg-jpeglib header version:', jpeg.JPEG_LIB_VERSION)		-- is this the libjpeg compatability version for libjpegturbo?  Maybe I should only care about this version number?
-- there's no good runtime check, so here is our own ... maybe I'll move this to ffi/jpeg.lua
-- https://stackoverflow.com/a/19116612
do
	local jpeg_version = nil
	local err_mgr = ffi.new'struct jpeg_error_mgr[1]'
	local callback = ffi.cast('void(*)(j_common_ptr)', function(cinfo)
		jpeg_version = cinfo[0].err[0].msg_parm.i[0]
	end)
	err_mgr[0].error_exit = callback
	local cinfo = ffi.new'struct jpeg_decompress_struct[1]'
	--cinfo[0].err = jpeg.jpeg_std_error(err_mgr)	-- what does jpeg_std_error do?
	cinfo[0].err = err_mgr
	jpeg.jpeg_CreateDecompress(cinfo, -1, ffi.sizeof(cinfo))	-- version -1 means it will error
	callback:free()
	print('turbojpeg-jpeglib library version:', jpeg_version)
end
--]]

-- [[ tiff ... links jpeg, png, and zlib
local tiff = require 'ffi.req' 'tiff'
local tolua = require 'ext.tolua'
print('tiff header version:', matchif(tiff.TIFFLIB_VERSION_STR, '^LIBTIFF, Version ([^\n]*)\nCopyright'))
print('tiff library version:', matchif(ffi.string(tiff.TIFFGetVersion()), '^LIBTIFF, Version ([^\n]*)\nCopyright'))
--]]

-- [[ sdl
local sdl, SDLApp = require 'sdl.setup'()
print('sdl header version:',
	sdl.SDL_MAJOR_VERSION
	..'.'..sdl.SDL_MINOR_VERSION
	..'.'..(op.safeindex(sdl, 'SDL_PATCHLEVEL') or op.safeindex(sdl, 'SDL_MICRO_VERSION'))
	..' / '..(op.safeindex(sdl, 'SDL_COMPILEDVERSION') or op.safeindex(sdl, 'SDL_VERSION')))
print('sdl library version:', SDLApp.sdlGetVersion())
--]]

-- [[ cimgui+sdl2+opengl3
local imgui = require 'ffi.req' 'cimgui'
print('cimgui header version ... missing a test!')
print('cimgui library version:', ffi.string(imgui.igGetVersion()))
--]]

-- [[ vorbis ...
-- TODO ffi/vorbis/vorbisfile.lua has the ffi.load(vorbisfile) in it, and the prototype for vorbis_version_string
-- but vorbis.so has the definition of vorbis_version_string in it
-- but ffi/vorbis/codec.lua doesn't have a ffi.load(vorbis) in it ...
require 'ffi.req' 'vorbis.codec'
local vorbis = require 'ffi.load' 'vorbis'
print('vorbis header version ... missing a test!')
print('vorbis library version:', ffi.string(vorbis.vorbis_version_string()))
--]]

-- TODO OGG ... I don't see a version query ...
print('libogg header version ... missing a test!')
print('libogg library version ... missing a test!')
-- TODO OpenAL ... just has some VERSION macro defines, no query
print('libopenal header version ... missing a test!')
print('libopenal library version ... missing a test!')
-- TODO libclip
print('libclip header version ... missing a test!')
print('libclip library version ... missing a test!')
