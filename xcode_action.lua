--
-- xcode6_action.lua
-- Define the Apple XCode action and support functions.
-- Copyright (c) 2015 Blizzard Entertainment
--
	premake.xcode6 = { }
	local api      = premake.api
	local xcode6   = premake.xcode6
	local config   = premake.config
	local project  = premake.project
	local solution = premake.solution


	function xcode6.solution(sln)
		_p('// !$*UTF8*$!')
		_p('{')
		_p(1, 'archiveVersion = 1;')
		_p(1, 'classes = {')
		_p(1, '};')
		_p(1, 'objectVersion = 46;')

		migBuildRuleId = xcode6.newid('migBuildRuleId')

		xcode6.mergeConfigs(sln)
		local tree = xcode6.getSolutionTree(sln, function(a, b)
            if a.kind ~= b.kind then
                if a.kind == 'group' then
                    return true
                elseif b.kind == 'group' then
                    return false
                end
            end
            return a.name < b.name
        end)

        table.sort(sln.projects, function(a, b)
            if a.kind ~= b.kind then
                if a.kind == 'WindowedApp' then
                    return true
                elseif b.kind == 'WindowedApp' then
                    return false
                elseif a.kind == 'ConsoleApp' then
                    return true
                elseif b.kind == 'ConsoleApp' then
                    return false
                elseif a.kind == 'Utility' then
                    return true
                elseif b.kind == 'Utility' then
                    return false
                end
            end
            return a.name < b.name
        end)

		if tree then
			_p(1, 'objects = {')

			xcode6.PBXBuildFile(tree)
			xcode6.PBXBuildRule(tree)
			xcode6.PBXContainerItemProxy(tree)
			xcode6.PBXCopyFilesBuildPhase(tree)
			xcode6.PBXFileReference(tree)
			xcode6.PBXFrameworksBuildPhase(tree)
			xcode6.PBXGroup(tree)
			xcode6.PBXHeadersBuildPhase(tree)
			xcode6.PBXNativeTarget(tree)
			xcode6.PBXProject(tree)
			xcode6.PBXResourcesBuildPhase(tree)
			xcode6.PBXShellScriptBuildPhase(tree)
			xcode6.PBXSourcesBuildPhase(tree)
			xcode6.PBXTargetDependency(tree)
			xcode6.PBXVariantGroup(tree)
			xcode6.XCConfigurationList(tree)

			_p(1, '};')
			_p(1, 'rootObject = %s /* Project object */;', tree.id)
		end

		_p('}')

        if _OPTIONS.debugraw then
            local raw = premake.capture(function() premake.raw.solution(sln) end)
            f = io.open(path.join(sln.location, sln.name .. ".raw"), "w")
            if f then
                f:write(raw)
                f:close()
            end
        end
	end


	function xcode6.PBXBuildFile(tree)
	    _p('')
		_p('/* Begin PBXBuildFile section */')

        local files = { }
        premake.tree.traverse(tree, {
            onleaf = function(node)
                if node.buildId then
                    table.insert(files, node)
                end
            end
        })
        table.sort(files, function(a, b) return a.buildId < b.buildId end)
        for _, node in ipairs(files) do
            local settings = { }
            local file_settings = node.xcode_file_settings
            if file_settings then
                for k, v in pairs(file_settings) do
                    table.insert(settings, k .. ' = ' .. v)
                end
            end

            if #settings > 0 then
                settings = 'settings = {' .. table.concat(settings, ', ') .. '; }; '
            else
                settings = ''
            end

            _p(2, '%s /* %s in %s */ = { isa = PBXBuildFile; fileRef = %s /* %s */; %s};', node.buildId, node.name, node.buildCategory, node.id, node.name, settings)
        end

		_p('/* End PBXBuildFile section */')
	end


	function xcode6.PBXBuildRule(tree)
	    _p('')
		_p('/* Begin PBXBuildRule section */')
		_p('/* End PBXBuildRule section */')
	end


	function xcode6.PBXContainerItemProxy(tree)
		_p('')
		_p('/* Begin PBXContainerItemProxy section */')

        local entries = { }
		for prj in solution.eachproject(tree.solution) do
		    table.insert(entries, prj.xcodeNode)
		end
        table.sort(entries, function(a, b) return a.containerItemProxyId < b.containerItemProxyId end)
		for _, entry in ipairs(entries) do
			_p(2, '%s /* PBXContainerItemProxy */ = {', entry.containerItemProxyId)
			_p(3, 'isa = PBXContainerItemProxy;')
			_p(3, 'containerPortal = %s /* Project object */;', tree.id)
			_p(3, 'proxyType = 1;')
			_p(3, 'remoteGlobalIDString = %s;', entry.targetId)
			_p(3, 'remoteInfo = %s;', xcode6.quoted(entry.name))
			_p(2, '};')
		end

		_p('/* End PBXContainerItemProxy section */')
	end


	function xcode6.PBXCopyFilesBuildPhase(tree)
		_p('')
		_p('/* Begin PBXCopyFilesBuildPhase section */')


		_p('/* End PBXCopyFilesBuildPhase section */')
	end


	function xcode6.PBXFileReference(tree)
		_p('')
		_p('/* Begin PBXFileReference section */')

        local entries = { }
		premake.tree.traverse(tree, {
			onleaf = function(node) table.insert(entries, node) end
		})

        table.sort(entries, function(a, b) return a.id < b.id end)
        for _, node in ipairs(entries) do
            if node.kind == 'fileConfig' then
                _p(2,'%s /* %s */ = {isa = PBXFileReference; lastKnownFileType = %s; name = %s; path = %s; sourceTree = "<group>"; };',
                    node.id, node.name, xcode6.quoted(node.fileType), xcode6.quoted(node.name), xcode6.quoted(node.relpath))
            elseif node.kind == 'link' then
                _p(2,'%s /* %s */ = {isa = PBXFileReference; lastKnownFileType = %s; name = %s; path = %s; sourceTree = %s; };',
                    node.id, node.name, xcode6.quoted(node.fileType), xcode6.quoted(node.name), xcode6.quoted(node.path), xcode6.quoted(node.sourceTree))
            elseif node.kind == 'product' then
                _p(2,'%s /* %s */ = {isa = PBXFileReference; explicitFileType = %s; includeInIndex = 0; path = %s; sourceTree = BUILT_PRODUCTS_DIR; };',
                    node.id, node.name, node.targetType, xcode6.quoted(node.name))
            end
		end

		_p('/* End PBXFileReference section */')
	end


	function xcode6.PBXFrameworksBuildPhase(tree)
		_p('')
		_p('/* Begin PBXFrameworksBuildPhase section */')

        local entries = { }
		for prj in solution.eachproject(tree.solution) do
			if prj.xcodeNode.frameworkBuildPhaseId then
			    table.insert(entries, prj.xcodeNode)
			end
		end

        table.sort(entries, function(a, b) return a.frameworkBuildPhaseId < b.frameworkBuildPhaseId end)
        for _, entry in ipairs(entries) do
            seen = { }
            links = { }
            for _, cfgT in ipairs(entry.configList.children) do
                for _, link in ipairs(cfgT.links) do
                    if not seen[link] then
                        seen[link] = true
                        table.insert(links, link)
                    end
                end
            end

            _p(2, '%s /* Frameworks */ = {', entry.frameworkBuildPhaseId);
            _p(3, 'isa = PBXFrameworksBuildPhase;')
            _p(3, 'buildActionMask = 2147483647;')
            _p(3, 'files = (')
                for _, dep in ipairs(entry.dependencies) do
                    _p(4, '%s /* %s */,', dep.xcodeNode.product.buildId, dep.name)
                end
                for _, linkT in ipairs(entry.frameworks) do
                    _p(4, '%s /* %s */,', linkT.buildId, linkT.name)
                end
                for _, link in ipairs(links) do
                    _p(4, '%s /* %s */,', link.buildId, link.name)
                end
            _p(3, ');')
            _p(3, 'runOnlyForDeploymentPostprocessing = 0;')
            _p(2, '};')
		end

		_p('/* End PBXFrameworksBuildPhase section */')
	end


	function xcode6.PBXGroup(tree)
		local settings = {}

		premake.tree.traverse(tree, {
			onnode = function(node)
				-- Skip over anything that isn't a group
				if node.kind == 'fileConfig' or node.kind == 'vgroup' or #node.children <= 0 then
					return
				end

				settings[node.productGroupId] = function()
					_p(2,'%s /* %s */ = {', node.productGroupId, node.name)
					_p(3,'isa = PBXGroup;')
					_p(3,'children = (')
					for _, childnode in ipairs(node.children) do
						if childnode.kind == 'fileConfig' or childnode.kind == 'link' or childnode.kind == 'product' then
							_p(4,'%s /* %s */,', childnode.id, childnode.name)
						else
							_p(4,'%s /* %s */,', childnode.productGroupId, childnode.name)
						end
					end
					_p(3,');')
					_p(3,'name = %s;', premake.xcode6.quoted(node.name))
					_p(3,'sourceTree = "<group>";')
					_p(2,'};')
				end
			end}, true)

		if not table.isempty(settings) then
			_p('')
			_p('/* Begin PBXGroup section */')
			xcode6.printSettingsTable(2, settings)
			_p('/* End PBXGroup section */')
		end
	end


	function xcode6.PBXHeadersBuildPhase(tree)
		_p('')
		_p('/* Begin PBXHeadersBuildPhase section */')


		_p('/* End PBXHeadersBuildPhase section */')
	end


	function xcode6.PBXNativeTarget(tree)
		_p('')
		_p('/* Begin PBXNativeTarget section */')

        local entries = { }
		for prj in solution.eachproject(tree.solution) do
		    table.insert(entries, prj.xcodeNode)
		end

		table.sort(entries, function(a, b) return a.targetId < b.targetId end)
		for _, entry in ipairs(entries) do
			_p(2, '%s /* %s */ = {', entry.targetId, entry.name);
			_p(3, 'isa = PBXNativeTarget;')
			_p(3, 'buildConfigurationList = %s /* Build configuration list for %s "%s" */;', entry.configList.id, entry.configList.isa, entry.name)

			_p(3, 'buildPhases = (')
			if #entry.prebuild > 0 then
			    for _, script in ipairs(entry.prebuild) do
    			    _p(4, '%s /* Run Script */,', script.id)
    			end
			end

			_p(4, '%s /* Sources */,', entry.sourcesBuildPhaseId)

			if #entry.prelink > 0 then
			    for _, script in ipairs(entry.prelink) do
    			    _p(4, '%s /* Run Script */,', script.id)
    			end
			end

			if entry.frameworkBuildPhaseId then
				_p(4, '%s /* Frameworks */,', entry.frameworkBuildPhaseId)
			end

			if #entry.postbuild > 0 then
			    for _, script in ipairs(entry.postbuild) do
    			    _p(4, '%s /* Run Script */,', script.id)
    			end
			end

			_p(3, ');')

			_p(3, 'buildRules = (')
			_p(3, ');')

			_p(3, 'dependencies = (')
			local deps = entry.dependencies
			if (deps and #deps > 0) then
				for _, dep in ipairs(deps) do
					_p(4, '%s /* PBXTargetDependency */,', dep.xcodeNode.targetDependencyId)
				end
			end
			_p(3, ');')

			_p(3, 'name = %s;', xcode6.quoted(entry.name))
			_p(3, 'productName = %s;', xcode6.quoted(entry.name))
			_p(3, 'productReference = %s /* %s */;', entry.product.id, entry.product.name)
			_p(3, 'productType = "%s";', entry.product.productType)
			_p(2, '};')
		end

		_p('/* End PBXNativeTarget section */')
	end


	function xcode6.PBXProject(tree)
		local sln = tree.solution

		_p('')
		_p('/* Begin PBXProject section */')

		_p(2, '%s /* Project object */ = {', tree.id)
		_p(3, 'isa = PBXProject;')
		_p(3, 'attributes = {')
		_p(4, 'BuildIndependentTargetsInParallel = YES;')
		_p(4, 'LastUpgradeCheck = 0630;')
		_p(3, '};')

		_p(3, 'buildConfigurationList = %s /* Build configuration list for %s "%s" */;', tree.configList.id, tree.configList.isa, sln.name)
		_p(3, 'compatibilityVersion = "Xcode 3.2";')
		_p(3, 'developmentRegion = English;')
		_p(3, 'hasScannedForEncodings = 0;')
		_p(3, 'knownRegions = (')
		_p(4, 'English,')
		_p(4, 'Base,')
		_p(3, ');')

		_p(3, 'mainGroup = %s /* %s */;', tree.productGroupId, tree.name)
		_p(3, 'productRefGroup = %s /* %s */;', tree.products.productGroupId, tree.products.name)
		_p(3, 'projectDirPath = "";')
		_p(3, 'projectRoot = "%s";', solution.getrelative(sln, sln.basedir))
		_p(3, 'targets = (')

		for prj in solution.eachproject(sln) do
			_p(4, '%s /* %s */,', prj.xcodeNode.targetId, prj.name)
		end

		_p(3, ');')
		_p(2, '};')
		_p('/* End PBXProject section */')
	end


	function xcode6.PBXResourcesBuildPhase(tree)
		_p('')
		_p('/* Begin PBXResourcesBuildPhase section */')


		_p('/* End PBXResourcesBuildPhase section */')
	end


	function xcode6.PBXShellScriptBuildPhase(tree)
		_p('')
		_p('/* Begin PBXShellScriptBuildPhase section */')

        local entries = { }
        for prj in solution.eachproject(tree.solution) do
            for _, entry in ipairs(prj.xcodeNode.prebuild) do
                table.insert(entries, entry)
            end
            for _, entry in ipairs(prj.xcodeNode.prelink) do
                table.insert(entries, entry)
            end
            for _, entry in ipairs(prj.xcodeNode.postbuild) do
                table.insert(entries, entry)
            end
        end

        table.sort(entries, function(a, b) return a.id < b.id end)
        for _, entry in ipairs(entries) do
            _p(2, '%s /* Run Script */ = {', entry.id)
            _p(3, 'isa = PBXShellScriptBuildPhase;')
            _p(3, 'buildActionMask = 2147483647;')
			_p(3, 'files = (')
			_p(3, ');')
			_p(3, 'inputPaths = (')
			_p(3, ');')
			_p(3, 'name = "Run Script";')
			_p(3, 'outputPaths = (')
			_p(3, ');')
			_p(3, 'runOnlyForDeploymentPostprocessing = 0;')
			_p(3, 'shellPath = /bin/sh;')
			_p(3, 'shellScript = "%s";', xcode6.quoted(entry.cmd))
            _p(2, '};')
        end

		_p('/* End PBXShellScriptBuildPhase section */')
	end


	function xcode6.PBXSourcesBuildPhase(tree)
		_p('')
		_p('/* Begin PBXSourcesBuildPhase section */')

        local entries = { }
		for prj in solution.eachproject(tree.solution) do
		    table.insert(entries, prj.xcodeNode)
		end

        table.sort(entries, function(a, b) return a.sourcesBuildPhaseId < b.sourcesBuildPhaseId end)
        for _, entry in ipairs(entries) do
			_p(2, '%s /* Sources */ = {', entry.sourcesBuildPhaseId)
			_p(3, 'isa = PBXSourcesBuildPhase;')
			_p(3, 'buildActionMask = 2147483647;')

			_p(3, 'files = (')
			premake.tree.traverse(entry, {
				onleaf = function(node)
					if node.buildId then
						_p(4,'%s /* %s in %s */,', node.buildId, node.name, node.buildCategory)
					end
				end})
			_p(3, ');')
			_p(3, 'runOnlyForDeploymentPostprocessing = 0;')
			_p(2, '};')
		end

		_p('/* End PBXSourcesBuildPhase section */')
	end


	function xcode6.PBXTargetDependency(tree)
		_p('')
		_p('/* Begin PBXTargetDependency section */')

        local entries = { }
		for prj in solution.eachproject(tree.solution) do
		    table.insert(entries, prj.xcodeNode)
		end

        table.sort(entries, function(a, b) return a.targetDependencyId < b.targetDependencyId end)
        for _, entry in ipairs(entries) do
			_p(2, '%s /* PBXTargetDependency */ = {', entry.targetDependencyId)
			_p(3, 'isa = PBXTargetDependency;')
			_p(3, 'target = %s /* %s */;', entry.targetId, entry.name)
			_p(3, 'targetProxy = %s /* PBXContainerItemProxy */;', entry.containerItemProxyId)
			_p(2, '};')
		end

		_p('/* End PBXTargetDependency section */')
	end


	function xcode6.PBXVariantGroup(tree)
		_p('')
		_p('/* Begin PBXVariantGroup section */')


		_p('/* End PBXVariantGroup section */')
	end


	function xcode6.XCBuildConfiguration(node)

		local settings = {}
		local cfg = node.config
		local prj = cfg.project
		local sln = cfg.solution

		if cfg.flags.Cpp11 then
			settings['CLANG_CXX_LANGUAGE_STANDARD'] = 'c++0x'
		end

		if cfg.flags.NoExceptions then
			settings['GCC_ENABLE_CPP_EXCEPTIONS'] = 'NO'
			settings['GCC_ENABLE_OBJC_EXCEPTIONS'] = 'NO'
		end

		if cfg.flags.NoRTTI then
			settings['GCC_ENABLE_CPP_RTTI'] = 'NO'
		end

		if cfg.flags.Symbols and not cfg.flags.NoEditAndContinue then
			settings['GCC_ENABLE_FIX_AND_CONTINUE'] = 'YES'
		end

		local optimizeMap = { On = 3, Size = 's', Speed = 3, Full = 'fast', Debug = 1 }
		settings['GCC_OPTIMIZATION_LEVEL'] = optimizeMap[cfg.optimize] or 0

		if cfg.pchheader and not cfg.flags.NoPCH then
			settings['GCC_PRECOMPILE_PREFIX_HEADER'] = 'YES'
			settings['GCC_PREFIX_HEADER'] = solution.getrelative(sln, path.join(prj.basedir, cfg.pchsource or cfg.pchheader))
		end

		settings['GCC_PREPROCESSOR_DEFINITIONS'] = table.join('$(inherited)', premake.esc(cfg.defines))

		settings["GCC_SYMBOLS_PRIVATE_EXTERN"] = 'NO'

		if cfg.flags.FatalWarnings then
			settings['GCC_TREAT_WARNINGS_AS_ERRORS'] = 'YES'
		end

		settings['GCC_WARN_ABOUT_RETURN_TYPE'] = 'YES'
		settings['GCC_WARN_UNUSED_VARIABLE'] = 'YES'

		if #cfg.includedirs > 0 then
			settings['HEADER_SEARCH_PATHS']      = table.join('$(inherited)', solution.getrelative(sln, cfg.includedirs))
		end

		-- get libdirs and links
		if cfg.libdirs and #cfg.libdirs > 0 then
			settings['LIBRARY_SEARCH_PATHS']     = table.join('$(inherited)',
			                                        table.translate(config.getlinks(cfg, 'siblings', 'directory'),
			                                            function(s)
			                                                return path.rebase(s, prj.location, sln.location)
			                                            end))
		end

		local fwdirs = xcode6.getFrameworkDirs(node)
		if fwdirs and #fwdirs > 0 then
			settings['FRAMEWORK_SEARCH_PATHS']   = table.join('$(inherited)', fwdirs)
		end

		if prj then
			settings['OBJROOT']                  = solution.getrelative(sln, cfg.objdir)
			settings['CONFIGURATION_BUILD_DIR']  = solution.getrelative(sln, cfg.buildtarget.directory)
			settings['PRODUCT_NAME']             = cfg.buildtarget.basename
		else
			settings['USE_HEADERMAP']            = 'NO'
			settings['LIBRARY_SEARCH_PATHS']     = solution.getrelative(sln, cfg.libdirs)
		end

		-- build list of "other" C/C++ flags
		local checks = {
			["-ffast-math"]          = cfg.flags.FloatFast,
			["-ffloat-store"]        = cfg.flags.FloatStrict,
			["-fomit-frame-pointer"] = cfg.flags.NoFramePointer,
		}

		local flags = { }
		for flag, check in pairs(checks) do
			if check then
				table.insert(flags, flag)
			end
		end
		settings['OTHER_CFLAGS'] = table.join(flags, cfg.buildoptions)
		settings['OTHER_LDFLAGS'] = table.join(flags, cfg.linkoptions)

		if cfg.warnings == "Extra" then
			settings['WARNING_CFLAGS'] = '-Wall'
		elseif cfg.warnings == "Off" then
			settings['GCC_WARN_INHIBIT_ALL_WARNINGS'] = 'YES'
		end

        if cfg.xcode_settings then
            settings = table.merge(settings, cfg.xcode_settings)
        end

		_p(2, '%s /* %s */ = {', node.id, node.name)
		_p(3, 'isa = XCBuildConfiguration;')
		_p(3, 'buildSettings = {')
		xcode6.printSettingsTable(4, settings)
		_p(3, '};')
		_p(3, 'name = %s;', xcode6.quoted(node.name))
		_p(2, '};')
	end


	function xcode6.XCConfigurationList(tree)
		local configLists = {}
		local configs = {}

		-- find all configs and config lists.
		premake.tree.traverse(tree, {
			onnode = function(node)
				if node.configList then
					configLists[node.configList.id] = node.configList;
					for _,cfg in ipairs(node.configList.children) do
						configs[cfg.id] = cfg
					end
				end
			end
		}, true)

		_p('')
		_p('/* Begin XCBuildConfiguration section */')
		local keys = table.keys(configs)
		table.sort(keys)
		for _, k in ipairs(keys) do
			xcode6.XCBuildConfiguration(configs[k]);
		end
		_p('/* End XCBuildConfiguration section */')

		_p('')
		_p('/* Begin XCConfigurationList section */')
		keys = table.keys(configLists)
		table.sort(keys)
		for _, k in ipairs(keys) do
			local list = configLists[k]

			_p(2, '%s /* Build configuration list for %s "%s" */ = {', list.id, list.isa, list.name)
			_p(3, 'isa = XCConfigurationList;')
			_p(3, 'buildConfigurations = (')
			for _, cfg in ipairs(list.children) do
				_p(4, '%s /* %s */,', cfg.id, cfg.name)
			end
			_p(3, ');')
			_p(3, 'defaultConfigurationIsVisible = 0;')
			_p(3, 'defaultConfigurationName = "%s";', list.children[1].name)
			_p(2, '};')
		end
		_p('/* End XCConfigurationList section */')
	end

