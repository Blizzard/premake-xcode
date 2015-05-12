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
        name = "xcode_file_settings",
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

	premake.override(_G, "icon", function(base, name)
		local c = base(name)

        local f = configset.getFilter(api.scope.current)

        filter { }
        files { name }
        filter { "files:" .. name }
        buildcommands {
            "{COPY} \"%{premake.solution.getrelative(sln, file.abspath)}\" \"$BUILT_PRODUCTS_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH/Icon.icns\""
        }
        buildoutputs {
            "$(BUILT_PRODUCTS_DIR)/$(UNLOCALIZED_RESOURCES_FOLDER_PATH)/Icon.icns"
        }

        configset.setFilter(api.scope.current, f)

		return c
	end)
