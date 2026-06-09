#!/usr/bin/env luajit
--[[
script to make an .app package
I'm using luajit for its ffi.os and ffi.arch variables

cmdline options:
- [1] = target
- 'target' = target
- 'targets' = list of strings of targets
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
	Windows = Windows/${ffi.arch}
		Windows-x86
		Windows-x64
	Linux = Linux/${ffi.arch}
		Linux-x86
		Linux-x64
	Linux-AppImage
		Linux-x86-AppImage
		Linux-x64-AppImage
	OSX = OSX/x64 .app ... though I don't have OSX to test on anymore ...
	Android = Android, requires my SDLLuaJIT-Android project to be stored in either $SDL_LUAJIT_ANDROID_APP_PATH or in $LUA_PROJECT_PATH/../Android/SDLLuaJIT/
	webserver = idk what I was doing with this one
	all = run all of them
--]]

-- global namespace so distinfo can see it
ffi = require 'ffi'
require 'ext.env'(_G)
local exec = require 'make.exec'
local makeZip = require 'dist.makezip'
local loadDistInfo = require 'dist.load-distinfo'

local dontZip = cmdline.dontZip

local runDir = path:cwd()

-- 'dist' project dir
local fn = package.searchpath('dist', package.path):gsub('\\', '/')
local distProjectDir = path(fn):getdir()

local defaultIconPath = distProjectDir'default-icon.png'

-- 'dist' local dir for this project
local distDir = path'dist'
assert(distDir.cd, "lfs_ffi might not have loaded correctly. check lfs_ffi.")


-- TODO we really can't do this here anymore, we have to do it inside each of the platforms so that we get the right distinfo configuration
--local distinfo = loadDistInfo 'distinfo'
--assert.type(distinfo.name, 'string')
local function getStartDir(distinfo)
	return distinfo.startDir or distinfo.name
end

-- hmmm hmmmmm
-- sometimes my 'luajit' is a script that sets up luarocks paths correctly and then runs luajit-openresty-2.1.0
luaDistVer = luaDistVer or 'luajit'
print("luaDistVer", luaDistVer)
assert.eq(luaDistVer, 'luajit')

-- needed by the windows build ... why not build static?
local luaLibVer = 'luajit-2.1.dll'


local homeDir = path((assert(os.getenv'HOME' or os.getenv'USERPROFILE', "failed to find your home dir")))

-- where to find your distinfo files.  Sometimes I saved this in $LUA_PROJECT_PATH
local projectsDir = os.getenv'LUA_PROJECT_PATH'
	and path(os.getenv'LUA_PROJECT_PATH')
	or homeDir/'Projects/lua'
assert(projectsDir:exists())

local function getDistBinPath(os, arch)
	return distProjectDir/'release/bin'/os/arch
end

-- TODO replace all exec(cp) and exec(rsync) with my own copy
-- or at least something that works on all OS's

