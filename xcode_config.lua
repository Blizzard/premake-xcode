--
-- xcode6_config.lua
-- Define the Apple XCode action and support functions.
-- Copyright (c) 2015 Blizzard Entertainment
--

	local api      = premake.api
	local xcode6   = premake.xcode6
	local project  = premake.project
	local solution = premake.solution


	function xcode6.merge(listA, listB)
		for key, item in pairs(listB) do
			if type(key) == 'number' then
				if not table.contains(listA, item) then
					table.insert(listA, item)
				end
			else
				listA[key] = item
			end
		end
		return listA
	end


	function xcode6.intersect(listA, listB)
		local result = {}
		for key, item in pairs(listB) do
			if type(key) == 'number' then
				if table.contains(listA, item) then
					table.insert(result, item)
				end
			else
				if listA[key] == item then
					result[key] = item
				end
			end
		end
		return result
	end


	function xcode6.subtract(listA, listB)
		local result = {}
		for key, item in pairs(listA) do
			if type(key) == 'number' then
				if not table.contains(listB, item) then
					table.insert(result, item)
				end
			else
				if not listB[key] then
					result[key] = item
				end
			end
		end
		return result
	end


	function xcode6.mergeConfigs(sln)
		for cfg in solution.eachconfig(sln) do
			if not cfg.flags then
				cfg.flags = {}
			end

			if not cfg.includedirs then
				cfg.includedirs = {}
			end

			if not cfg.libdirs then
				cfg.libdirs = {}
			end

			if not cfg.buildoptions then
				cfg.buildoptions = {}
			end

			if not cfg.linkoptions then
				cfg.linkoptions = {}
			end

			if not cfg.defines then
				cfg.defines = {}
			end

			-- union of everything.
			for prj in solution.eachproject(sln) do
				local prjCfg = project.getconfig(prj, cfg.buildcfg, cfg.platform)
				if prjCfg then
					cfg.flags        = xcode6.merge(cfg.flags, prjCfg.flags)
					cfg.includedirs  = xcode6.merge(cfg.includedirs, prjCfg.includedirs)
					cfg.libdirs      = xcode6.merge(cfg.libdirs, prjCfg.libdirs)
					cfg.buildoptions = xcode6.merge(cfg.buildoptions, prjCfg.buildoptions)
					cfg.linkoptions  = xcode6.merge(cfg.linkoptions, prjCfg.linkoptions)
					cfg.defines      = xcode6.merge(cfg.defines, prjCfg.defines)
				end
			end

			-- now remove everything that is not common to everything.
			for prj in solution.eachproject(sln) do
				local prjCfg = project.getconfig(prj, cfg.buildcfg, cfg.platform)
				if prjCfg then
					cfg.flags        = xcode6.intersect(cfg.flags, prjCfg.flags)
					cfg.includedirs  = xcode6.intersect(cfg.includedirs, prjCfg.includedirs)
					cfg.libdirs      = xcode6.intersect(cfg.libdirs, prjCfg.libdirs)
					cfg.buildoptions = xcode6.intersect(cfg.buildoptions, prjCfg.buildoptions)
					cfg.linkoptions  = xcode6.intersect(cfg.linkoptions, prjCfg.linkoptions)
					cfg.defines      = xcode6.intersect(cfg.defines, prjCfg.defines)
				end
			end

			-- and finally remove the duplicate settings from the project specific configs.
			for prj in solution.eachproject(sln) do
				local prjCfg = project.getconfig(prj, cfg.buildcfg, cfg.platform)
				if prjCfg then
					prjCfg.flags        = xcode6.subtract(prjCfg.flags, cfg.flags)
					prjCfg.includedirs  = xcode6.subtract(prjCfg.includedirs, cfg.includedirs)
					prjCfg.libdirs      = xcode6.subtract(prjCfg.libdirs, cfg.libdirs)
					prjCfg.buildoptions = xcode6.subtract(prjCfg.buildoptions, cfg.buildoptions)
					prjCfg.linkoptions  = xcode6.subtract(prjCfg.linkoptions, cfg.linkoptions)
					prjCfg.defines      = xcode6.subtract(prjCfg.defines, cfg.defines)
				end
			end
		end
	end
