#!/usr/bin/env luajit
--[[
script to make an .app package
I'm using luajit for its ffi.os and ffi.arch variables

cmdline options:
- dontZip = don't make final zip file

TODO
can I make this also use .rockspec files?
can I replace this completely with .rockspec files?
would I want to?
what does this need?
- OS determination
- per-OS configuration
- copy entire folders, maybe with pattern filters (ext)


maybe todo?
- move the copy files stuff into one specific place, don't do them per-OS
- don't bother with make-per-OS, just make for every OS at once
- keep local copies of per-OS binaries?  this is looking more like UFO ...
...but then again, OS's like Android and OSX will require their own unique directory structure.
for their sake, maybe it's best to make a unique copy per-OS
what about windows vs linux?  both are basically the same, just different launch scripts ...

targets:
	win32 = Windows/x32
	win64 = Windows/x64
	linux = Linux/x64
	linux-appimage = Linux/x64 AppImage
	osx = OSX/x64 .app
	all = run all of them
	webserver = idk what I was doing with this one
--]]

-- global namespace so distinfo can see it
ffi = require 'ffi'
require 'ext.env'(_G)
local exec = require 'make.exec'

local runDir = path:cwd()

-- 'dist' project dir
local fn = package.searchpath('dist', package.path):gsub('\\', '/')
local distProjectDir = path(fn):getdir()

-- set 'all' to run all
local targets = table(cmdline.targets)
if #targets == 0 then
	local target = cmdline.target or cmdline[1]
	if not target then
	-- [[ pick target based on current arch/os ...
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
		elseif ffi.os == 'OSX' then
			target = 'osx'
		else
			error("unknown os/arch "..ffi.os..'/'..ffi.arch)
		end
	--]]
	--[[ just default to 'all' ?
		target = 'all'
	--]]
	end
	targets:insert(target)