local function copyFileToDir(basedir, srcpath, dstdir)
--DEBUG:print('cwd '..path:cwd()..' copyFileToDir basedir='..path.escape(basedir)..' srcpath='..path.escape(srcpath)..' dstdir='..path.escape(dstdir))
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
error('copyDirToDir('..basedir..', '..srcdir..', '..dstdir..', '..pattern..')')
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
srcDir = where to copy from
dstDir = where to copy to
filesTable = list-of-files relative to srcDir
--]]
local function copyByDescTable(srcDir, dstDir, files)
--DEBUG:print('cwd '..path:cwd()..' copyByDescTable srcDir='..path.escape(srcDir)..' dstDir='..path.escape(dstDir)..' #files='..#files)
	srcDir = path(srcDir)
	dstDir = path(dstDir)
	assert.type(files, 'table')
	for _,file in ipairs(files) do
		local filepath = path(file)
		assert((srcDir/filepath):exists(), "failed to find file "..filepath)

		-- get the dir and name relative to srcDir
		local filedir, filename = filepath:getdir()
--DEBUG:print('filedir', filedir)
--DEBUG:print('filename', filename)
--DEBUG:print('copyByDescTable calling copyFileToDir', srcDir/filedir, filename, dstDir/filedir)
		copyFileToDir(srcDir/filedir, filename, dstDir/filedir)
	end
end

-- copy the file+dep tree to our platform-specific location
local function copyBody(distinfo, destDir, targetPlatform)
	copyByDescTable('.', destDir/distinfo.name, distinfo.files)
	local allDeps = {}
	local leftDeps = table(distinfo.deps)
	while #leftDeps > 0 do
		local dep = leftDeps:remove(1)
		if not allDeps[dep] then
			allDeps[dep] = true

			local found
			-- first try the dist/distinfos/*.distinfo files
			-- TODO honestly thinking about it ... pushing the dist-builtin versions of these things means you're pushing untested ones
			-- so you're assuming that whatever is in dist-builtin is matching whatever is on the local machine...
			-- this is convenient for publishing cross-platform packages but it is risky if versions dont match...
			--
			-- also, since most other packages don't match my naming
			--  and instead they just dump all their files in root and pray for no collision,
			-- that means that reproducing other packages' folder structure with mine is a mess,
			--  but also is incompatible with my 'distinfo' file which just lists files within the project subfolder.
			--  (and other packages dont do this, they just have root folder files.)
			-- so, only for dist/distinfos/*.distinfo external projects,
			-- I guess I'll have to search in dist/release and copy across
			--
			-- also, new file system, all libs are in the bin subfolder
			-- does Windows even allow this? or does it complain due to .lib vs .dll vs whatever search paths?
			--  I think in Windows I'll have to add every single $project/bin/Windows/$arch/ folder to the PATH env var just so the windows dlsym will work.
			do
				local distinfopath = distProjectDir('distinfos/'..dep..'.distinfo')
				if distinfopath:exists() then
print('... '..destDir..' adding dist-builtin '..dep)
					found = true
					local subdistinfo
					assert(xpcall(function()
						subdistinfo = loadDistInfo(distinfopath.path, targetPlatform)
						assert(subdistinfo.files, "failed to find any files in distinfo of dep "..dep)
					end, function(err)
						return 'for file: '..distinfopath..'\n'..err..'\n'..debug.traceback()
					end))
					-- now find where the luarocks or builtin or whatever is installed
					for _,from in ipairs(subdistinfo.files) do
						local to = destDir/from
						--[[ search in search paths:
						local frombase = from:match'^(.*)%.lua$'
						assert(not frombase:find'%.', "can't use this path since it has a dot in its name: "..tostring(frombase))
						local frompath = package.searchpath(frombase, package.path)
									or package.searchpath(frombase, package.cpath)
--DEBUG:print('frompath', frompath)
						frompath = path(frompath)
						--]]
						-- [[ search in release/
						local frompath = distProjectDir/'release'/from
						--]]
--DEBUG:print('path(frompath)', path(frompath))
						local fromdir, fromname = frompath:getdir()
--DEBUG:print('fromdir', fromdir)
--DEBUG:print('fromname', fromname)
						local todir, toname = path(to):getdir()
--DEBUG:print('copyFileToDir', fromdir, fromname, destDir/todir)
						assert.eq(fromname, toname)	-- because I guess copyFileToDir doesn't rename *shrug* should it?
						copyFileToDir(fromdir, fromname, todir)
					end
print('... '..dep..' adding '..table.concat(subdistinfo.deps or {}, ', '))
					leftDeps:append(subdistinfo.deps)
				end
			end

			-- next try the projects/*/distinfo files
			if not found then
				local depPath = projectsDir/dep
				assert(depPath:exists(), "failed to find dependency base dir: "..depPath)
				local distinfopath = depPath/'distinfo'
				assert(distinfopath:exists(), "failed to find distinfo file: "..distinfopath)
				local subdistinfo
				assert(xpcall(function()
					subdistinfo = loadDistInfo(distinfopath.path, targetPlatform)
				end, function(err)
					return 'for file: '..distinfopath..'\n'..err..'\n'..debug.traceback()
				end))
				assert(subdistinfo.files, "failed to find any files in distinfo of dep "..dep)

				-- "depPath" should be relative to the projectsDir
				-- so that the dist/platform/depPath is where the files end up
				copyByDescTable(depPath, destDir/dep, subdistinfo.files)
print('... '..dep..' adding '..table.concat(subdistinfo.deps or {}, ', '))
				leftDeps:append(subdistinfo.deps)
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

-- TODO I think this is on its way out
local function getLuajitLibs(distinfo, plat)
	return getForPlat(distinfo.luajitLibs, plat, 'table')
end

local function getLuaArgs(distinfo, plat)
	-- TODO if there's no luaArgs then you're running interactive lua, which means you don't want your shell to pipe to a file ...
	local luaArgs = assert.index(distinfo, 'luaArgs')
	return assert.type(luaArgs, 'string')
end

-- osDir is "$distPerOS/"
-- binDirRel is "bin/Windows/$arch"
-- to be relative to $distPerOS/data
local function makeWindowsScript(distinfo, arch, osDir, binDirRel)
	local startDir = getStartDir(distinfo)

	-- I'm including both now that on some machines .bat warns and .vbs doesn't, while on others .vbs silent quits and .bat doesn't
	-- [=[ vbs
	local vbsPath = osDir/('run-Windows-'..arch..'.vbs')
	vbsPath:write(
		table{
[[set shell = CreateObject("WScript.Shell")]],
[[shell.CurrentDirectory = ".\data"]],
[[rootdir = CreateObject("Scripting.FileSystemObject").GetAbsolutePathName(".")]],
[[set env = shell.Environment("Process")]],
[[env("PATH") = env("PATH") & ";" & rootdir & "\]]
	..tostring(binDirRel):gsub('/', '\\')	-- gotta gsub manually to support packaging win distributables on non-win platforms
	..[["]],
[[env("LUA_PATH") = rootdir & "\?.lua;" & rootdir & "\?\?.lua;.\?.lua;.\?\?.lua"]],
[[env("LUA_CPATH") = rootdir & "\bin\Windows\]]..arch..[[\?.dll"]],
(startDir and [[shell.CurrentDirectory = ".\]]..startDir..[["]] or ''),
[[shell.Run "]]..luaDistVer..[[.exe ]]..(getLuaArgs(distinfo, 'Windows') or '')
	..[[ > """ & rootdir & "\..\out.txt"" 2> """ & rootdir & "\..\err.txt""]] -- want to pipe output?
	..[[", 0, True]],
[[WScript.Quit]],
		}:concat'\r\n'..'\r\n'
	)
	--]=]
	-- [=[ bat
	local batPath = osDir/('run-Windows-'..arch..'.bat')
	batPath:write(
		table{
[[@echo off]],
[[cd data]],
[[set LUA_PROJECT_PATH=%CD%]],
-- option #1: copy everything into bin/Windows/arch
-- option #2: add lots of PATH entries
[[set PATH=%PATH%;%LUA_PROJECT_PATH%\]]
	..binDirRel.path:gsub('/', '\\'),	-- gotta gsub manually to support packaging win distributables on non-win platforms
[[set LUA_PATH=%LUA_PROJECT_PATH%\?.lua;%LUA_PROJECT_PATH%\?\?.lua;.\?.lua;.\?\?.lua]],
[[set LUA_CPATH=%LUA_PROJECT_PATH%\bin\Windows\]]..arch..[[\?.dll]],
startDir and 'cd '..path(startDir):escape() or '',
luaDistVer..'.exe '..(getLuaArgs(distinfo, 'Windows') or '')..' > "%LUA_PROJECT_PATH%\\..\\out.txt" 2> "%LUA_PROJECT_PATH%\\..\\err.txt"'
		}:concat'\r\n'..'\r\n'
	)
	--]=]
end

-- the windows-specific stuff:
local function makeWindows(arch)
	local targetOS = 'Windows'
	local targetPlatform = {os=targetOS, arch=arch}

	local distinfo = loadDistInfo('distinfo', targetPlatform)
	assert.type(distinfo.name, 'string')
	assert(distinfo.name)
	assert(distinfo.files)

	local bits = assert.index({x86='32',x64='64'}, arch, "don't know what bits of arch this is (32? 64? etc?)")
	local distName = distinfo.name..'-Windows-'..arch
	local osDir = distDir/distName
	osDir:mkdir()

	local binDirRel = path'bin'/targetOS/arch
	makeWindowsScript(distinfo, arch, osDir, binDirRel)

	local dataDir = osDir/'data'
	dataDir:mkdir()

	local distBinPath = getDistBinPath(targetOS, arch)

	local binDir = dataDir/binDirRel
	binDir:mkdir(true)

	-- copy luajit
	copyFileToDir(distBinPath, luaDistVer..'.exe', binDir)
	copyFileToDir(distBinPath, luaLibVer, binDir)

	-- copy body
	copyBody(distinfo, dataDir, targetPlatform)

	-- copy ffi windows dlls's
	-- same as Linux
	-- old system?  now i'm moving to storing binaries per-library
	local libs = getLuajitLibs(distinfo, 'Windows')
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

	-- hmm how to handle windows' dll search paths, since dlopen doesn't care what LUA_CPATH says, and only needs everything in PATH ...
	-- after 'copyBody' is done, all dlls should be where they are
	-- I can always just move them all to binDir ...
	for f in dataDir:dir() do
		local binOSDir = dataDir/f/'bin'/targetOS
		local binOSArchDir = binOSDir/arch
		if binOSArchDir:exists() then
			-- if $osDir/data/$project/bin/$targetOS/$arch/ exists
			for g in binOSArchDir:dir() do
				-- them move all its conents to $osDir/data/bin/$targetOS/$arch/
				(binOSArchDir/g):move(binDir/g)
			end
			binOSArchDir:rmdir()
			binOSDir:rmdir()
		end
	end

	-- now make the zip
	if not dontZip then
		distDir(distName..'.zip'):remove()
		makeZip('dist', distName)
	end
end

-- OSX goes in dist/OSX/${name}.app/Contents/
local function makeOSX()
	local arch = 'x64'
	--assert.eq(targetPlatform.arch, 'x64', "don't know what bits of arch this is (32? 64? etc?)")
	local targetPlatform = {os='OSX', arch=arch}

	local distinfo = loadDistInfo('distinfo', targetPlatform)
	assert.type(distinfo.name, 'string')
	assert(distinfo.name)
	assert(distinfo.files)

	local distName = distinfo.name..'-OSX-'..arch
	-- the osx-specific stuff:
	local osDir = distDir/distName
	osDir:mkdir()
	osDir(distinfo.name..'.app'):mkdir()

	local contentsDir = osDir(distinfo.name..'.app/Contents')
	contentsDir:mkdir()

	local macOSDir = contentsDir/'MacOS'
	macOSDir:mkdir()

	local resourcesDir = contentsDir/'Resources'
	resourcesDir:mkdir()

	local iconProp = 'Icons'
	local dstIconPath = resourcesDir/(distinfo.name..'.icns')
	if iconOSX then
		exec('cp '..path(iconOSX):escape()..' '..dstIconPath:escape())
		iconProp = distinfo.name
	--elseif icon then	-- if no icon then use OSX default icon
	else				-- if no icon then use Dist default icon
		if exec('makeicns -in '..path(icon or defaultIconPath):escape()..' -out '..dstIconPath:escape(), false) then
			-- only use the icon if makeicns didn't error
			iconProp = distinfo.name
		end
	end

	local shfn = 'run-OSX-'..arch..'.sh'

	contentsDir'PkgInfo':write'APPLhect'
	contentsDir'Info.plist':write([[
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleName</key>
	<string>]]..distinfo.name..[[</string>
	<key>CFBundleIdentifier</key>
	<string>net.christopheremoore.]]..distinfo.name..[[</string>
	<key>CFBundleVersion</key>
	<string>1.0</string>
	<key>CFBundleIconFile</key>
	<string>]]..iconProp..[[</string>
	<key>CFBundleDevelopmentRegion</key>
	<string>English</string>
	<key>CFBundleDocumentTypes</key>
	<array/>
	<key>CFBundleExecutable</key>
	<string>]]..shfn..[[</string>
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
	local startDir = getStartDir(distinfo)
	local runshpath = macOSDir/shfn
	runshpath:write(
		table{
			[[#!/usr/bin/env bash]],
			-- https://stackoverflow.com/questions/59895/can-a-bash-script-tell-what-directory-its-stored-in
			[[DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"]],
			[[cd $DIR/../Resources]],
			[[export LUA_PROJECT_PATH=`pwd`]],
			[[export PATH="$LUA_PROJECT_PATH/bin/OSX/]]..arch..[["]],
			[[export DYLD_LIBRARY_PATH="$LUA_PROJECT_PATH/bin/OSX/]]..arch..[["]],
			[[export LUA_PATH="$LUA_PROJECT_PATH/?.lua;$LUA_PROJECT_PATH/?/?.lua;./?.lua;./?/?.lua"]],
			[[export LUA_CPATH="$LUA_PROJECT_PATH/bin/OSX/]]..arch..[[/?.so"]],
			startDir and 'cd "'..startDir..'"' or '',
			luaDistVer..' '
				..(getLuaArgs(distinfo, 'osx') or '')
				..' > "$LUA_PROJECT_PATH/../out.txt" 2> "$LUA_PROJECT_PATH/../err.txt"',
		}:concat'\n'..'\n'
	)
	exec('chmod +x '..runshpath)

	local distBinPath = getDistBinPath('OSX', arch)

	-- copy luajit
	copyFileToDir(distBinPath, luaDistVer, resourcesDir)

	-- copy body
	copyBody(distinfo, resourcesDir, targetPlatform)

	-- ffi osx so's
	local libs = getLuajitLibs(distinfo, 'OSX')
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
	if not dontZip then
		distDir(distName..'.zip'):remove()
		makeZip('dist', distName)
	end
end

-- TODO change runshpath based on arch?
local function makeLinuxScript(distinfo, arch, osDir, binDirRel, scriptName, dontPipe)
	local startDir = getStartDir(distinfo)
	local runshpath = osDir/(scriptName or 'run-Linux-'..arch..'.sh')
	runshpath:write(
		table{
			[[#!/usr/bin/env bash]],
			'cd data',
			[[export LUA_PROJECT_PATH=`pwd`]],
			-- this is binDir relative to dataDir
			-- this line is needed for ffi's load to work
			[[export PATH="$LUA_PROJECT_PATH/]]..binDirRel..'"',
			[[export LD_LIBRARY_PATH="$LUA_PROJECT_PATH/]]..binDirRel..'"',
			[[export LUA_PATH="$LUA_PROJECT_PATH/?.lua;$LUA_PROJECT_PATH/?/?.lua;./?.lua;./?/?.lua"]],
			-- this is binDir relative to dataDir
			[[export LUA_CPATH="$LUA_PROJECT_PATH/bin/Linux/]]..arch..[[/?.so"]],
			startDir and 'cd "'..startDir..'"' or '',
			luaDistVer..' '
				..(getLuaArgs(distinfo, 'Linux') or '')
				..(dontPipe and '' or ' > "$LUA_PROJECT_PATH/../out.txt" 2> "$LUA_PROJECT_PATH/../err.txt"'),
		}:concat'\n'..'\n'
	)
	exec('chmod +x '..runshpath)
end

-- should I include binaries in the Linux distribution?
local function makeLinux(arch)
	local targetOS = 'Linux'
	local targetPlatform = {os=targetOS, arch=arch}
	local distinfo = loadDistInfo('distinfo', targetPlatform)
	assert.type(distinfo.name, 'string')
	assert(distinfo.name)
	assert(distinfo.files)

	local bits = assert.index({x86='32',x64='64'}, arch, "don't know what bits of arch this is (32? 64? etc?)")
	local distName = distinfo.name..'-Linux-'..bits
	local osDir = distDir/distName
	osDir:mkdir()

	-- this is where luajit is relative to the runtime cwd
	local binDirRel = path'bin'/targetOS/arch

	makeLinuxScript(distinfo, arch, osDir, binDirRel)

	local dataDir = osDir/'data'
	dataDir:mkdir()

	local distBinPath = getDistBinPath(targetOS, arch)

	local binDir = dataDir/binDirRel
	binDir:mkdir(true)

	-- copy luajit
	copyFileToDir(distBinPath, luaDistVer, binDir)

	-- copy body
	copyBody(distinfo, dataDir, targetPlatform)

	-- copy ffi Linux so's
	-- same as Windows
	-- old system?  now i'm moving to storing binaries per-library
	local libs = getLuajitLibs(distinfo, 'Linux')
	if libs then
		for _,basefn in ipairs(libs) do
			for _,fn in ipairs{'lib'..basefn..'.so', basefn} do
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

	-- same as windows,
	-- consolidate .so'd:
	-- copy all the <package>/bin/Linux/$arch/* into bin/Linux/$arch
	for f in dataDir:dir() do
		local binOSDir = dataDir/f/'bin'/targetOS
		local binOSArchDir = binOSDir/arch
		if binOSArchDir:exists() then
			-- if $osDir/data/$project/bin/$targetOS/$arch/ exists
			for g in binOSArchDir:dir() do
				-- them move all its conents to $osDir/data/bin/$targetOS/$arch/
				(binOSArchDir/g):move(binDir/g)
			end
			binOSArchDir:rmdir()
			binOSDir:rmdir()
		end
	end

	-- now make the zip
	if not dontZip then
		distDir(distName..'.zip'):remove()
		makeZip('dist', distName)
	end
end

-- make for x64 only because I just don't have the x32 builds
local function makeLinuxAppImage(arch)
	if not os.exec('which appimagetool') then
		print("!!! can't find appimagetool, skipping !!!")
		return
	end

	local distName = distinfo.name..'-x86_64.AppDir'
	local osDir = distDir/distName
	osDir:mkdir()

	local binDirRel = path'bin/Linux'/arch	-- this is where luajit is relative to the runtime cwd

	--[[ do I just do AppRun here, and have the .desktop run it?
	makeLinuxScript(distinfo, arch, osDir, binDirRel, 'AppRun')
	--]]
	-- [[ or do I put the run in the usual place?
	makeLinuxScript(distinfo, arch, osDir, binDirRel, nil, true)
	local AppRunPath = osDir/'AppRun'
	local shfn = 'run-Linux-'..arch..'.sh'
	AppRunPath:write([[
#!/bin/sh
cd $APPDIR
./]]..shfn..[[ "$@"
]])
	exec('chmod +x '..AppRunPath:escape())
	--]]

	local dataDir = osDir/'data'
	dataDir:mkdir()

	-- copy body
	copyBody(distinfo, dataDir, {os='Linux', arch=arch})

	local distBinPath = getDistBinPath('Linux', arch)

	local binDir = dataDir/binDirRel
	binDir:mkdir(true)
	copyFileToDir(distBinPath, luaDistVer, binDir)

	-- copy ffi Linux so's
	-- same as Windows
	local libs = getLuajitLibs(distinfo, 'Linux')
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
	osDir(distinfo.name..'.desktop'):write(
		table{
			'[Desktop Entry]',
			'Name='..distinfo.name,			-- the name here has to match the dir being ${name}-x86_64.AppDir
			'Exec='..shfn,					-- wait, should this be AppRun, or should it be `shfn` and AppRun points to `shfn` as well?

			--[[
			Icon is weird one.
			It has to be there.  You can't have no icon.  So TODO I need a default AppImage icon in the dist project here.
			You can't have an extension on the entry here, this just has to match the <file>.png I guess.
			--]]
			'Icon='..distinfo.name,	-- matches dstIconPath's name is ${name}.png

			'Type=Application',
			'Categories='..(AppImageCategories or 'Utility'),

		}:concat'\n'..'\n'
	)

	-- cp from icon to osDir/${name}.png
	local srcIconPath = icon and path(icon) or defaultIconPath
	assert(srcIconPath:exists(), "AppImage requires an icon, and I couldn't find the icon file at "..srcIconPath)

	local dstIconPath = osDir/(distinfo.name..'.png')
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

-- TODO this is bugged now that i'm loading distinfo once per platform...
local function makeLinuxWindows()
error"doesn't work anymore"
	local arch = 'x64'
	local distName = distinfo.name..'-Linux-Windows-'..arch

	-- [[ BEGIN MATCHING makeLinux
	local osDir = distDir/distName
	osDir:mkdir()

	local targetPlatform = {os='Windows', arch=arch}
	local distinfo = loadDistInfo('distinfo', targetPlatform)
	assert.type(distinfo.name, 'string')
	assert(distinfo.name)
	assert(distinfo.files)

	-- this is where luajit is relative to the runtime cwd
	local binDirRel = path'bin'/'Linux'/arch

	makeLinuxScript(distinfo, arch, osDir, binDirRel)
	makeWindowsScript(distinfo, arch, osDir, binDirRel)

	local dataDir = osDir/'data'
	dataDir:mkdir()

	-- copy body
	copyBody(distinfo, dataDir, {os='Windows', arch=arch})
	copyBody(distinfo, dataDir, {os='Linux', arch=arch})	-- hmm how to tell copyBody to copy both Linux and windows dlls ... hmm

	local distBinPath = getDistBinPath('Linux', arch)

	local binDir = dataDir/binDirRel
	binDir:mkdir(true)
	copyFileToDir(distBinPath, luaDistVer, binDir)

	-- copy ffi Linux so's
	-- same as Windows
	local libs = getLuajitLibs(distinfo, 'Linux')
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
	-- this is assuming we're running from Linux ...
	if not dontZip then
		distDir(distName..'.zip'):remove()
		makeZip('dist', distName)
	end
end


--[[
what to do here ...
1) copy the SDL-LuaJIT apk source into a temp folder in dist/ , like dist/android-apk/
2) modify the SDL-LuaJIT apk accordingly
	- move SDLLuaJIT/app/src/main/java/io/github/thenumbernine/SDLLuaJIT/SDLActivity.java
		to dist/android-apk/app/src/main/java/${packagename replace .'s with /'s}/SDLActivity.java
	- change app/build.gradle
		- android.namespace from "io.github.thenumbernine.SDLLuaJIT" to "${packagename}"
		- android.defaultConfig.applicationId from same to same
		- android.defaultConfig's base.archivesName.set("SDLLuaJIT-$versionName") to whatever ${apkfilename}
	- change app/src/main/AndroidManifest.xml
	- rename AndroidManifest.xml
		- manifest.application.activity.android:name from "io.github.thenumbernine.SDLLuaJIT.SDLActivity" to "${packagename}.SDLActivity"

TODO TODO TODO I should save the sdl3 and luajit android binaries in its jniLibs folder so I don't have to keep rebuilding them again and again ...

	- copy lua into our typical luajit runtime directory structure and put it in dist/android-apk/assets/
		- these will go to /data/data/packagename/files/
	- libs should all go in one place: dist/android-apk/assets/lib/
		- these will go to /data/data/packagename/files/lib/
3) run android SDK build on it all ... TODO see what cmds android studio executes.
4) copy the results from dist/android-apk/app/build/outputs/apk/release/${apkfilename}-${apkversion}-${android-abi}-${debug-vs-release}.apk
--]]
local function makeAndroid()
	--[==[
	local distinfo = loadDistInfo('distinfo', {os='Android', arch='arm'})
	assert.type(distinfo.name, 'string')
	assert(distinfo.name)
	assert(distinfo.files)

	local apkFileName = distinfo.apkFileName or (function()
		io.stderr:write("WARNING - didn't find apkFileName, using name instead\n")
		return distinfo.name
	end)()
	local apkPkgName = distinfo.apkPkgName or (function()
		io.stderr:write("WARNING - didn't find apkPkgName, using name instead\n")
		return 'io.github.thenumbernine.'..distinfo.name
	end)()
error'TODO'
	local srcSdlLuaJITDir =
		os.getenv'SDL_LUAJIT_ANDROID_APP_PATH'
			and path(os.getenv'SDL_LUAJIT_ANDROID_APP_PATH')
		or os.getenv'LUA_PROJECT_PATH'
			and path(os.getenv'LUA_PROJECT_PATH')/'../android/SDLLuaJIT'
		or error("idk where to find the SDL LuaJIT Android app...")
	local apkSrcDir = distDir/'android-apk'
	exec('cp -R '..srcSdlLuaJITDir:escape()..' '..apkSrcDir:escape())
	--]==]
	-- [==[
	local targetOS = 'Android'
	local targetArch = 'arm'
	local distinfo = loadDistInfo('distinfo', {os=targetOS, arch=targetArch})
	assert.type(distinfo.name, 'string')
	assert(distinfo.name)
	assert(distinfo.files)

	local distName = distinfo.name..'-'..targetOS..'-'..targetArch
	local osDir = distDir/distName
	osDir:mkdir()

error'todo'

	-- ok now ... clone? download master zip?  copy from local?
	-- init base of our android project:
	os.exec('cp -R ../../android/SDL-in-LuaJIT '..osDir..'/')

	-- write build config info:
	(osDir/'config.rua'):write(table{
		'package = "io.github.thenumbernine.'..dist.name..'"',
		'appname = "'..dist.name..'"',
	}:concat'\n'..'\n')

	-- rename stuff in the repo ... wait won't I need to init the base LuaJIT repo?
	os.exec('cd '..osDir..'/SDL-in-LuaJIT/LuaJIT && ./rename.rua')

	-- copy across repos we will need

	-- build
	os.exec('cd '..osDir..'/SDL-in-LuaJIT && ./make.rua')
	--]==]
end

-- i'm using this for a webserver distributable that assumes the host has lua already installed
-- it's a really bad hack, but I'm lazy
local function makeWebServer()
error'TODO'

	assert(luaDistVer ~= 'luajit', "not supported just yet")
	local osDir = distDir/'webserver'
	osDir:mkdir()

	-- copy launch scripts
	assert(launchScripts, "expected launchScripts")
	error'update this call' copyByDescTable(osDir, launchScripts)

	local dataDir = osDir/'data'
	dataDir:mkdir()

	-- copy body
	copyBody(distinfo, dataDir, {os=='webserver', arch='webserver'})
end


-- set 'all' to run all
local targets = table(cmdline.targets)
if #targets == 0 then
	local target = cmdline.target or cmdline[1]
	if not target then
	-- [[ pick target based on current arch/os ...
		if ffi.os == 'Windows'
		or ffi.os == 'Linux'
		or ffi.os == 'OSX'
		then
			target = ffi.os
		else
			error("can't determine default, unknown os/arch "..ffi.os..'/'..ffi.arch)
		end
	--]]
	--[[ just default to 'all' ?
		target = 'all'
	--]]
	end
	targets:insert(target)
end
assert(#targets > 0, "don't have any targets to build for")

print('targets', targets:concat', ')
targets = targets:mapi(function(v) return true, v end):setmetatable(nil)
distDir:mkdir()

-- TODO icon-conversion makeicns support will probably break outside OSX.  If you have an icon then store a .icns as well in the repo, or only build .app on OSX.
if targets['OSX-x64']
or (targets.OSX and ffi.arch == 'x64')
--or targets.all	-- not in 'all' by default
then
	makeOSX()	-- is there such a thing as OSX-x86 anymore?
end

if targets['Windows-x86']
or (targets.Windows and ffi.arch == 'x86')
--or targets.all	-- Windows-x86 is not a member of 'all' by default
then
	makeWindows'x86'
end

if targets['Windows-x64']
or (targets.Windows and ffi.arch == 'x64')
or targets.all
then
	makeWindows'x64'
end

if targets['Linux-x86']
or (targets.Linux and ffi.arch == 'x86')
--or targets.all	-- Linux-x86 is not a member of 'all' by default
then
	makeLinux'x86'
end

if targets['Linux-x64']
or (targets.Linux and ffi.arch == 'x64')
or targets.all
then
	makeLinux'x64'
end

if targets['Linux-x86-AppImage']
or (targets['Linux-AppImage'] and ffi.arch == 'x86')
or (ffi.os == 'Linux' and targets.all)	-- not 'all', since this will always break outside Linux
then
	makeLinuxAppImage'x86'
end

if targets['Linux-x64-AppImage']
or (targets['Linux-AppImage'] and ffi.arch == 'x64')
or (ffi.os == 'Linux' and targets.all)	-- not 'all', since this will always break outside Linux
then
	makeLinuxAppImage'x64'
end

-- broken...
if targets['Linux-Windows'] then makeLinuxWindows() end	-- build linux/windows x64 ... until I rethink how to break things apart and make them more modular ...

-- broken, or WIP
if targets.Android then makeAndroid() end

-- broken...
-- hmm ... I'll finish that lazy hack later
--if targets.all or targets.webserver then makeWebServer() end
