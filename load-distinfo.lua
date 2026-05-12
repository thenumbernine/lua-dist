-- load a distinfo file
-- assumes it is in rua format so I can use shorthand lambda and bitflag markup
local assert = require 'ext.assert'

-- setup the new distinfo langfix-based loader
local distinfoenv = setmetatable({}, {__index=_G})
require 'langfix.env'(distinfoenv)
require 'ext.env'(distinfoenv)
distinfoenv.ffi = require 'ffi'
--distinfoenv.require = require	-- needed?

return function(fn, plat)
	distinfoenv.targetOS = assert.index(plat, 'os')
	distinfoenv.targetArch = assert.index(plat, 'arch')

	local thisdistinfoenv = setmetatable({}, {__index=distinfoenv})
	assert(distinfoenv.loadfile(fn, 't', thisdistinfoenv))()
	-- keep the metatable __index so that subsequent calls like `generateBindings` will get proper env functions
	--setmetatable(thisdistinfoenv, nil)
	return thisdistinfoenv
end
