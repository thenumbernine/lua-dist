-- load a distinfo file
-- assumes it is in rua format so I can use shorthand lambda and bitflag markup

-- setup the new distinfo langfix-based loader
local distinfoenv = setmetatable({}, {__index=_G})
require 'langfix.env'(distinfoenv)
require 'ext.env'(distinfoenv)
distinfoenv.ffi = require 'ffi'
--distinfoenv.require = require	-- needed?

return function(fn)
	local thisdistinfoenv = setmetatable({}, {__index=distinfoenv})
	assert(distinfoenv.loadfile(fn, 't', thisdistinfoenv))()
	setmetatable(thisdistinfoenv, nil)
	return thisdistinfoenv
end
