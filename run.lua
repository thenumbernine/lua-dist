#!/usr/bin/env luajit
-- script to make an .app package
-- I'm using luajit for its ffi.os and ffi.arch variables

-- global namespace so distinfo can see it
ffi = require 'ffi'
require 'ext'

-- set 'all' to run all
local target = ...
if not target then
	if ffi.os == 'Windows' then
		if ffi.arch == 'x32' then
			target = 'win32'
		elseif ffi.arch == 'x64' then
			target = 'win64'
		else
			error("unknown os/arch "..ffi.os..'/'..ffi.arch)
		end
	elseif ffi.os == 'Linux' then
		target = 'linux'
	elseif fi.os == 'OSX' then
		target = 'osx'
	else
		error("unknown os/arch "..ffi.os..'/'..ffi.arch)
	end
end


-- hmm just always do this?
includeLuaBinary = true

assert(loadfile('distinfo', 'bt', _G))()
assert(name)
assert(files)

local homeDir = os.getenv'HOME' or os.getenv'USERPROFILE'
local projectsDir = os.getenv'LUA_PROJECT_PATH'
-- where to find and copy luajit executable binary from
local luaBinDirs = {
	Windows = homeDir..'\\bin\\'..ffi.arch,
}
-- where to find and copy dlls/so/dylibs from
local libDirs = {
	Windows = {
		homeDir..'\\bin\\'..ffi.arch,
		'C:\\Windows\\System32',
	},
	Linux = {
		'/usr/local/lib',
		'/usr/lib/x86_64-linux-gnu',
	},
}
-- TODO use luarocks more

local function exec(cmd)
	print(cmd)
	assert(os.execute(cmd))
end

-- TODO replace all exec(cp) and exec(rsync) with my own copy
-- or at least something that works on all OS's

local function copyFileToDir(basedir, srcpath, dstdir)
	local relsrcdir,srcfn = path(srcpath):getdir()
	if ffi.os == 'Windows' then
		-- TODO how about an 'isabsolute()' in ext.path (which I need to rename to 'ext.path' ...)
		if srcpath:sub(2,3) == ':\\' then
			-- worth complaining about?
			--print("hmm how should I handle copying absolute paths to relative paths?\n".."got "..srcpath)
			relsrcdir = '.'
		end
		(path(dstdir)/relsrcdir):mkdir(true)
		-- /Y means suppress error on overwriting files
		exec('copy "'
			..(path(basedir)/srcpath)
			..'" "'
			..(path(dstdir)/relsrcdir)
			..'" /Y')
	else
		-- this is why luarocks requires you to map each individual files from-path to-path ...
		-- maybe don't complain here and don't append the path ...
		if srcpath:sub(1,1) == '/' then
			--print("hmm how should I handle copying absolute paths to relative paths?\n".."got "..srcpath)
			relsrcdir = '.'
		end
		(path(dstdir)/relsrcdir):mkdir(true)
		exec('cp "'
			..(path(basedir)/srcpath)
			..'" "'
			..(path(dstdir)/relsrcdir)
			..'/"')
	end
end

-- TODO ignore hidden files, or at least just skip the .git folders
local function copyDirToDir(basedir, srcdir, dstdir, pattern)
	pattern = pattern or '*'
	if ffi.os == 'Windows' then
		exec('xcopy "'
			..(path(basedir)/srcdir)
			..'\\'..pattern
			..'" "'
			..(path(dstdir)/srcdir)
			..'" /E /I /Y')
	else
		--exec('cp -R '..srcdir..' '..dstdir)
		exec("rsync -avm --exclude='.*' --include='"
			..pattern
			.."' -f 'hide,! */' '"
			..(path(basedir)/srcdir)
			.."' '"
			..(path(dstdir)/srcdir/'..')..'/'
			.."'")
	end
end

