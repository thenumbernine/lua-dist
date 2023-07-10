#!/usr/bin/env luajit
-- script to make an .app package
-- I'm using luajit for its ffi.os and ffi.arch variables

local target = ... or 'all'

-- global namespace so distinfo can see it
ffi = require 'ffi'
require 'ext'

includeLuaBinary = true

assert(loadfile('distinfo', 'bt', _G))()
assert(name)
assert(files)

local homeDir = os.getenv'HOME' or os.getenv'USERPROFILE'
local projectsDir = os.getenv'LUA_PROJECT_PATH'
-- moving away from malkia ufo
--local ufoDir = projectsDir..'/../other/ufo'
-- where to find and copy luajit executable binary from
local luaBinDirs = {
	Windows = homeDir..'/bin/x64',
}
-- where to find and copy dlls/so/dylibs from
local libDirs = {
	Windows = projectsDir..'/bin/Windows',
}

local function fixpath(path)
	if ffi.os == 'Windows' then
		return path:gsub('/','\\')
	else
		return path
	end
end

local function mkdir(dir)
	return file(dir):mkdir()
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
		exec('copy "'..fixpath(srcfile)..'" "'..fixpath(dstdir)..'" /Y')
	else
		exec('cp "'..srcfile..'" "'..dstdir..'"')
	end
end

-- TODO ignore hidden files, or at least just skip the .git folders
local function copyDirToDir(srcdir, dstdir, pattern)
	local srcname = srcdir:split'/':last()
	pattern = pattern or '*'
	if ffi.os == 'Windows' then
		exec('xcopy "'..fixpath(srcdir)..'\\'..pattern..'" "'..fixpath(dstdir..'/'..srcname)..'" /E /I /Y')
	else
		--exec('cp -R '..srcdir..' '..dstdir)
		exec("rsync -avm --exclude='.*' --include='"..pattern.."' -f 'hide,! */' '"..srcname.."' '"..dstdir.."'")
	end
end

local function copyByDescTable(destDir, descTable)
	assert(type(destDir) == 'string')
	assert(type(descTable) == 'table')
	for base, filesForBase in pairs(descTable) do
		if type(filesForBase) ~= 'table' then
			error("failed on destDir "..destDir.." got descTable "..require 'ext.tolua'(descTable))
		end
		for _,fn in ipairs(filesForBase) do
			local src = base..'/'..fn
			if file(src):isdir() then
				copyDirToDir(src, destDir)
			else
				copyFileToDir(src, destDir)
			end
		end
	end
end

-- the platform-independent stuff:
local function copyBody(destDir)
	copyByDescTable(destDir, files)
end

-- returns t[plat], t[1], or t, depending on which exists and is a table
local function getForPlat(t, plat, reqtype)
	if not t then return end
	return t[plat]
		or (type(t[1]) == reqtype and t[1] or t)
end

local function getLuajitLibs(plat)
	return getForPlat(luajitLibs, plat, 'table')
end

local function getLuaArgs(plat)
	return getForPlat(luaArgs, plat, 'string')
end

-- the windows-specific stuff:
local function makeWin(arch)
	assert(arch == 'x86' or arch == 'x64', "expected arch to be x86 or x64")
	local bits = assert( ({x86='32',x64='64'})[arch], "don't know what bits of arch this is (32? 64? etc?)")
	local osDir = 'dist/win'..bits
	mkdir(osDir)

