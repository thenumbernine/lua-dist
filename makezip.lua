-- function for making zip, just runs cli depending on your os
local ffi = require 'ffi'

local path = require 'ext.path'
local exec = require 'make.exec'	-- why isn't this os.exec?

-- kind of specialized, but. ..
-- 	wd = dir to the folder you want to zip
-- 	zipdir = name of the subdir in that folder to zip
-- I could organize it better :shrug:
local function makeZip(wd, zipdir)
	wd = path(wd)
	assert(wd:exists(), wd.." wd doesn't exist")
	assert(wd:isdir(), wd.." wd isn't dir")

	zipdir = path(zipdir)
	assert((wd/zipdir):exists(), (wd/zipdir).." zipdir doesn't exist")
	assert((wd/zipdir):isdir(), (wd/zipdir).." zipdir isn't dir")

	local zip = path(zipdir.path..'.zip')	-- setext replaces .something, should I have an :addext() function?
	assert(not (wd/zip):exists(), (wd/zip).." zip already exists, plz delete yourself, I don't want to be responsible for overwriting something you wanted.")

	if ffi.os == 'Windows' then
		exec('cd '..wd:escape()..' && 7z.exe a -tzip '..zip:escape()..' '..zipdir:escape())
	else
		exec('cd '..wd:escape()..' && zip -r '..zip:escape()..' "'..zipdir.path..'/"')	-- TODO path but with slash...
	end
end

return makeZip
