[![Donate via Stripe](https://img.shields.io/badge/Donate-Stripe-green.svg)](https://buy.stripe.com/00gbJZ0OdcNs9zi288)<br>

# Distribution for Lua Projects

- In OSX this makes an .app
- In Windows this makes a folder with a run.bat
- That's all I've got for now.  maybe an Android version will come someday, based on the jni SDL + luajit build of android.

usage: `/path/to/dist/run.lua [platform]`
	where platform is all or one of the following: osx, win32, win64, linux

requires a distinfo file

`distinfo` contains the following:

name = name of project

luaArgs = lua args, or
- table of platform-specific lua args, with the first entry being the default,
- 'win' being the windows-specific args
- 'osx' being the OSX-specific args

files = key/value map where the keys is the base directory and the values are what files to copy
- all directory structure other than the base is preserved in the copy
- copies from `base/file` to `dist/data/directory/file`

luajitLibs = table of luajit libs to use, with platform-specific overrides similar to luaArgs



# Current Directory Setup

Looks like I am copying malkia's UFO for this one.

`release/` = holds stuff to be copied to each release.
-	`bin/$OS/$arch/` = holds any C-symbol libraries loaded by luajit's `ffi.load()`.  Its path is configurable in the `ffi/load.lua` file.
-	`bin/$OS/$arch/` = holds Lua libraries loaded by lua's `load()`.  Its path is configurable with the `LUA_CPATH` env var / `package.cpath` lua global.  Maybe I should separate this from the C-symbol libraries?
Looks like I am putting all OS-specific directory stuff into `bin/$OS/$arch` for now, maybe I'll break this up later.

# Libraries to be packaged with?

Ideally these will fit with the `ffi/$binding.lua` generated from include files, which would be:
- luajit2-OpenResty git tags/v2.1-20250117 aka version 2.1.1737090214 ... built with `LUAJIT_ENABLE_LUA52COMPAT` enabled
- luasocket version ... 47e5bd71a95a0a36ef5b02e5bf3af3fcab7a4409 ... since checking out v3.1.0 still has the version string set as "3.0.0"
- luasec version tags/v1.3.2
- SDL2 version tags/release-2.32.4
- LibPNG version tags/1.6.47
- zlib version tags/1.3.1
- LibTIFF tags/4.7.0
- LibOGG version
- LibVorbis tags/1.3.7
- cimgui+sdl2+opengl3 1.90.5dock ... TODO match with [lua-imgui](https://github.com/thenumbernine/lua-imgui)
- OpenAL version ... 1.1?  I think I'm using some other compat library ...
- LibClip
