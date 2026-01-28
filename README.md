[![Donate via Stripe](https://img.shields.io/badge/Donate-Stripe-green.svg)](https://buy.stripe.com/00gbJZ0OdcNs9zi288)<br>

# Distribution for Lua Projects

# How to build a distributable for Lua Projects

Chdir to your Lua project repository,

make sure there is a `distinfo` file present,

and run `../path/to/dist/run.lua`

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

## The `distinfo` file:

The `distinfo` file can be automatically created from a github repo by running `/path/to/dist/build-distinfo.rua`.  (The `.rua` extension is for my [langfix](https://github.com/thenumbernine/langfix-lua) script).

The `distinfo` file should contain the following variables:

`startDir` = what path within the directory structure to start at.

`files` = list of what files to copy.  copies from `dirname/file` to `dist/data/dirname/file`

`deps` = key/value where the resulting `key/value/` path is searched for another `distinfo` file to determine which files to copy.

### application configuration variables:

`name` = name of project / folder to name the repo / name of folder in the distributable's base Lua folder.

`icon` = (optional) filename to icon.
- For AppImage, it must be present, and must be a `.png`, and all the docs mention "i.e. 256x256" but don't specify any hard constraints of the size.
- For OSX, icons must be in `.icns` format, and to generate it `makeicns` must be installed.

`iconOSX` = (optional) filename to an `.icns` icon used with OSX `.app` files.  If you set `icon` but not `iconOSX` then lua-dist will try to generate the `.icns` file using `makeicns`.

`luaArgs` = lua args, or
- table of platform-specific lua args, with the first entry being the default,
- `win` being the windows-specific args
- `osx` being the OSX-specific args
- `linux` being the windows-specific args

### AppImage configuration has the following variables:

`AppImageCategories` = `Categories` of AppImage `.desktop` file.

### binding generation

- `generateBindings` = function that returns a list of binding-generators to be used with my lua-include project for generating bindings, typically placed in `<library-name>/ffi/<binding-name>.lua`.
- lua-include generation information. ex: lib-clip:
``` Lua
generateBindings = function()
	return {
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
	}
end
```

# Other Scripts In This Repo:

- `dist.lua`: This is a shorthand wrapper so that ideally `luajit -ldist` does the same as `/path/to/dist/run.lua` would.  Tempted to get rid of this.

- `check_versions.rua`: This is a helper script for printing out the include-binding version and the library version of a few installed libraries.

- `update-release.lua`: This copies the binaries from your OS folders to the `release/bin/$os/$arch/` folder.
	This is a design aspect I'm rethinking.
	Maybe I'll change this script to run in a relative project's folder, check its distinfo for some thing that tells it where to copy OS libs from, and do the copying.

- `build-distinfo.rua`: Run this from a repo's cwd to have it produce a `distinfo` library file.  The file will contain:
- - the library/cwd name
- - a list of files from the repo
- - a parsed scan of those files for `require()` for any dependent `distinfo`-based repos.

# Current Directory Setup

I am copying heavily from the design pattern of [malkia's ufo](https://github.com/malkia/ufo).

- `release/` = holds stuff to be copied to each release.
- `release/bin/$OS/$arch/` = holds any C-symbol libraries loaded by luajit's `ffi.load()`.  Its path is configurable in the `ffi/load.lua` file.
- `release/bin/$OS/$arch/` = holds Lua libraries loaded by lua's `load()`.  Its path is configurable with the `LUA_CPATH` env var / `package.cpath` lua global.  Maybe I should separate this from the C-symbol libraries?

Looks like I am putting all OS-specific directory stuff into `bin/$OS/$arch` for now, maybe I'll break this up later.

# Libraries to be packaged with?

Ideally these will fit with the `ffi/$binding.lua` generated from include files, which would be:
- luajit2-OpenResty git tags/v2.1-20250117 aka version 2.1.1737090214 ... built with `LUAJIT_ENABLE_LUA52COMPAT` enabled
- luasocket version ... 47e5bd71a95a0a36ef5b02e5bf3af3fcab7a4409 ... since checking out v3.1.0 still has the version string set as "3.0.0"
- luasec version tags/v1.3.2


# TODO

Maybe something like:
- install info.  ex: lib-clip:
``` Lua
{
	git = 'https://github.com/thenumbernine/clip/'
	branch = 'master', -- or maybe tag = '1.2.3',
	build = 'cmake',	-- or maybe build = 'mkdir build && cd build && cmake ..',
	-- and then maybe some info on where to find the built binary, and where to package it per-OS
},
```

But what about search paths?  Especially `$PATH` and especially `$LUA_CPATH` ...

I'm thinking, put `$LUA_CPATH` libraries, i.e. luasocket and luasec, into their own folder, separate of the bin folder ... typically lua searches for scripts in `/usr/share/lua/` and lua libs in `/usr/lib/lua/`, but I want `lib/` for the system libs that ffi will link into,
so maybe I'll put `$LUA_CPATH` libs into another folder like `lualib/`...

Or maybe just take any repo as-is, like the `clip` C++/cmake repo, and just give it a `distinfo` file that tells it:
- where the install-binary-libraries can be found
- ... and where to copy them (distlua/bin by default?)
- what the binding-generation info is
- where the lua-path directory is (distlua/share by default?)
- where the lua-cpath direcory is (distlua/lib by default?)

- TODO for external packages that are used, such as dkjson, sha2, luasocket, lua-ssl ...