local function copyByDescTable(destDir, descTable)
	assert(type(destDir) == 'string')
	assert(type(descTable) == 'table')
	for base, filesForBase in pairs(descTable) do
		-- evaluate any env vars
		base = base:gsub('%$%b{}', function(w) return tostring(os.getenv(w:sub(3,-2))) end)

		if type(filesForBase) ~= 'table' then
			error("failed on destDir "..destDir.." got descTable "..require 'ext.tolua'(descTable))
		end
		for _,srcfn in ipairs(filesForBase) do
			local srcpath = base..'/'..srcfn
			assert(path(srcpath):exists(), "couldn't find "..srcpath)
			if path(srcpath):isdir() then
				copyDirToDir(base, srcfn, destDir)
			else
				copyFileToDir(base, srcfn, destDir)
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
	local distName = name..'-win'..bits
	local osDir = 'dist/'..distName
	path(osDir):mkdir()

-- TODO for now windows runs with no audio and no editor.  eventually add OpenAL and C/ImGui support.
	path(osDir..'/setupenv.bat'):write(
		table{
			'setlocal',
			'cd data',
			[[set PATH=%PATH%;bin\Windows\]]..arch,
			[[set LUA_PATH=./?.lua;./?/?.lua]],
			[[set LUA_CPATH=./?.dll]],
			'bin\\Windows\\'..arch..'\\'..luaDistVer..'.exe '
				..(getLuaArgs'win' or '')
				..' > ..\\out.txt 2> ..\\err.txt',
			'cd ..',
			'endlocal',
		}:concat'\r\n'..'\r\n'
	)

	--exec('shortcut /f:"'..(path(osDir)'run.lnk')..'" /a:c /t:"%COMSPEC% /c setupenv.bat"')
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
	local linkPath = path(osDir)/'run.lnk'
	linkPath:remove()
	exec([[powershell "$s=(New-Object -COM WScript.Shell).CreateShortcut(']]..linkPath..[[');$s.TargetPath='%'+'COMSPEC'+'%';$s.Arguments='/c setupenv.bat';$s.Save()"]])

	local dataDir = osDir..'/data'
	path(dataDir):mkdir()
	path(dataDir..'/bin'):mkdir()
	path(dataDir..'/bin/Windows'):mkdir()
	local binDir = dataDir..'/bin/Windows/'..arch
	path(binDir):mkdir()

	-- copy luajit
	copyFileToDir(luaBinDirs.Windows, luaDistVer..'.exe', binDir)
	copyFileToDir(luaBinDirs.Windows, 'luajit-2.1.0-beta3.dll', binDir)

	-- copy body
	copyBody(dataDir)

	-- copy ffi windows dlls's
	-- same as Linux
	local libs = getLuajitLibs'win'
	if libs then
		for _,basefn in ipairs(libs) do
			for _,ext in ipairs{
				'dll',
				-- I don't need this, do I?
				--'lib',
			} do
				local fn = basefn..'.'..ext
				local found
				for _,srcdir in ipairs(libDirs.Windows) do
					if (path(srcdir)/fn):exists() then
						copyFileToDir(srcdir, fn, binDir)
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

	-- now make the zip
	path('dist/'..distName..'.zip'):remove()
	exec('cd dist && tar -a -c -f "'..distName..'.zip" "'..distName..'"')
end