end
assert(#targets > 0, "don't have any targets to build for")

-- 'dist' local dir for this project
local distDir = path'dist'

-- hmm just always do this?
includeLuaBinary = true

assert(loadfile('distinfo', 'bt', _G))()
assert(name)
assert(files)

-- hmmm hmmmmm
-- sometimes my 'luajit' is a script that sets up luarocks paths correctly and then runs luajit-openresty-2.1.0
luaDistVer = luaDistVer or 'luajit'
print("luaDistVer", luaDistVer)
assert.eq(luaDistVer, 'luajit')

-- TODO have a per-OS varible or something?  here? idk?
local realLuaDistVer = 'luajit'
assert.eq(realLuaDistVer, 'luajit')


local homeDir = os.getenv'HOME' or os.getenv'USERPROFILE'
local projectsDir = os.getenv'LUA_PROJECT_PATH'
-- where to find and copy luajit executable binary from

local function getDestBinPath(os, arch)
	return distProjectDir/'release/bin'/os/arch
end

-- TODO replace all exec(cp) and exec(rsync) with my own copy
-- or at least something that works on all OS's

local function copyFileToDir(basedir, srcpath, dstdir)
	basedir = path(basedir)
	srcpath = path(srcpath)
	dstdir = path(dstdir)
	local relsrcdir, srcfn = srcpath:getdir()
	if ffi.os == 'Windows' then
		-- TODO how about an 'isabsolute()' in ext.path (which I need to rename to 'ext.path' ...)
		-- welp now there is a path:abs() ...
		if srcpath.path:sub(2,3) == ':\\' then
			-- worth complaining about?
			--print("hmm how should I handle copying absolute paths to relative paths?\n".."got "..srcpath)
			relsrcdir = path'.'
		end
		(dstdir/relsrcdir):mkdir(true)
		-- /Y means suppress error on overwriting files
		exec('copy '
			..(basedir/srcpath):escape()
			..' '
			..(dstdir/relsrcdir):escape()
			..' /Y')
	else
		-- this is why luarocks requires you to map each individual files from-path to-path ...
		-- maybe don't complain here and don't append the path ...
		if srcpath.path:sub(1,1) == '/' then
			--print("hmm how should I handle copying absolute paths to relative paths?\n".."got "..srcpath)
			relsrcdir = path'.'
		end
		(dstdir/relsrcdir):mkdir(true)
		exec('cp '
			..(basedir/srcpath):escape()
			..' "'
			..(dstdir/relsrcdir)
			..'/"')	-- is it important to have that tailing / there? if so, how can ext.path accomodate...
	end
end

-- TODO ignore hidden files, or at least just skip the .git folders
local function copyDirToDir(basedir, srcdir, dstdir, pattern)
	basedir = path(basedir)
	srcdir = path(srcdir)
	dstdir = path(dstdir)
	pattern = pattern or '*'
	if ffi.os == 'Windows' then
		exec('xcopy "'
			..(basedir/srcdir)
			..'\\'..pattern
			..'" "'
			..(dstdir/srcdir)
			..'" /E /I /Y')
	else
		--exec('cp -R '..srcdir..' '..dstdir)
		exec("rsync -avm --exclude='.*' --include='"
			..pattern
			.."' -f 'hide,! */' '"
			..(basedir/srcdir)
			.."' '"
			..(dstdir/srcdir/'..')..'/'
			.."'")
	end
end

local function copyByDescTable(destDir, descTable)
	destDir = path(destDir)
	assert(type(descTable) == 'table')
	for base, filesForBase in pairs(descTable) do
		-- evaluate any env vars
		base = base:gsub('%$%b{}', function(w) return tostring(os.getenv(w:sub(3,-2))) end)

		if type(filesForBase) ~= 'table' then
			error("failed on destDir "..destDir.." got descTable "..require 'ext.tolua'(descTable))
		end
		for _,srcfn in ipairs(filesForBase) do
			local srcpath = path(base)(srcfn)
			assert(srcpath:exists(), "couldn't find "..srcpath)
			if srcpath:isdir() then
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

local function makeWinScript(arch, osDir, binDirRel)
	local runbatname = 'run-'..arch..'.bat'
	(osDir/runbatname):write(
		table{
			'setlocal',
			'cd data',
			[[set PATH=%PATH%;]]..binDirRel,
			[[set LUA_PATH=./?.lua;./?/?.lua]],
			[[set LUA_CPATH=./?.dll]],
			binDirRel(luaDistVer..'.exe')..' '
				..(getLuaArgs'win' or '')
				..' > ..\\out.txt 2> ..\\err.txt',
			'cd ..',
			'endlocal',
		}:concat'\r\n'..'\r\n'
	)
	return runbatname
end

-- the windows-specific stuff:
local function makeWin(arch)
	local bits = assert.index({x86='32',x64='64'}, arch, "don't know what bits of arch this is (32? 64? etc?)")
	local distName = name..'-win'..bits
	local osDir = distDir/distName
	osDir:mkdir()

	local binDirRel = path'bin/Windows'/arch
	local runbatname = makeWinScript(arch, osDir, binDirRel)

	-- TODO how to do this when we're not on Windows?
	if ffi.os == 'Windows' then
		-- [[ make the .lnk file since some computers give a warning when launching a .bat file
		local runlnkname = 'run-'..arch..'.lnk'
		--exec('shortcut /f:"'..(osDir/runlnkname)..'" /a:c /t:"%COMSPEC% /c setupenv.bat"')
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
		local runlnkpath = osDir/runlnkname
		runlnkpath:remove()
		local cmd = table{
			"$s=(New-Object -COM WScript.Shell).CreateShortcut('"..runlnkpath.."');",
			"$s.TargetPath='%'+'COMSPEC'+'%';",
			"$s.Arguments='/c "..runbatname.."';",
			"$s.Save()",
		}:concat()
		exec('powershell "'..cmd..'"')
		--]]
	end

	local dataDir = osDir/'data'
	dataDir:mkdir()

	local binDir = dataDir/binDirRel
	binDir:mkdir(true)

	local dstbinpath = getDestBinPath('Windows', arch)

	-- copy luajit
	copyFileToDir(dstbinpath, luaDistVer..'.exe', binDir)
	--copyFileToDir(dstbinpath, 'luajit-2.1.0-beta3-openresty.dll', binDir)
	copyFileToDir(dstbinpath, 'luajit-openresty-v2.1-20250117.dll', binDir)

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
				if dstbinpath(fn):exists() then
					copyFileToDir(dstbinpath, fn, binDir)
				else
					print("couldn't find library "..fn.." in paths "..tolua(dstbinpath))
				end
			end
		end
	end

	-- now make the zip
	if not cmdline.dontZip then
		distDir(distName..'.zip'):remove()
		exec('cd dist && tar -a -c -f "'..distName..'.zip" "'..distName..'"')
	end
end

-- osx goes in dist/osx/${name}.app/Contents/
local function makeOSX()
	assert.eq(ffi.arch, 'x64', "don't know what bits of arch this is (32? 64? etc?)")
	local distName = name..'-osx'
	-- the osx-specific stuff:
	local osDir = distDir/distName
	osDir:mkdir()
	osDir(name..'.app'):mkdir()
	local contentsDir = osDir(name..'.app/Contents')
	contentsDir:mkdir()
	contentsDir'PkgInfo':write'APPLhect'
	contentsDir'Info.plist':write([[
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
	<string>run-osx.sh</string>
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

	local macOSDir = contentsDir/'MacOS'
	macOSDir:mkdir()

	-- lemme double check the dir structure on this ...
	local runshpath = macOSDir/'run-osx.sh'
	runshpath:write(
		table{
			[[#!/usr/bin/env bash]],
			-- https://stackoverflow.com/questions/59895/can-a-bash-script-tell-what-directory-its-stored-in
			[[DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"]],
			[[cd $DIR/../Resources]],
			[[export DYLD_LIBRARY_PATH="bin/OSX"]],
			[[export LUA_PATH="./?.lua;./?/?.lua"]],
			[[export LUA_CPATH="./?.so"]],
			'./'..luaDistVer..' '
				..(getLuaArgs'osx' or '')
				..' > out.txt 2> err.txt',
		}:concat'\n'..'\n'
	)
	exec('chmod +x '..runshpath)

	local resourcesDir = contentsDir/'Resources'
	resourcesDir:mkdir()

	-- copy luajit
	local luajitPath = path(string.trim(io.readproc('which '..luaDistVer)))
	exec('cp '..luajitPath:escape()..' '..resourcesDir:escape())

	-- copy body
	copyBody(resourcesDir)

	local dstbinpath = getDestBinPath('OSX', 'x64')

	-- ffi osx so's
	local libs = getLuajitLibs'osx'
	if libs then
		local resBinDir = resourcesDir/'bin/OSX'
		resBinDir:mkdir(true)
		for _,basefn in ipairs(libs) do
			local fn = 'lib'..basefn..'.dylib'
			if dstbinpath(fn):exists() then
				copyFileToDir(dstbinpath, fn, resBinDir)
			else
				print("couldn't find library "..fn.." in paths "..tolua(dstbinpath))
			end
		end
	end

	-- now make the zip
	if not cmdline.dontZip then
		distDir(distName..'.zip'):remove()
		exec('cd dist && zip -r "'..distName..'.zip" "'..distName..'/"')
	end
end

-- TODO change runshpath based on arch? run-linux32 vs run-linux64
local function makeLinuxScript(osDir, binDirRel, scriptName, dontPipe)
	local runshpath = osDir/(scriptName or 'run-linux.sh')
	runshpath:write(
		table{
			[[#!/usr/bin/env bash]],
			'cd data',
			[[export LUA_PATH="./?.lua;./?/?.lua"]],
			[[export LUA_CPATH="./?.so"]],
			-- this is binDir relative to dataDir
			-- this line is needed for ffi's load to work
			[[export LD_LIBRARY_PATH=]]..binDirRel:escape(),
			-- this is binDir relative to dataDir
			binDirRel..'/'..realLuaDistVer..' '
				..(getLuaArgs'linux' or '')
				..(dontPipe and '' or ' > ../out.txt 2> ../err.txt'),
		}:concat'\n'..'\n'
	)
	exec('chmod +x '..runshpath)
end

-- should I include binaries in the linux distribution?
local function makeLinux(arch)
	local bits = assert.index({x86='32',x64='64'}, arch, "don't know what bits of arch this is (32? 64? etc?)")
	local distName = name..'-linux'..bits
	local osDir = distDir/distName
	osDir:mkdir()

	-- this is where luajit is relative to the runtime cwd
	local binDirRel = path'bin/Linux'/arch

	makeLinuxScript(osDir, binDirRel)

	local dataDir = osDir/'data'
	dataDir:mkdir()

	local libs = getLuajitLibs'linux'
	local binDir
	if includeLuaBinary or libs then
		binDir = dataDir/binDirRel
		binDir:mkdir(true)
	end
		-- copy luajit
	if includeLuaBinary then
		--[[
		local luajitPath = path((string.trim(io.readproc'which luajit')))
		local dir, name = luajitPath:getdir()
		copyFileToDir(dir, name, binDir)
		--]]
		-- [[
		copyFileToDir('/usr/local/bin', realLuaDistVer, binDir)
		--]]
	end

	-- copy body
	copyBody(dataDir)

	local dstbinpath = getDestBinPath('Linux', arch)

	-- copy ffi linux so's
	-- same as Windows
	if libs then
		for _,basefn in ipairs(libs) do
			local fn = 'lib'..basefn..'.so'
			if dstbinpath(fn):exists() then
				copyFileToDir(dstbinpath, fn, binDir)
			else
				print("couldn't find library "..fn.." in paths "..tolua(dstbinpath))
			end
		end
	end

	-- now make the zip
	if not cmdline.dontZip then
		distDir(distName..'.zip'):remove()
		exec('cd dist && zip -r "'..distName..'.zip" "'..distName..'/"')
	end
end

-- make for x64 only because I just don't have the x32 builds
local function makeLinuxAppImage()
	local distName = name..'-x86_64.AppDir'
	local osDir = distDir/distName
	osDir:mkdir()

	local arch = 'x64' -- TODO also 'x86' packaged together
	local binDirRel = path'bin/Linux'/arch	-- this is where luajit is relative to the runtime cwd

	--[[ do I just do AppRun here, and have the .desktop run it?
	makeLinuxScript(osDir, binDirRel, 'AppRun')
	--]]
	-- [[ or do I put the run in the usual place?
	makeLinuxScript(osDir, binDirRel, nil, true)
	local AppRunPath = osDir/'AppRun'
	AppRunPath:write[[
#!/bin/sh
cd $APPDIR
./run-linux.sh "$@"
]]
	exec('chmod +x '..AppRunPath:escape())
	--]]

	local dataDir = osDir/'data'
	dataDir:mkdir()

	local libs = getLuajitLibs'linux'
	local binDir
	if includeLuaBinary or libs then
		binDir = dataDir/binDirRel
		binDir:mkdir(true)
	end
		-- copy luajit
	if includeLuaBinary then
		--[[
		local luajitPath = path((string.trim(io.readproc'which luajit')))
		local dir, name = luajitPath:getdir()
		copyFileToDir(dir, name, binDir)
		--]]
		-- [[
		copyFileToDir('/usr/local/bin', realLuaDistVer, binDir)
		--]]
	end

	-- copy body
	copyBody(dataDir)

	local dstbinpath = getDestBinPath('Linux', arch)

	-- copy ffi linux so's
	-- same as Windows
	if libs then
		for _,basefn in ipairs(libs) do
			local fn = 'lib'..basefn..'.so'
			if dstbinpath(fn):exists() then
				copyFileToDir(dstbinpath, fn, binDir)
			else
				print("couldn't find library "..fn.." in paths "..tolua(dstbinpath))
			end
		end
	end

	-- TODO myapp.desktop file .  is it myapp.desktop or is it *my app*.desktop ?
	osDir(name..'.desktop'):write(
		table{
			'[Desktop Entry]',
			'Name='..name,			-- the name here has to match the dir being ${name}-x86_64.AppDir
			'Exec=run-linux.sh',	-- wait, should this be AppRun, or should it be run-linux.sh and AppRun points to run-linux.sh as well?

			--[[
			Icon is weird one.
			It has to be there.  You can't have no icon.  So TODO I need a default AppImage icon in the dist project here.
			You can't have an extension on the entry here, this just has to match the <file>.png I guess.
			--]]
			'Icon='..name,

			'Type=Application',
			'Categories='..(AppImageCategories or 'Utility'),

		}:concat'\n'..'\n'
	)

	-- TODO myapp.png for the icon
	-- cp from AppImageIcon to osDir/${name}.png
	local srcIconPath
	if not AppImageIcon then
		error"TODO you needn AppImageIcon for AppImage"
		-- TODO provide a default in dist/
	else
		srcIconPath = path(AppImageIcon)
	end
	exec('cp '..srcIconPath:escape()..' '..osDir(name..'.png'):escape())

	distDir:cd()
	assert(os.exec('ARCH=x86_64 appimagetool '..distName))
	runDir:cd()
end

local function makeLinuxWin64()
	local arch = 'x64'
	local distName = name..'-linux-win-64'

	-- [[ BEGIN MATCHING makeLinux
	local osDir = distDir/distName
	osDir:mkdir()

	-- this is where luajit is relative to the runtime cwd
	local binDirRel = path'bin/Linux'/arch

	makeLinuxScript(osDir, binDirRel)
	makeWinScript(arch, osDir, binDirRel)

	local dataDir = osDir/'data'
	dataDir:mkdir()

	local libs = getLuajitLibs'linux'
	local binDir
	if includeLuaBinary or libs then
		binDir = dataDir/binDirRel
		binDir:mkdir(true)
	end
		-- copy luajit
	if includeLuaBinary then
		copyFileToDir('/usr/local/bin', realLuaDistVer, binDir)
	end

	-- TODO this whole function is probably broken, and probabyl doesn't need to exist
	local dstbinpath = getDestBinPath('Linux', arch)

	-- copy body
	copyBody(dataDir)

	-- copy ffi linux so's
	-- same as Windows
	if libs then
		for _,basefn in ipairs(libs) do
			local fn = 'lib'..basefn..'.so'
			if dstbinpath(fn):exists() then
				copyFileToDir(dstbinpath, fn, binDir)
			else
				print("couldn't find library "..fn.." in paths "..tolua(dstbinpath))
			end
		end
	end
	--]]

	-- now copy the run_Windows dir to dataDir/bin/Windows
	copyDirToDir(distProjectDir/'bin/Windows', '.', dataDir/'bin/Windows')

	-- now make the zip
	-- this is assuming we're running from linux ...
	if not cmdline.dontZip then
		distDir(distName..'.zip'):remove()
		exec('cd dist && zip -r "'..distName..'.zip" "'..distName..'/"')
	end
end

-- i'm using this for a webserver distributable that assumes the host has lua already installed
-- it's a really bad hack, but I'm lazy
local function makeWebServer()
	assert(luaDistVer ~= 'luajit', "not supported just yet")
	local osDir = distDir/'webserver'
	osDir:mkdir()

	-- copy launch scripts
	assert(launchScripts, "expected launchScripts")
	copyByDescTable(osDir, launchScripts)

	local dataDir = osDir/'data'
	dataDir:mkdir()

	-- copy body
	copyBody(dataDir)
end

print('targets', targets:concat', ')
targets = targets:mapi(function(v) return true, v end):setmetatable(nil)
distDir:mkdir()
if targets.all or targets.osx then makeOSX() end
-- TODO separate os/arch like ffi does? win32 => Windows/x86, win64 => Windows/x64
if targets.all or targets.win32 then makeWin('x86') end
if targets.all or targets.win64 then makeWin('x64') end
if targets.all or targets.linux then makeLinux('x64') end
if targets.all or targets['linux-appimage'] then makeLinuxAppImage() end
if targets.linuxWin64 then makeLinuxWin64() end	-- build linux/windows x64 ... until I rethink how to break things apart and make them more modular ...
-- hmm ... I'll finish that lazy hack later
--if targets.all or targets.webserver then makeWebServer() end
