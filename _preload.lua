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
		os              = "macosx",

		valid_kinds     = { "ConsoleApp", "WindowedApp", "SharedLib", "StaticLib", "Makefile", "Utility", "None" },
		valid_languages = { "C", "C++" },
		valid_tools     = { cc = { "clang" } },

		onsolution = function(sln)
			require('xcode')

			premake.escaper(premake.xcode6.esc)
			premake.generate(sln, ".xcodeproj/project.pbxproj", premake.xcode6.solution)
		end,

		pathVars = {
			["file.basename"] = { absolute = false, token = "$(INPUT_FILE_BASE)" },
			["file.abspath"]  = { absolute = true,  token = "$(INPUT_FILE_PATH)" },
			["file.relpath"]  = { absolute = true,  token = "$(INPUT_FILE_PATH)" },
		}
	}

	newoption
	{
		trigger     = "debugraw",
		description = "Output the raw solution hierarchy in addition to the project file"
	}

	include("xcode_api.lua")

	return function(cfg)
		return (_ACTION == "xcode")
	end
