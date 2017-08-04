--
-- xcode_api.lua
-- Define the Apple XCode action and support functions.
-- Copyright (c) 2015 Blizzard Entertainment
--
	local p         = premake
	local api       = premake.api
	local configset = premake.configset

	p.IOS     = "ios"
	p.APPLETV = "appletv"

	-- register IOS and AppleTV os
	api.addAllowed("system", p.IOS)
	api.addAllowed("system", p.APPLETV)
	api.addAllowed("architecture", { "armv7", "armv7s", "arm64" })

	-- add system tags for ios and appletv.
	os.systemTags[p.IOS]     = { "ios",     "mobile" }
	os.systemTags[p.APPLETV] = { "appletv", "mobile" }

	local osoption = premake.option.get("os")
	if osoption ~= nil then
		table.insert(osoption.allowed, { p.IOS,     "iOS" })
		table.insert(osoption.allowed, { p.APPLETV, "Apple TV" })
	end

	-- register additional Xcode specific API's.
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
		name = "xcode_filetype",
		scope = "project",
		kind = "string",
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

	api.register {
		name = "xcode_targetattributes",
		scope = "project",
		kind  = "keyed:string"
	}

	premake.override(_G, "icon", function(base, name)
		local c = base(name)

		if _ACTION == "xcode" then
			local f = configset.getFilter(api.scope.current)

			files { name }
			filter { "files:" .. name }
			buildcommands {
				"{COPY} \"%{premake.workspace.getrelative(wks, file.abspath)}\" \"$BUILT_PRODUCTS_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH/Icon.icns\""
			}
			buildoutputs {
				"$(BUILT_PRODUCTS_DIR)/$(UNLOCALIZED_RESOURCES_FOLDER_PATH)/Icon.icns"
			}

			configset.setFilter(api.scope.current, f)
		end

		return c
	end)
