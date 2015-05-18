--
-- xcode6_utils.lua
-- Define the Apple XCode action and support functions.
-- Copyright (c) 2015 Tom van Dijck
--
	local api      = premake.api
	local xcode6   = premake.xcode6
	local project  = premake.project
	local solution = premake.solution


	function premake.xcode6.newid(...)
		local name = table.concat({...}, ';');
		return string.sub(name:sha1(), 1, 24)
	end


	function premake.xcode6.getFileType(filename)
		local types = {
			[".a"]         = "archive.ar",
			[".app"]       = "wrapper.application",
			[".c"]         = "sourcecode.c.c",
			[".cc"]        = "sourcecode.cpp.cpp",
			[".cpp"]       = "sourcecode.cpp.cpp",
			[".css"]       = "text.css",
			[".cxx"]       = "sourcecode.cpp.cpp",
			[".dylib"]     = "compiled.mach-o.dylib",
			[".S"]         = "sourcecode.asm.asm",
			[".framework"] = "wrapper.framework",
			[".gif"]       = "image.gif",
			[".h"]         = "sourcecode.c.h",
			[".hh"]        = "sourcecode.cpp.h",
			[".hpp"]       = "sourcecode.cpp.h",
			[".hxx"]       = "sourcecode.cpp.h",
			[".html"]      = "text.html",
			[".inl"]       = "sourcecode.c.h",
			[".lua"]       = "sourcecode.lua",
			[".m"]         = "sourcecode.c.objc",
			[".mm"]        = "sourcecode.cpp.objc",
			[".mig"]       = "sourcecode.mig",
			[".nib"]       = "wrapper.nib",
			[".pch"]       = "sourcecode.c.h",
			[".plist"]     = "text.plist.xml",
			[".strings"]   = "text.plist.strings",
			[".xib"]       = "file.xib",
			[".icns"]      = "image.icns",
			[".s"]         = "sourcecode.asm",
			[".sh"]        = "text.script.sh",
			[".bmp"]       = "image.bmp",
			[".wav"]       = "audio.wav",
			[".xcassets"]  = "folder.assetcatalog",
			[".xcconfig"]  = "text.xcconfig",
			[".xml"]       = "text.xml",
		}

		local ext = string.lower(path.getextension(filename));
		return types[ext] or "text"
	end


	function premake.xcode6.getBuildCategory(filename)
		local categories = {
			[".a"] = "Frameworks",
			[".c"] = "Sources",
			[".cc"] = "Sources",
			[".cpp"] = "Sources",
			[".cxx"] = "Sources",
			[".dylib"] = "Frameworks",
			[".framework"] = "Frameworks",
			[".m"] = "Sources",
			[".mm"] = "Sources",
			[".strings"] = "Resources",
			[".nib"] = "Resources",
			[".xib"] = "Resources",
			[".icns"] = "Resources",
			[".s"] = "Sources",
			[".S"] = "Sources",
		}
		return categories[path.getextension(filename)]
	end


	function premake.xcode6.getProductType(prj)
		local types = {
			ConsoleApp  = "com.apple.product-type.tool",
			WindowedApp = "com.apple.product-type.application",
			StaticLib   = "com.apple.product-type.library.static",
			SharedLib   = "com.apple.product-type.library.dynamic",
		}
		return types[prj.kind]
	end


	function premake.xcode6.getTargetType(prj)
		local types = {
			ConsoleApp  = "\"compiled.mach-o.executable\"",
			WindowedApp = "wrapper.application",
			StaticLib   = "archive.ar",
			SharedLib   = "\"compiled.mach-o.dylib\"",
		}
		return types[prj.kind]
	end


	function premake.xcode6.getTargetName(prj, cfg)
		if prj.external then
			return cfg.project.name
		end
		return cfg.buildtarget.bundlename ~= "" and cfg.buildtarget.bundlename or cfg.buildtarget.name;
	end


	function premake.xcode6.isItemResource(project, node)
		local res;
		if project and project.xcodebuildresources and type(project.xcodebuildresources) == "table" then
			res = project.xcodebuildresources
		end

		local function checkItemInList(item, list)
			if item and list and type(list) == "table" then
				for _,v in pairs(list) do
					if string.find(item, v) then
						return true
					end
				end
			end
			return false
		end

		return checkItemInList(node.path, res);
	end


	function premake.xcode6.getFrameworkDirs(cfgT)
		local done = {}
		local dirs = {}

		if not cfgT.project then
			return dirs
		end

		for _, linkT in ipairs(cfgT.project.xcodeNode.frameworks) do
			if linkT.sourceTree == 'SOURCE_ROOT' then
				local dir = path.getdirectory(linkT.path)
				if #dir > 1 and not done[dir] then
					done[dir] = true
					table.insert(dirs, dir)
				end
			end
		end
		return dirs
	end

	function premake.xcode6.getFrameworkPath(nodePath)
		--respect user supplied paths
		-- look for special variable-starting paths for different sources
		local _, matchEnd, variable = string.find(nodePath, "^%$%((.+)%)/")
		if variable then
			-- by skipping the last '/' we support the same absolute/relative
			-- paths as before
			nodePath = string.sub(nodePath, matchEnd + 1)
		end

		if string.find(nodePath,'/')  then
			if string.find(nodePath,'^%.') then
				pth = nodePath
				src = "SOURCE_ROOT"
				variable = src
			else
				pth = nodePath
				src = "<absolute>"
			end
		end

		-- if it starts with a variable, use that as the src instead
		if variable then
			src = variable
			-- if we are using a different source tree, it has to be relative
			-- to that source tree, so get rid of any leading '/'
			if string.find(pth, '^/') then
				pth = string.sub(pth, 2)
			end
		else
		    pth = "System/Library/Frameworks/" .. nodePath
			src = "SDKROOT"
		end

		return pth, src
	end


	local escapeSpecialChars = {
		['\n'] = '\\n',
		['\r'] = '\\r',
		['\t'] = '\\t',
	}


	local function escapeChar(c)
		return escapeSpecialChars[c] or '\\'..c
	end


	local function escapeArg(value)
		value = value:gsub('[\'"\\\n\r\t ]', escapeChar)
		return value
	end


	local function escapeSetting(value)
		value = value:gsub('["\\\n\r\t]', escapeChar)
		return value
	end


	function premake.xcode6.quoted(value)
		value = value..''
		if not value:match('^[%a%d_./]+$') then
			value = '"' .. escapeSetting(value) .. '"'
		end
		return value
	end


	function premake.xcode6.filterEmpty(dirs)
		return table.translate(dirs, function(val)
			if val and #val > 0 then
				return val
			else
				return nil
			end
		end)
	end


	function premake.xcode6.printSetting(level, name, value)
		if type(value) == 'function' then
			value(level, name)
		elseif type(value) ~= 'table' then
			_p(level, '%s = %s;', premake.xcode6.quoted(name), premake.xcode6.quoted(value))
		--elseif #value == 1 then
			--_p(level, '%s = %s;', premake.xcode6.quoted(name), premake.xcode6.quoted(value[1]))
		elseif #value >= 1 then
			_p(level, '%s = (', premake.xcode6.quoted(name))
			for _, item in ipairs(value) do
				_p(level + 1, '%s,', premake.xcode6.quoted(item))
			end
			_p(level, ');')
		end
	end


	function premake.xcode6.printSettingsTable(level, settings)
		-- Maintain alphabetic order to be consistent
		local keys = table.keys(settings)
		table.sort(keys)
		for _, k in ipairs(keys) do
			premake.xcode6.printSetting(level, k, settings[k])
		end
	end


