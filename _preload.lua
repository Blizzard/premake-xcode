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

		valid_kinds     = { "ConsoleApp", "WindowedApp", "SharedLib", "StaticLib", "Makefile", "None" },
		valid_languages = { "C", "C++" },
		valid_tools     = { cc = { "clang" } },

		onsolution = function(sln)
			require('xcode')

			premake.escaper(premake.xcode6.esc)
			premake.generate(sln, ".xcodeproj/project.pbxproj", premake.xcode6.solution)
		end,

		supportsconfig = function(cfg)
			if (cfg.platform == 'x32') then
				return false
			end
			return true
		end,
	}
