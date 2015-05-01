--
-- xcode6_api.lua
-- Define the Apple XCode action and support functions.
-- Copyright (c) 2015 Blizzard Entertainment
--
	local api      = premake.api
	local xcode6   = premake.xcode6
	local project  = premake.project
	local solution = premake.solution


	api.register {
		name = "xcode_settings",
		scope = "config",
		kind = "keyed:mixed",
		tokens = true
    }

    api.register {
        name = "xcode_file_settings",
        scope = "config",
        kind = "keyed:mixed",
        tokens = true
    }