local function makeOSX()
	-- the osx-specific stuff:
	local osDir = 'dist/osx'
	path(osDir):mkdir()
	path(osDir..'/'..name..'.app'):mkdir()
	local contentsDir = osDir..'/'..name..'.app/Contents'
	path(contentsDir):mkdir()
	path(contentsDir..'/PkgInfo'):write'APPLhect'
	path(contentsDir..'/Info.plist'):write([[
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
	path(macOSDir):mkdir()

	-- lemme double check the dir structure on this ...
	local runSh = macOSDir..'/run.sh'
	path(runSh):write(
		table{
			[[#!/usr/bin/env bash]],
			-- https://stackoverflow.com/questions/59895/can-a-bash-script-tell-what-directory-its-stored-in
			[[DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"]],
			[[cd $DIR/../Resources]],
			[[export LUA_PATH="./?.lua;./?/?.lua"]],
			[[export LUA_CPATH="./?.so"]],
			'./'..luaDistVer..' '
				..(getLuaArgs'osx' or '')
				..' > out.txt 2> err.txt',
		}:concat'\n'..'\n'
	)
	exec('chmod +x '..runSh)

	local resourcesDir = contentsDir..'/Resources'
	path(resourcesDir):mkdir()

	-- copy luajit
	local luajitPath = io.readproc('which '..luaDistVer):trim()
	exec('cp "'..luajitPath..'" "'..resourcesDir..'"')

	-- copy body
	copyBody(resourcesDir)

	-- ffi osx so's
	local libs = getLuajitLibs'osx'
	if libs then
		path(resourcesDir..'/bin'):mkdir()
		path(resourcesDir..'/bin/OSX'):mkdir()
		for _,fn in ipairs(libs) do
			exec('cp "'..projectsDir..'/bin/OSX/'..fn..'.dylib" "'..resourcesDir..'/bin/OSX"')
		end
	end
end

-- should I include binaries in the linux distribution?
local function makeLinux(arch)
	assert(arch == 'x86' or arch == 'x64', "expected arch to be x86 or x64")
	local bits = assert( ({x86='32',x64='64'})[arch], "don't know what bits of arch this is (32? 64? etc?)")
	local distName = name..'-linux'..bits
	local osDir = 'dist/'..distName
	path(osDir):mkdir()

	local runSh = osDir..'/run.sh'

	-- hmmm hmmmmm
	-- my 'luajit' is a script that sets up luarocks paths correctly and then runs luajit-openresty-2.1.0
	assert(luaDistVer == 'luajit')
	local realLuaDistVer = 'luajit-openresty-2.1.0'

	path(runSh):write(
		table{
			[[#!/usr/bin/env bash]],
			'cd data',
			[[export LUA_PATH="./?.lua;./?/?.lua"]],
			[[export LUA_CPATH="./?.so"]],
			-- this is binDir relative to dataDir
			-- this line is needed for ffi's load to work
			[[export LD_LIBRARY_PATH="bin/Linux/]]..arch..[["]],
			-- this is binDir relative to dataDir
			'bin/Linux/'..arch..'/'..realLuaDistVer..' '
				..(getLuaArgs'linux' or '')
				..' > ../out.txt 2> ../err.txt',
		}:concat'\n'..'\n'
	)
	exec('chmod +x '..runSh)

	local dataDir = osDir..'/data'
	path(dataDir):mkdir()

	local libs = getLuajitLibs'linux'
	local binDir
	if includeLuaBinary or libs then
		path(dataDir..'/bin'):mkdir()
		path(dataDir..'/bin/Linux'):mkdir()
		binDir = dataDir..'/bin/Linux/'..arch
		path(binDir):mkdir()
	end
		-- copy luajit
	if includeLuaBinary then
		--[[
		local luajitPath = io.readproc'which luajit':trim()
		local dir, name = path(luajitPath):getdir()
		copyFileToDir(dir, name, binDir)
		--]]
		-- [[
		copyFileToDir('/usr/local/bin', realLuaDistVer, binDir)
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
				if (path(srcdir)/fn):exists() then
					copyFileToDir(srcdir, fn, binDir)
					found = true
					break
				end
			end
			if not found then
				print("couldn't find library "..fn.." in paths "..tolua(libDirs.Linux))
			end
		end
	end

	-- now make the zip
	path('dist/'..distName..'.zip'):remove()
	exec('cd dist && zip -r "'..distName..'.zip" "'..distName..'/"')
end

-- i'm using this for a webserver distributable that assumes the host has lua already installed
-- it's a really bad hack, but I'm lazy
local function makeWebServer()
	assert(luaDistVer ~= 'luajit', "not supported just yet")
	local osDir = 'dist/webserver'
	path(osDir):mkdir()

	-- copy launch scripts
	assert(launchScripts, "expected launchScripts")
	copyByDescTable(osDir, launchScripts)

	local dataDir = osDir..'/data'
	path(dataDir):mkdir()

	-- copy body
	copyBody(dataDir)
end

path'dist':mkdir()
if target == 'all' or target == 'osx' then makeOSX() end
if target == 'all' or target == 'win32' then makeWin('x86') end
if target == 'all' or target == 'win64' then makeWin('x64') end
if target == 'all' or target == 'linux' then makeLinux('x64') end
-- hmm ... I'll finish that lazy hack later
--if target == 'all' or target == 'webserver' then makeWebServer() end
