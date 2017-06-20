---
-- xcode/_preload.lua
-- Define the Apple XCode actions and new APIs.
-- Copyright (c) 2009-2015 Jason Perkins and the Premake project
---

	newaction
	{
		trigger         = "xcode",
		shortname       = "Xcode",
		description     = "Generate Apple Xcode 6 project",
		targetos        = "macosx",
		toolset         = "clang",

		valid_kinds     = { "ConsoleApp", "WindowedApp", "SharedLib", "StaticLib", "Makefile", "Utility", "None" },
		valid_languages = { "C", "C++" },
		valid_tools     = { cc = { "clang" } },

		onWorkspace = function(wks)
			require('xcode')

			premake.escaper(premake.xcode6.esc)
			premake.generate(wks, ".xcodeproj/project.pbxproj", premake.xcode6.workspace)
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
