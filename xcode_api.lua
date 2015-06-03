--
-- xcode6_api.lua
-- Define the Apple XCode action and support functions.
-- Copyright (c) 2015 Blizzard Entertainment
--
	local api      = premake.api
	local xcode6   = premake.xcode6
	local project  = premake.project
	local solution = premake.solution
	local configset = premake.configset


	api.register {
		name = "xcode_settings",
		scope = "config",
		kind = "keyed:mixed",
		tokens = true
	}


	api.register {
		name = "xcode_filesettings",
		scope = "config",
		kind = "keyed:mixed",
		tokens = true
	}


	api.register {
		name = "xcode_resources",
		scope = "project",
		kind = "list:file",
		tokens = true
	}


	-- List of all links that are optional.	 Each item must also appear in a links command.
	api.register {
		name = "xcode_weaklinks",
		scope = "config",
		kind = "list:mixed",
		tokens = true
	}


	api.register {
		name = "xcode_frameworkdirs",
		scope = "config",
		kind = "list:directory",
		tokens = true
	}


	api.register {
		name = "xcode_runpathdirs",
		scope = "config",
		kind = "list:string",
		tokens = true
	}

	premake.override(_G, "icon", function(base, name)
		local c = base(name)

		if _ACTION == "xcode" then
			local f = configset.getFilter(api.scope.current)

			files { name }
			filter { "files:" .. name }
			buildcommands {
				"{COPY} \"%{premake.solution.getrelative(sln, file.abspath)}\" \"$BUILT_PRODUCTS_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH/Icon.icns\""
			}
			buildoutputs {
				"$(BUILT_PRODUCTS_DIR)/$(UNLOCALIZED_RESOURCES_FOLDER_PATH)/Icon.icns"
			}

			configset.setFilter(api.scope.current, f)
		end

		return c
	end)
