[![Donate via Stripe](https://img.shields.io/badge/Donate-Stripe-green.svg)](https://buy.stripe.com/00gbJZ0OdcNs9zi288)<br>

# Distribution for Lua Projects

This will make the following:
- An OSX `.app` file that will run in OSX.
- A Windows `.zip` with a folder that contains `run.bat`.
- A Linux `.zip` with a foldre that contains `run-linux64.sh`.
- If you are on Linux and have`appimagetool` installed then you can run `dist/run.lua linux-appimage` to produce an `.AppImage` packaged executable file.

That's all I've got for now.  Maybe an Android version will come someday, based on the JNI SDL + luajit build of android, but I last used this environment 10 years ago, and over time their SDK just gets more and more unbearable.

Usage:
```
/path/to/dist/run.lua [platform]
```

Where `platform` is `all` or one of the following: `osx, win32, win64, linux, linux-appimage`.

This requires a `distinfo` file to be present in the working directory.

The `distinfo` file should contain the following variables:

`name` = name of project

`icon` = (optional) filename to icon.
- For AppImage, it must be present, and must be a `.png`, and all the docs mention "i.e. 256x256" but don't specify any hard constraints of the size.
- For OSX, icons must be in `.icns` format, and to generate it `makeicns` must be installed.

`iconOSX` = (optional) filename to an `.icns` icon used with OSX `.app` files.  If you set `icon` but not `iconOSX` then lua-dist will try to generate the `.icns` file using `makeicns`.

`luaArgs` = lua args, or
- table of platform-specific lua args, with the first entry being the default,
- `win` being the windows-specific args
- `osx` being the OSX-specific args
- `linux` being the windows-specific args

`files` = key/value map where the keys is the base directory and the values are what files to copy
- all directory structure other than the base is preserved in the copy
- copies from `base/file` to `dist/data/directory/file`

`luajitLibs` = Table of luajit libs to use, with platform-specific overrides similar to luaArgs.
This is being phased out in favor of the packaged distributables, to ensure version consistency among all OS's.
Some day I should put those packages' submodules in here and allow building them per-environment.

AppImage configuration has the following variables:

`AppImageCategories` = `Categories` of AppImage `.desktop` file.


# Current Directory Setup

I tried to avoid it for years but it looks like I am copying the design pattern of [malkia's ufo](https://github.com/malkia/ufo).

- `release/` = holds stuff to be copied to each release.
- `release/bin/$OS/$arch/` = holds any C-symbol libraries loaded by luajit's `ffi.load()`.  Its path is configurable in the `ffi/load.lua` file.
- `release/bin/$OS/$arch/` = holds Lua libraries loaded by lua's `load()`.  Its path is configurable with the `LUA_CPATH` env var / `package.cpath` lua global.  Maybe I should separate this from the C-symbol libraries?
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
- LibClip - My [fork](https://github.com/thenumbernine/clip).  Does any one know of a good cross-platform clipboard library that handles text, images (including 8bpp indexed), audio, etc?


# TODO

Really this is great and all, but, it's packaging too much.

How to tell it which supporting DLLs go with which other DLLS?

I should from the start in lua-include, in lua-ffi-bindings, and here, be collecting the following per-3rd-party-library:
- how to install?  git address, tag #, apt, brew, etc package name.
- how to generate bindings?
- which libraries are dependent

That means in lua-ffi-bindings, change it from one flat directory to instead have multiple named ones ... heck , maybe lua-ffi-bindings shouldn't exist for 3rd party bindings, but only for ISO-C / POSIX bindings?

And then *somewhere*, maybe in lua-ffi-bindings, maybe in lua-include, maybe just the root folder, *somewhere* each library should have some kind of `distinfo` or whatever in it that says those things above (how to install deps, how to gen bindings, etc)

And then lua-dist, here, shouldn't hold its own bindings (each 3rd party lib's own bindings-folder should hold them).
lua-dist here should just be wrangling them - and only the needed 3rd-party-binding-folders - and only the associated-per-os-libs that should be stored in those folders - and from that making the per-os-distributable file.

So each 3rd-party-folder should have in it:
- install info.  ex: lib-clip:
``` Lua
{
	git = 'https://github.com/thenumbernine/clip/'
	branch = 'master', -- or maybe tag = '1.2.3',
	build = 'cmake',	-- or maybe build = 'mkdir build && cd build && cmake ..',
	-- and then maybe some info on where to find the built binary, and where to package it per-OS
},
```

- lua-include generation information. ex: lib-clip:
``` Lua
{
	inc = '<cclip.h>',
	--out = 'cclip.lua',
	-- and this would before go into 'ffi/cclip.lua'
	-- ... maybe it should go somewhere per-3rd-party like ...
	out = 'clip/ffi.lua',
	final = function(code)
		code = code .. "\nreturn require 'ffi.load' 'clip'\n"	-- load libclip.so / libclip.dylib / clip.dll
		return code
	end,
},
```
- lua-api-interface.  i.e. contents of `https://github.com/thenumbernine/lua-clip`
So really I'm proposing to merge the per-3rd-party stuff into their own individual folders.
Final result would look like:
- clip/
	- `clip.lua` (or if you don't have `?/?.lua` in your path, this goes in root)
	- `install/`-- or maybe this is just a single file
		- that "install info" above
	- `make-ffi/` or include/ or binding/ or generate-bindings/ or something ...
		- that "lua-include generation information" above ...
		- ... maybe this can be a single file too ... maybe merge it with the 'install' file ... maybe merge it with the 'distinfo' file ... maybe merge it with '.rockspec' file ...
	- `ffi.lua` -- this would be what was stored in lua-ffi-bindings' `ffi/clip.lua`
	- `bin`	-- store binary distributables here.  seems to be polluting repos. but in the name of easily producing cross-platform-distributables...
		- `$os/`
			- `$arch/`
				- `[lib]clip.[so|dylib|dll]`

Then, in `clip.lua`, instead of going to ffi/clip.lua and trusting that another repo is there there, we would go to clip/ffi.lua.

Then for installation, we just copy these folders as they are.

But what about search paths?  Especially `$PATH` and especially `$LUA_CPATH` ...

I'm thinking, put `$LUA_CPATH` libraries, i.e. luasocket and luasec, into their own folder, separate of the bin folder ... typically lua searches for scripts in `/usr/share/lua/` and lua libs in `/usr/lib/lua/`, but I want `lib/` for the system libs that ffi will link into,
so maybe I'll put `$LUA_CPATH` libs into another folder like `lualib/`...

Or maybe just take any repo as-is, like the `clip` C++/cmake repo, and just give it a `distinfo` file that tells it:
- where the install-binary-libraries can be found
- ... and where to copy them (distlua/bin by default?)
- what the binding-generation info is
- where the lua-path directory is (distlua/share by default?)
- where the lua-cpath direcory is (distlua/lib by default?)
