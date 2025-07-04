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

local defaultIconPath = distProjectDir'default-icon.png'

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
assert(distDir.cd, "lfs_ffi might not have loaded correctly. check lfs_ffi.")

assert(loadfile('distinfo', 'bt', _G))()
assert(name)
assert(files)

-- hmmm hmmmmm
-- sometimes my 'luajit' is a script that sets up luarocks paths correctly and then runs luajit-openresty-2.1.0
luaDistVer = luaDistVer or 'luajit'
print("luaDistVer", luaDistVer)
assert.eq(luaDistVer, 'luajit')

-- needed by the windows build ... why not build static?
local luaLibVer = 'luajit-2.1-20250117.dll'


local homeDir = path((assert(os.getenv'HOME' or os.getenv'USERPROFILE', "failed to find your home dir")))
local projectsDir = homeDir/'Projects/lua'	-- where to find your distinfo files.  Sometimes I saved this in $LUA_PROJECTS_DIR

local function getDistBinPath(os, arch)
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

--[[
baseDir = where to copy from
destDir = where to copy to
filesTable = k/v from/to
--]]
local function copyByDescTable(baseDir, destDir, filesTable)
	baseDir = path(baseDir)
	destDir = path(destDir)
	assert.type(filesTable, 'table')
	for from, to in pairs(filesTable) do
		local frompath = path(from)
		local topath = path(to)
		assert((baseDir/frompath):exists(), "failed to find file "..frompath)

		-- fixme maybe?
		local fromdir, fromname = frompath:getdir()
		local todir, toname = topath:getdir()
		assert.eq(fromname, toname)
--DEBUG:print('copyFileToDir', baseDir/fromdir, fromname, destDir/todir)
		copyFileToDir(baseDir/fromdir, fromname, destDir/todir)
	end
end

-- copy the file+dep tree to our platform-specific location
local function copyBody(destDir)
	copyByDescTable('.', destDir, files)
	local allDeps = {}
	local leftDeps = table(deps)
	while #leftDeps > 0 do
		local dep = leftDeps:remove(1)
		if not allDeps[dep] then
			allDeps[dep] = true

			local found
			-- first try the dist/distinfos/*.distinfo files
			-- TODO honestly thinking about it ... pushing the dist-builtin versions of these things means you're pushing untested ones
			-- so you're assuming that whatever is in dist-builtin is matching whatever is on the local machine...
			-- this is convenient for publishing cross-platform packages but it is risky if versions dont match...
			do
				local distinfopath = distProjectDir('distinfos/'..dep..'.distinfo')
				if distinfopath:exists() then
print(destDir..' adding dist-builtin '..dep)
					found = true
					local env = {}
					local distinfodata = assert(load(assert(distinfopath:read()), nil, 't', env))()
					assert(env.files, "failed to find any files in distinfo of dep "..dep)
					-- now find where the luarocks or builtin or whatever is installed
					for from,to in pairs(env.files) do
						local frombase = from:match'^(.*)%.lua$'
						assert(not frombase:find'%.', "can't use this path since it has a dot in its name: "..tostring(frombase))
						-- TODO search in release/
						local frompath = package.searchpath(frombase, package.path) or package.searchpath(frombase, package.cpath)
--DEBUG:print('frompath', frompath)
						frompath = path(frompath)
--DEBUG:print('path(frompath)', path(frompath))
						local fromdir, fromname = frompath:getdir()
--DEBUG:print('fromdir', fromdir)
--DEBUG:print('fromname', fromname)
						local todir, toname = path(to):getdir()
--DEBUG:print('copyFileToDir', fromdir, fromname, destDir/todir)
						assert.eq(fromname, toname)	-- because I guess copyFileToDir doesn't rename *shrug* should it?
						copyFileToDir(fromdir, fromname, destDir/todir)
					end
print(dep..' adding '..table.concat(env.deps or {}, ', '))
					leftDeps:append(env.deps)
				end
			end

			-- next try the projects/*/distinfo files
			if not found then
				local depPath = projectsDir/dep
				assert(depPath:exists(), "failed to find dependency base dir: "..depPath)
				local distinfopath = depPath/'distinfo'
				assert(distinfopath:exists(), "failed to find distinfo file: "..distinfopath)
				local env = {}
				local distinfodata = assert(load(assert(distinfopath:read()), nil, 't', env))()
				assert(env.files, "failed to find any files in distinfo of dep "..dep)
				copyByDescTable(depPath, destDir, env.files)
