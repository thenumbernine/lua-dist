#!/usr/bin/env luajit
-- script to make an .app package
-- I'm using luajit for its ffi.os and ffi.arch variables

local target = ... or 'all'

-- global namespace so distinfo can see it
ffi = require 'ffi'
require 'ext'

-- hmm just always do this?
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
	Windows = homeDir..'\\bin\\'..ffi.arch,
}
-- where to find and copy dlls/so/dylibs from
local libDirs = {
	Windows = {
		homeDir..'\\bin\\'..ffi.arch,
		projectsDir..'\\bin\\Windows\\'..ffi.arch,
		'C:\\Windows\\System32',
	},
	Linux = {
		'/usr/local/lib',
		'/usr/lib/x86_64-linux-gnu',
	},
}

-- TODO use ext.file
local function fixpath(path)
	if ffi.os == 'Windows' then
		return path:gsub('/','\\')
	else
		return path
	end
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
		exec("rsync -avm --exclude='.*' --include='"..pattern.."' -f 'hide,! */' '"..fixpath(srcdir).."' '"..dstdir.."'")
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
	local osDir = 'dist/'..name..'-win'..bits
	file(osDir):mkdir()

-- TODO for now windows runs with no audio and no editor.  eventually add OpenAL and C/ImGui support.
	file(osDir..'/setupenv.bat'):write(
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
		}:concat'\r\n'..'\r\n'
	)

	--exec('shortcut /f:"'..(file(osDir)'run.lnk'):fixpathsep()..'" /a:c /t:"%COMSPEC% /c setupenv.bat"')
	-- https://stackoverflow.com/a/30029955
	-- should I finally switch from .bat to .ps1?
	-- don't use exec cuz it gsub's all /'s to \'s ... which it wouldn't need to do if i just always called fixpath everywhere ... TODO
	-- TODO escaping ... i think it saves the lnk with *MY* COMSPEC, not the string "%COMSPEC%"
	-- looks like putting a '+' in the string prevents the %'s from being used as env var delimiters ...
	-- but still it wraps the TargetPath with "'s
	--  one answer says put this after the string: -replace "`"|'"
	-- but doesn't seem to help
	-- it seems if the file is already there then powershell will modify it and append the targetpath instead of writing a new link so ...
	-- also in the windows desktop it shows a link, but if i edit it then it edits cmd.exe .... so it's a hard-link?
	local linkPath = file(osDir)'run.lnk'
	linkPath:remove()
	local cmd = [[powershell "$s=(New-Object -COM WScript.Shell).CreateShortcut(']]..linkPath:fixpathsep()..[[');$s.TargetPath='%'+'COMSPEC'+'%';$s.Arguments='/c setupenv.bat';$s.Save()"]]
	--local cmd = [[powershell "New-Item -ItemType SymbolicLink -Path ']]..file(osDir):fixpathsep()..[[' -Name run.lnk -Value '%COMSPEC% /c setupenv.bat'"]]
	print(cmd)
	os.execute(cmd)

	local dataDir = osDir..'/data'
	file(dataDir):mkdir()
	file(dataDir..'/bin'):mkdir()
	file(dataDir..'/bin/Windows'):mkdir()
	local binDir = dataDir..'/bin/Windows/'..arch
	file(binDir):mkdir()

	-- copy luajit
	copyFileToDir(luaBinDirs.Windows..'/'..luaDistVer..'.exe', binDir)
	copyFileToDir(luaBinDirs.Windows..'/luajit-2.1.0-beta3.dll', binDir)

	-- copy body
	copyBody(dataDir)

	-- copy ffi windows dlls's
	-- same as Linux
	local libs = getLuajitLibs'win'
	if libs then
		for _,basefn in ipairs(libs) do
			for _,ext in ipairs{
				'dll',
				--'lib',	-- I don't need this, do I?
			} do
				local fn = basefn..'.'..ext
				local found
				for _,srcdir in ipairs(libDirs.Windows) do
					local srcfn = srcdir..'\\'..fn
					if file(srcfn):exists() then
						copyFileToDir(srcfn, binDir)
						found = true
						break
					end
				end
				if not found then
					print("couldn't find library "..fn.." in paths "..tolua(libDirs.Windows))
				end
			end
		end
	end
end

