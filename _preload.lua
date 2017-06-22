---
-- xcode/_preload.lua
-- Define the Apple XCode actions and new APIs.
-- Copyright (c) 2009-2015 Jason Perkins and the Premake project
---

	newaction
	{
		trigger         = "xcode",
		shortname       = "Xcode",
		description     = "Generate Apple Xcode project",
		targetos        = "macosx",
		toolset         = "clang",

		valid_kinds     = { "ConsoleApp", "WindowedApp", "SharedLib", "StaticLib", "Makefile", "Utility", "None" },
		valid_languages = { "C", "C++" },
		valid_tools     = { cc = { "clang" } },

		onWorkspace = function(wks)
			local m = require('xcode-blizzard')
			premake.escaper(m.esc)
			premake.generate(wks, ".xcodeproj/project.pbxproj", m.generate_workspace)
		end,

		pathVars = {
			["file.basename"]     = { absolute = false, token = "$(INPUT_FILE_BASE)" },
			["file.abspath"]      = { absolute = true,  token = "$(INPUT_FILE_PATH)" },
			["file.relpath"]      = { absolute = true,  token = "$(INPUT_FILE_PATH)" },
			["file.path"]         = { absolute = true,  token = "$(INPUT_FILE_PATH)" },
			["file.directory"]    = { absolute = true,  token = "$(INPUT_FILE_DIR)" },
			["file.reldirectory"] = { absolute = true,  token = "$(INPUT_FILE_DIR)" },
		}
	}

	newoption
	{
		trigger     = "debugraw",
		description = "Output the raw workspace hierarchy in addition to the project file"
	}

	include("xcode_api.lua")

	return function(cfg)
		return (_ACTION == "xcode")
	end