-- TODO for now windows runs with no audio and no editor.  eventually add OpenAL and C/ImGui support.
	local runBat = osDir..'/run.bat'
	file(runBat):write(
		table{
			'setlocal',
			'cd data',
			[[set PATH=%PATH%;bin\Windows\]]..arch,
			[[set LUA_PATH=./?.lua;./?/?.lua]],
		}:append(
			luaDistVer == 'luajit' and {'set LUAJIT_LIBPATH=.'} or {}
		):append{
			'bin\\Windows\\'..arch..'\\'..luaDistVer..'.exe '
				..(getLuaArgs'win' or '')
				..' > ..\\out.txt 2> ..\\err.txt',
			'cd ..',
			'endlocal',
		}:concat'\n'..'\n'
	)
	local dataDir = osDir..'/data'
	mkdir(dataDir)
	mkdir(dataDir..'/bin')
	mkdir(dataDir..'/bin/Windows')
	local binDir = dataDir..'/bin/Windows/'..arch
	mkdir(binDir)

	-- copy luajit
	copyFileToDir(luaBinDirs.Windows..'/'..luaDistVer..'.exe', binDir)

	-- copy body
	copyBody(dataDir)

	-- copy ffi windows dlls's
	local winLuajitLibs = getLuajitLibs'win'
	if winLuajitLibs then
		for _,fn in ipairs(winLuajitLibs) do
			for _,ext in ipairs{'dll','lib'} do
				copyFileToDir(libDirs.Windows..'/'..arch..'/'..fn..'.'..ext, binDir)
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
	file(contentsDir..'/PkgInfo'):write'APPLhect'
	file(contentsDir..'/Info.plist'):write([[
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
</plist>]])

	local macOSDir = contentsDir..'/MacOS'
	mkdir(macOSDir)

	-- lemme double check the dir structure on this ...
	local runSh = macOSDir..'/run.sh'
	file(runSh):write(
		table{
			[[#!/usr/bin/env bash]],
			-- https://stackoverflow.com/questions/59895/can-a-bash-script-tell-what-directory-its-stored-in
			[[DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"]],
			[[cd $DIR/../Resources]],
			[[export LUA_PATH="./?.lua;./?/?.lua"]],
		}:append(
			luaDistVer == 'luajit' and {'export LUAJIT_LIBPATH="."'} or {}
		):append{
			'./'..luaDistVer..' '
				..(getLuaArgs'osx' or '')
				..' > out.txt 2> err.txt',
		}:concat'\n'..'\n'
	)
	exec('chmod +x '..runSh)

	local resourcesDir = contentsDir..'/Resources'
	mkdir(resourcesDir)

	-- copy luajit
	local luajitPath = io.readproc('which '..luaDistVer):trim()
	exec('cp "'..luajitPath..'" "'..resourcesDir..'"')

	-- copy body
	copyBody(resourcesDir)

	-- ffi osx so's
	local osxLuajitLibs = getLuajitLibs'osx'
	if osxLuajitLibs then
		mkdir(resourcesDir..'/bin')
		mkdir(resourcesDir..'/bin/OSX')
		for _,fn in ipairs(osxLuajitLibs) do
			exec('cp "'..projectsDir..'/bin/OSX/'..fn..'.dylib" "'..resourcesDir..'/bin/OSX"')
		end
	end
end

-- should I include binaries in the linux distribution?
local function makeLinux(arch)
	assert(arch == 'x86' or arch == 'x64', "expected arch to be x86 or x64")
	local bits = assert( ({x86='32',x64='64'})[arch], "don't know what bits of arch this is (32? 64? etc?)")
	local osDir = 'dist/linux'..bits
	mkdir(osDir)

	local runSh = osDir..'/run.sh'

	file(runSh):write(
		table{
			[[#!/usr/bin/env bash]],
			'cd data',
			[[export LUA_PATH="./?.lua;./?/?.lua"]],
		}:append(
			luaDistVer == 'luajit' and {'export LUAJIT_LIBPATH="."'} or {}
		):append{
			'bin/Linux/'..arch..'/'..luaDistVer..' '
				..(getLuaArgs'linux' or '')
				..' > out.txt 2> err.txt',
		}:concat'\n'..'\n'
	)
	exec('chmod +x '..runSh)

	local dataDir = osDir..'/data'
	mkdir(dataDir)

	local linuxLuajitLibs = getLuajitLibs'linux'
	local binDir
	if includeLuaBinary or linuxLuajitLibs then
		mkdir(dataDir..'/bin')
		mkdir(dataDir..'/bin/Linux')
		binDir = dataDir..'/bin/Linux/'..arch
		mkdir(binDir)
	end
		-- copy luajit
	if includeLuaBinary then
		--[[ I don't think I'm using UFO anymore...
		copyFileToDir(ufoDir..'/bin/Linux/'..arch..'/'..luaDistVer, binDir)
		--]]
		-- [[
		local luajitPath = io.readproc'which luajit':trim()
		copyFileToDir(luajitPath, binDir)
		--]]
	end

	-- copy body
	copyBody(dataDir)

	-- copy ffi linux so's
	if linuxLuajitLibs then
		for _,fn in ipairs(linuxLuajitLibs) do
			-- TODO hmmmm ....
			copyFileToDir(ufoDir..'/bin/Linux/'..arch..'/'..fn..'.so', binDir)
		end
	end
end

-- i'm using this for a webserver distributable that assumes the host has lua already installed
-- it's a really bad hack, but I'm lazy
local function makeWebServer()
	assert(luaDistVer ~= 'luajit', "not supported just yet")
	local osDir = 'dist/webserver'
	mkdir(osDir)

	-- copy launch scripts
	assert(launchScripts, "expected launchScripts")
	copyByDescTable(osDir, launchScripts)

	local dataDir = osDir..'/data'
	mkdir(dataDir)

	-- copy body
	copyBody(dataDir)
end

mkdir('dist')
if target == 'all' or target == 'osx' then makeOSX() end
if target == 'all' or target == 'win32' then makeWin('x86') end
if target == 'all' or target == 'win64' then makeWin('x64') end
if target == 'all' or target == 'linux' then makeLinux('x64') end
-- hmm ... I'll finish that lazy hack later
--if target == 'all' or target == 'webserver' then makeWebServer() end