print(dep..' adding '..table.concat(env.deps or {}, ', '))
				leftDeps:append(env.deps)
			end
		end
	end
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
			'@echo off',
			'setlocal',
			'cd data',
			[[set ROOT=%CD%]],
			[[set PATH=%PATH%;%ROOT%\]]..tostring(binDirRel):gsub('/', '\\'),	-- gotta gsub manually to support packaging win distributables on non-win platforms
			[[set LUA_PATH=%ROOT%\?.lua;%ROOT%\?\?.lua;.\?.lua;.\?\?.lua]],
			[[set LUA_CPATH=%ROOT%\bin\Windows\]]..arch..[[\?.dll]],
			startDir and 'cd "'..startDir..'"' or '',
			luaDistVer..'.exe'..' '
				..(getLuaArgs'win' or '')
				..' > "%ROOT%\\..\\out.txt" 2> "%ROOT%\\..\\err.txt"',
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

	local binDirRel = path'bin'/'Windows'/arch
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

	local distBinPath = getDistBinPath('Windows', arch)

	local binDir = dataDir/binDirRel
	binDir:mkdir(true)

	-- copy luajit
	copyFileToDir(distBinPath, luaDistVer..'.exe', binDir)
	copyFileToDir(distBinPath, luaLibVer, binDir)

	-- copy body
	copyBody(dataDir)

	-- copy ffi windows dlls's
	-- same as Linux
	local libs = getLuajitLibs'win'
	if libs then
		for _,basefn in ipairs(libs) do
			for _,fn in ipairs{basefn..'.dll', basefn} do
				if distBinPath(fn):exists() then
					if distBinPath(fn):isdir() then
						copyDirToDir(distBinPath, fn, binDir)
					else
						copyFileToDir(distBinPath, fn, binDir)
					end
				else
					print("couldn't find library "..fn.." in paths "..tolua(distBinPath))
				end
			end
		end
	end

	-- now make the zip
	if not cmdline.dontZip then
		distDir(distName..'.zip'):remove()
		exec('cd dist && zip -r "'..distName..'.zip" "'..distName..'"')
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

	local macOSDir = contentsDir/'MacOS'
	macOSDir:mkdir()

	local resourcesDir = contentsDir/'Resources'
	resourcesDir:mkdir()

	local iconProp = 'Icons'
	local dstIconPath = resourcesDir/(name..'.icns')
	if iconOSX then
		exec('cp '..path(iconOSX):escape()..' '..dstIconPath:escape())
		iconProp = name
	--elseif icon then	-- if no icon then use OSX default icon
	else				-- if no icon then use Dist default icon
		if exec('makeicns -in '..path(icon or defaultIconPath):escape()..' -out '..dstIconPath:escape(), false) then
			-- only use the icon if makeicns didn't error
			iconProp = name
		end
	end

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
	<string>]]..iconProp..[[</string>
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

	-- lemme double check the dir structure on this ...
	local runshpath = macOSDir/'run-osx.sh'
	runshpath:write(
		table{
			[[#!/usr/bin/env bash]],
			-- https://stackoverflow.com/questions/59895/can-a-bash-script-tell-what-directory-its-stored-in
			[[DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"]],
			[[cd $DIR/../Resources]],
			[[export ROOT=`pwd`]],
			[[export PATH="$ROOT/bin/OSX/x64"]],
			[[export DYLD_LIBRARY_PATH="$ROOT/bin/OSX/x64"]],
			[[export LUA_PATH="$ROOT/?.lua;$ROOT/?/?.lua;./?.lua;./?/?.lua"]],
			[[export LUA_CPATH="$ROOT/bin/OSX/x64/?.so"]],
			startDir and 'cd "'..startDir..'"' or '',
			luaDistVer..' '
				..(getLuaArgs'osx' or '')
				..' > "$ROOT/../out.txt" 2> "$ROOT/../err.txt"',
		}:concat'\n'..'\n'
	)
	exec('chmod +x '..runshpath)

	local distBinPath = getDistBinPath('OSX', 'x64')

	-- copy luajit
	copyFileToDir(distBinPath, luaDistVer, resourcesDir)

	-- copy body
	copyBody(resourcesDir)

	-- ffi osx so's
	local libs = getLuajitLibs'osx'
	if libs then
		local resBinDir = resourcesDir/'bin/OSX'
		resBinDir:mkdir(true)
		for _,basefn in ipairs(libs) do
			for _,fn in ipairs{'lib'..basefn..'.dylib', basefn} do
				if distBinPath(fn):exists() then
					if distBinPath(fn):isdir() then
						copyDirToDir(distBinPath, fn, binDir)
					else
						copyFileToDir(distBinPath, fn, resBinDir)
					end
				else
					print("couldn't find library "..fn.." in paths "..tolua(distBinPath))
				end
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
			[[export ROOT=`pwd`]],
			[[export PATH="$ROOT/bin/Linux/x64"]],
			-- this is binDir relative to dataDir
			-- this line is needed for ffi's load to work
			[[export LD_LIBRARY_PATH="$ROOT/]]..binDirRel..'"',
			[[export LUA_PATH="$ROOT/?.lua;$ROOT/?/?.lua;./?.lua;./?/?.lua"]],
			-- this is binDir relative to dataDir
			[[export LUA_CPATH="$ROOT/bin/Linux/x64/?.so"]],
			startDir and 'cd "'..startDir..'"' or '',
			luaDistVer..' '
				..(getLuaArgs'linux' or '')
				..(dontPipe and '' or ' > "$ROOT/../out.txt" 2> "$ROOT/../err.txt"'),
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

	-- copy body
	copyBody(dataDir)

	local distBinPath = getDistBinPath('Linux', arch)

	local binDir = dataDir/binDirRel
	binDir:mkdir(true)
	copyFileToDir(distBinPath, luaDistVer, binDir)

	-- copy ffi linux so's
	-- same as Windows
	local libs = getLuajitLibs'linux'
	if libs then
		for _,basefn in ipairs(libs) do
			for _,fn in ipairs{'lib'..basefn..'.dylib', basefn} do
				if distBinPath(fn):exists() then
					if distBinPath(fn):isdir() then
						copyDirToDir(distBinPath, fn, binDir)
					else
						copyFileToDir(distBinPath, fn, binDir)
					end
				else
					print("couldn't find library "..fn.." in paths "..tolua(distBinPath))
				end
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

	-- copy body
	copyBody(dataDir)

	local distBinPath = getDistBinPath('Linux', arch)

	local binDir = dataDir/binDirRel
	binDir:mkdir(true)
	copyFileToDir(distBinPath, luaDistVer, binDir)

	-- copy ffi linux so's
	-- same as Windows
	local libs = getLuajitLibs'linux'
	if libs then
		for _,basefn in ipairs(libs) do
			for _,fn in ipairs{'lib'..basefn..'.dylib', basefn} do
				if distBinPath(fn):exists() then
					if distBinPath(fn):isdir() then
						copyDirToDir(distBinPath, fn, binDir)
					else
						copyFileToDir(distBinPath, fn, binDir)
					end
				else
					print("couldn't find library "..fn.." in paths "..tolua(distBinPath))
				end
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
			'Icon='..name,	-- matches dstIconPath's name is ${name}.png

			'Type=Application',
			'Categories='..(AppImageCategories or 'Utility'),

		}:concat'\n'..'\n'
	)

	-- cp from icon to osDir/${name}.png
	local srcIconPath = icon and path(icon) or defaultIconPath
	assert(srcIconPath:exists(), "AppImage requires an icon, and I couldn't find the icon file at "..srcIconPath)

	local dstIconPath = osDir/(name..'.png')
	exec('cp '..srcIconPath:escape()..' '..dstIconPath:escape())

	distDir:cd()
	assert(os.exec('ARCH=x86_64 appimagetool '..distName))
	runDir:cd()


--[[
if you want config and home folder within the .AppImage during its launch:
--appimage-portable-home		<=> $HOME
--appimage-portable-config		<=> $XDG_CONFIG_HOME
... but which shoudl I use in my code, especially to be cross-compatible with Windows
btw where on Linux and Windows do apps typically save stuff
Linux: $HOME/.config/<appName>/
--]]

end

local function makeLinuxWin64()
	local arch = 'x64'
	local distName = name..'-linux-win-64'

	-- [[ BEGIN MATCHING makeLinux
	local osDir = distDir/distName
	osDir:mkdir()

	-- this is where luajit is relative to the runtime cwd
	local binDirRel = path'bin'/'Linux'/arch

	makeLinuxScript(osDir, binDirRel)
	makeWinScript(arch, osDir, binDirRel)

	local dataDir = osDir/'data'
	dataDir:mkdir()

	-- copy body
	copyBody(dataDir)

	local distBinPath = getDistBinPath('Linux', arch)

	local binDir = dataDir/binDirRel
	binDir:mkdir(true)
	copyFileToDir(distBinPath, luaDistVer, binDir)

	-- copy ffi linux so's
	-- same as Windows
	local libs = getLuajitLibs'linux'
	if libs then
		for _,basefn in ipairs(libs) do
			for _,fn in ipairs{'lib'..basefn..'.dylib', basefn} do
				if distBinPath(fn):exists() then
					if distBinPath(fn):isdir() then
						copyDirToDir(distBinPath, fn, binDir)
					else
						copyFileToDir(distBinPath, fn, binDir)
					end
				else
					print("couldn't find library "..fn.." in paths "..tolua(distBinPath))
				end
			end
		end
	end
	--]]

	-- just copy everything in windows over - even dlls we dont use...?
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
	error'update this call' copyByDescTable(osDir, launchScripts)

	local dataDir = osDir/'data'
	dataDir:mkdir()

	-- copy body
	copyBody(dataDir)
end

print('targets', targets:concat', ')
targets = targets:mapi(function(v) return true, v end):setmetatable(nil)
distDir:mkdir()

-- TODO icon-conversion makeicns support will probably break outside OSX.  If you have an icon then store a .icns as well in the repo, or only build .app on OSX.
if targets.all or targets.osx then makeOSX() end

-- TODO separate os/arch like ffi does? win32 => Windows/x86, win64 => Windows/x64
--if targets.all or targets.win32 then makeWin('x86') end

if targets.all or targets.win64 then makeWin('x64') end

if targets.all or targets.linux then makeLinux('x64') end

-- TODO this will always break outside Linux
if targets.all or targets['linux-appimage'] then makeLinuxAppImage() end

if targets.linuxWin64 then makeLinuxWin64() end	-- build linux/windows x64 ... until I rethink how to break things apart and make them more modular ...
-- hmm ... I'll finish that lazy hack later
--if targets.all or targets.webserver then makeWebServer() end
