package = "dist"
version = "dev-1"
source = {
	url = "git+https://github.com/thenumbernine/lua-dist.git"
}
description = {
	summary = "Distribution for Lua Projects",
	detailed = "Distribution for Lua Projects",
	homepage = "https://github.com/thenumbernine/lua-dist",
	license = "MIT"
}
dependencies = {
	"lua >= 5.2"
}
build = {
	type = "builtin",
	modules = {
		dist = "dist.lua",
		["dist.run"] = "run.lua",
		["dist.release"] = "release",
		["dist.check_versions"] = "check_versions.lua",
		["dist.update-release"] = "update-release.lua"
	}
}
