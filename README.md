[![Donate via Stripe](https://img.shields.io/badge/Donate-Stripe-green.svg)](https://buy.stripe.com/00gbJZ0OdcNs9zi288)<br>
[![Donate via Bitcoin](https://img.shields.io/badge/Donate-Bitcoin-green.svg)](bitcoin:37fsp7qQKU8XoHZGRQvVzQVP8FrEJ73cSJ)<br>
[![Donate via Paypal](https://img.shields.io/badge/Donate-Paypal-green.svg)](https://buy.stripe.com/00gbJZ0OdcNs9zi288)

# Distribution for Lua Projects

- In OSX this makes an .app
- In Windows this makes a folder with a run.bat
- That's all I've got for now.  maybe an Android version will come someday, based on the jni SDL + luajit build of android.

usage: `/path/to/dist/run.lua [platform]`
	where platform is all or one of the following: osx, win32, win64

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
