#!/usr/bin/env luajit
local ffi = require 'ffi'
local string = require 'ext.string'
local assert = require 'ext.assert'
local io = require 'ext.io'

local binext = ffi.os == 'Windows' and '.exe' or ''
local libprefix = ffi.os == 'Windows' and '' or 'lib'
local libext = ({Windows='dll', OSX='dylib'})[ffi.os] or 'so'

local distarchdir = 'release/bin/'..ffi.os..'/'..ffi.arch

-- [[ luajit
local luajitVer = string.trim(io.readproc(distarchdir..'/luajit'..binext..' -v'))
	:match'^LuaJIT (.*) %-'
print('luajit version:', luajitVer)
--]]

local function getLibName(name)
	--[[ use machine local copy
	-- TODO latest luajit2-openresty version isn't finding libraries ...
	-- ... maybe because it's not finding its own library?  idk
	return name
	--]]
	-- [[ use copy saved in dist/release
	return distarchdir..'/'..libprefix..name..'.'..libext
	--]]
end

-- [[ luasocket
print('luasocket version: '..require'socket'._VERSION:match'^LuaSocket (.*)$')
print('luasec version: '..require'ssl'._VERSION)
--]]

-- [[ png
require 'ffi.load'.png = getLibName'png'
local png = require 'ffi.req' 'png'
print('png header version:', png.PNG_LIBPNG_VER_STRING)
print('png library version:', ffi.string(png.png_get_libpng_ver(nil)))
--]]

-- [[ sdl2
require 'ffi.load'.SDL2 = getLibName'SDL2'
local sdl = require 'ffi.req' 'sdl'
print('sdl header version:', sdl.SDL_MAJOR_VERSION..'.'..sdl.SDL_MINOR_VERSION..'.'..sdl.SDL_PATCHLEVEL..' compiled:'..sdl.SDL_COMPILEDVERSION)
local sdlver = ffi.new'SDL_version'
sdl.SDL_GetVersion(sdlver)
print('sdl library version:', sdlver.major..'.'..sdlver.minor..'.'..sdlver.patch)
--]]

-- [[ cimgui+sdl2+opengl3
require 'ffi.load'.cimgui_sdl = getLibName'cimgui_sdl'
local imgui = require 'ffi.req' 'cimgui'
print('cimgui library version:', ffi.string(imgui.igGetVersion()))
print('cimgui header version missing a test!')
--]]

-- [[ vorbis ... 
-- TODO ffi/vorbis/vorbisfile.lua has the ffi.load(vorbisfile) in it, and the prototype for vorbis_version_string
-- but vorbis.so has the definition of vorbis_version_string in it
-- but ffi/vorbis/codec.lua doesn't have a ffi.load(vorbis) in it ...
require 'ffi.load'.vorbis = getLibName'vorbisfile'
require 'ffi.req' 'vorbis.codec'
local vorbis = require 'ffi.load' 'vorbis'
print('vorbis library version: '..ffi.string(vorbis.vorbis_version_string())) --:match'^Xiph%.Org libVorbis (.*)$')
print('vorbis header version missing a test!')
--]]

-- TODO OGG ... I don't see a version query ...
print('libogg header version missing a test!')
print('libogg library version missing a test!')
-- TODO OpenAL ... just has some VERSION macro defines, no query
print('libopenal header version missing a test!')
print('libopenal library version missing a test!')
-- TODO libclip
print('libclip header version missing a test!')
print('libclip library version missing a test!')