local function makeOSX()
	-- the osx-specific stuff:
	local osDir = 'dist/osx'
	file(osDir):mkdir()
	file(osDir..'/'..name..'.app'):mkdir()
	local contentsDir = osDir..'/'..name..'.app/Contents'
	file(contentsDir):mkdir()
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
	file(macOSDir):mkdir()

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
	file(resourcesDir):mkdir()

	-- copy luajit
	local luajitPath = io.readproc('which '..luaDistVer):trim()
	exec('cp "'..luajitPath..'" "'..resourcesDir..'"')

	-- copy body
	copyBody(resourcesDir)

	-- ffi osx so's
	local libs = getLuajitLibs'osx'
	if libs then
		file(resourcesDir..'/bin'):mkdir()
		file(resourcesDir..'/bin/OSX'):mkdir()
		for _,fn in ipairs(libs) do
			exec('cp "'..projectsDir..'/bin/OSX/'..fn..'.dylib" "'..resourcesDir..'/bin/OSX"')
		end
	end
end

-- should I include binaries in the linux distribution?
local function makeLinux(arch)
	assert(arch == 'x86' or arch == 'x64', "expected arch to be x86 or x64")
	local bits = assert( ({x86='32',x64='64'})[arch], "don't know what bits of arch this is (32? 64? etc?)")
	local osDir = 'dist/'..name..'-linux'..bits
	file(osDir):mkdir()

	local runSh = osDir..'/run.sh'

	-- hmmm hmmmmm
	-- my 'luajit' is a script that sets up luarocks paths correctly and then runs luajit-openresty-2.1.0
	assert(luaDistVer == 'luajit')
	local realLuaDistVer = 'luajit-openresty-2.1.0'

	file(runSh):write(
		table{
			[[#!/usr/bin/env bash]],
			'cd data',
			[[export LUA_PATH="./?.lua;./?/?.lua"]],
			-- this is binDir relative to dataDir
			-- this line is needed for ffi's load to work
			-- TODO get rid of luajit-ffi-bindings's use of LUAJIT_LIBPATH ?
			-- and just use this instead?
			[[export LD_LIBRARY_PATH="bin/Linux/]]..arch..[["]]
		}:append(
			luaDistVer == 'luajit' and {
				'export LUAJIT_LIBPATH="."'
			} or {}
		):append{
			-- this is binDir relative to dataDir
			'bin/Linux/'..arch..'/'..realLuaDistVer..' '
				..(getLuaArgs'linux' or '')
				..' > ../out.txt 2> ../err.txt',
		}:concat'\n'..'\n'
	)
	exec('chmod +x '..runSh)

	local dataDir = osDir..'/data'
	file(dataDir):mkdir()

	local libs = getLuajitLibs'linux'
	local binDir
	if includeLuaBinary or libs then
		file(dataDir..'/bin'):mkdir()
		file(dataDir..'/bin/Linux'):mkdir()
		binDir = dataDir..'/bin/Linux/'..arch
		file(binDir):mkdir()
	end
		-- copy luajit
	if includeLuaBinary then
		--[[ I don't think I'm using UFO anymore...
		copyFileToDir(ufoDir..'/bin/Linux/'..arch..'/'..luaDistVer, binDir)
		--]]
		--[[
		local luajitPath = io.readproc'which luajit':trim()
		copyFileToDir(luajitPath, binDir)
		--]]
		-- [[
		copyFileToDir('/usr/local/bin/'..realLuaDistVer, binDir)
		--]]
	end

	-- copy body
	copyBody(dataDir)

	-- copy ffi linux so's
	-- same as Windows
	if libs then
		for _,basefn in ipairs(libs) do
			local fn = 'lib'..basefn..'.so'
			local found
			for _,srcdir in ipairs(libDirs.Linux) do
				local srcfn = srcdir..'/'..fn
				if file(srcfn):exists() then
					copyFileToDir(srcfn, binDir)
					found = true
					break
				end
			end
			if not found then
				print("couldn't find library "..fn.." in paths "..tolua(libDirs.Linux))
			end
		end
	end
end

-- i'm using this for a webserver distributable that assumes the host has lua already installed
-- it's a really bad hack, but I'm lazy
local function makeWebServer()
	assert(luaDistVer ~= 'luajit', "not supported just yet")
	local osDir = 'dist/webserver'
	file(osDir):mkdir()

	-- copy launch scripts
	assert(launchScripts, "expected launchScripts")
	copyByDescTable(osDir, launchScripts)

	local dataDir = osDir..'/data'
	file(dataDir):mkdir()

	-- copy body
	copyBody(dataDir)
end

file'dist':mkdir()
if target == 'all' or target == 'osx' then makeOSX() end
if target == 'all' or target == 'win32' then makeWin('x86') end
if target == 'all' or target == 'win64' then makeWin('x64') end
if target == 'all' or target == 'linux' then makeLinux('x64') end
-- hmm ... I'll finish that lazy hack later
--if target == 'all' or target == 'webserver' then makeWebServer() end
