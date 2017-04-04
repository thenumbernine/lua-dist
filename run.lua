#!/usr/bin/env luajit
-- script to make an .app package
-- I'm using luajit for its ffi.os and ffi.arch variables

local target = ...

local ffi = require 'ffi'
require 'ext'

assert(loadfile('distinfo', 'bt', _G))()
assert(name)
assert(files)

local function fixpath(path)
	if ffi.os == 'Windows' then
		return path:gsub('/','\\')
	else
		return path
	end
end

local function mkdir(dir)
	local cmd = 'mkdir '..fixpath(dir)
	print(cmd)
	os.execute(cmd)
end

local function exec(cmd)
	print(cmd)
	assert(os.execute(cmd))
end

-- TODO replace all exec(cp) and exec(rsync) with my own copy
-- or at least something that works on all OS's

local function copyFileToDir(srcfile,dstdir)
	if ffi.os == 'Windows' then
		-- /Y means suppress error on overwriting files
		exec('copy '..fixpath(srcfile)..' '..fixpath(dstdir)..' /Y')
	else
		exec('cp '..srcfile..' '..dstdir)
	end
end

local function copyDirToDir(srcdir, dstdir)
	if ffi.os == 'Windows' then
		-- all files
		exec('xcopy '..fixpath(srcdir)..' '..fixpath(dstdir..'/'..srcdir)..' /E /I /Y')
		-- lua files only?
		--exec('xcopy '..fixpath(srcdir)..'\\*.lua '..fixpath(dstdir..'/'..srcdir)..' /E /I /Y')
	else
		-- all files
		exec('cp -R '..srcdir..' '..dstdir)
		-- lua files only?
		--exec("rsync -avm --include='*.lua' -f 'hide,! */' "..srcdir.." "..dstdir)
	end
end

-- the platform-independent stuff:
local function copyBody(destDir)
	for base, filesForBase in pairs(files) do
		for _,file in ipairs(filesForBase) do
			local src = base..'/'..file
			if io.isdir(src) then
				copyDirToDir(src, destDir)
			else
				copyFileToDir(src, destDir)
			end
		end
	end
end

-- returns t[plat], t[1], or t, depending on which exists and is a table 
local function getForPlat(t, plat)
	if not t then return end
	return t[plat] 
		or (type(t[1]) == 'table' and t[1] or t)
end

local function getLuajitLibs(plat)
	return getForPlat(luajitLibs, plat)
end

local function getLuaArgs(plat)
	return getForPlat(luaArgs, plat)
end

mkdir('dist')

-- the windows-specific stuff:
local function makeWin(arch)
	assert(arch == 'x86' or arch == 'x64', "expected arch to be x86 or x64")
	local bits = assert( ({x86='32',x64='64'})[arch], "don't know what bits of windows this is (32? 64? etc?)")
	local osDir = 'dist/win'..bits
	mkdir(osDir)
	local runBat = osDir..'/run.bat'

-- TODO for now windows runs with no audio and no editor.  eventually add OpenAL and C/ImGui support. 
	local winLuaArgs = getLuaArgs'win'
	file[runBat] = table{
		'cd data',
		[[set PATH=%PATH%;bin\Windows\]]..arch,
		[[set LUA_PATH=./?.lua;./?/?.lua]],
	}:append(
		luaDistVer == 'luajit' and {'set LUAJIT_LIBPATH=.'} or {}
	):append{
		[[bin\Windows\x86\]]..luaDistVer..'.exe '..winLuaArgs..' > out.txt 2> err.txt',
		'cd ..'
	}:concat'\n'..'\n'

	local dataDir = osDir..'/data'
	mkdir(dataDir)
	mkdir(dataDir..'/bin')
	mkdir(dataDir..'/bin/Windows')
	local binDir = dataDir..'/bin/Windows/'..arch
	mkdir(binDir)
	
	-- copy luajit
	copyFileToDir('../ufo/bin/Windows/'..arch..'/'..luaDistVer..'.exe', binDir)
	
	-- copy body
	copyBody(dataDir)

	-- copy ffi windows dlls's
	local winLuajitLibs = getLuajitLibs'win'
	if winLuajitLibs then
		for _,fn in ipairs(winLuajitLibs) do
			for _,ext in ipairs{'dll','lib'} do
				copyFileToDir('../ufo/bin/Windows/'..arch..'/'..fn..'.'..ext, binDir)
			end
		end
	end
end

local function makeOSX()
	-- the osx-specific stuff:
	local osDir = 'dist/osx'
	mkdir(osDir)
	mkdir(osDir..'/'..name..'.app')
	local contentsDir = osDir..'/'..name..'.app/Contents'
	mkdir(contentsDir)
	file[contentsDir..'/PkgInfo'] = 'APPLhect'
	file[contentsDir..'/Info.plist'] = [[
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleName</key>
	<string>]]..name..[[</string>
	<key>CFBundleIdentifier</key>
	<string>net.christopheremoore.]]..name..[[</string>
	<key>CFBundleVersion</key>
	<string>1.0</string>
	<key>CFBundleIconFile</key>
	<string>Icons</string>
	<key>CFBundleDevelopmentRegion</key>
	<string>English</string>
	<key>CFBundleDocumentTypes</key>
	<array/>
	<key>CFBundleExecutable</key>
	<string>run.sh</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>1.0</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleSignature</key>
	<string>hect</string>
	<key>NSMainNibFile</key>
	<string>MainMenu</string>
	<key>NSPrincipalClass</key>
	<string>NSApplication</string>
</dict>
</plist>]]

	local osxLuaArgs = getLuaArgs'osx'
	local macOSDir = contentsDir..'/MacOS'
	mkdir(macOSDir)
	local runSh = macOSDir..'/run.sh' 
	file[runSh] = table{
		[[#!/usr/bin/env bash]],
		-- https://stackoverflow.com/questions/59895/can-a-bash-script-tell-what-directory-its-stored-in
		[[DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"]],
		[[cd $DIR/../Resources]],
		[[export LUA_PATH="./?.lua;./?/?.lua"]],
	}:append(
		luaDistVer == 'luajit' and {'export LUAJIT_LIBPATH="."'} or {}
	):append{
		'./'..luaDistVer..' '..osxLuaArgs..' > out.txt 2> err.txt',
	}:concat'\n'..'\n'
	exec('chmod +x '..runSh)

	local resourcesDir = contentsDir..'/Resources'
	mkdir(resourcesDir)

	-- copy luajit
	local luajitPath = io.readproc('which '..luaDistVer):trim()
	exec('cp '..luajitPath..' '..resourcesDir)

	-- copy body
	copyBody(resourcesDir)
	
	-- ffi osx so's
	local osxLuajitLibs = getLuajitLibs'osx'
	if osxLuajitLibs then
		mkdir(resourcesDir..'/bin')
		mkdir(resourcesDir..'/bin/OSX')
		for _,fn in ipairs(osxLuajitLibs) do
			exec('cp ../bin/OSX/'..fn..'.dylib '..resourcesDir..'/bin/OSX')
		end
	end
end


if target == 'all' or target == 'osx' then makeOSX() end
if target == 'all' or target == 'win32' then makeWin('x86') end
--if target == 'all' or target == 'win64' then makeWin('x64') end -- ufo only runs the 64 bit versions for amd ...
