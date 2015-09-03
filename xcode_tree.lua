--
-- xcode6_tree.lua
-- Define the Apple XCode action and support functions.
-- Copyright (c) 2015 Blizzard Entertainment
--

	local api      = premake.api
	local config   = premake.config
	local context  = premake.context
	local xcode6   = premake.xcode6
	local project  = premake.project
	local solution = premake.solution
	local tree     = premake.tree


	local function groupsorter(a, b)
		if a.isa ~= b.isa then
			if a.isa == 'PBXGroup' then
				return true
			elseif b.isa == 'PBXGroup' then
				return false
			end
		end
		return string.lower(a.name or a.path) < string.lower(b.name or b.path)
	end

	function xcode6.getSolutionTree(sln)
		if sln.xcodeNode then
			return sln.xcodeNode
		end
		return xcode6.buildSolutionTree(sln)
	end


	function xcode6.buildSolutionTree(sln)
		print('start buildSolutionTree')
		local pbxproject = {
			_id = xcode6.newid(sln.name, 'PBXProject'),
			_comment = 'Project object',
			_fileRefs = { }, -- contains only files used by multiple targets (e.g. libraries, not source files)
			isa = 'PBXProject',
			attributes = {
				BuildIndependentTargetsInParallel = 'YES',
				ORGANIZATIONNAME = 'Blizzard Entertainment'
			},
			buildConfigurationList = {
				_id = xcode6.newid(sln.name, 'XCConfigurationList'),
				_comment = string.format('Build configuration list for PBXProject "%s"', sln.name),
				isa = 'XCConfigurationList',
				buildConfigurations = { },
				defaultConfigurationIsVisible = 0,
				defaultConfigurationName = sln.configs[1].name
			},
			compatibilityVersion = 'Xcode 3.2',
			developmentRegion = 'English',
			hasScannedForEncodings = 0,
			knownRegions = {
				'Base'
			},
			mainGroup = {
				_id = xcode6.newid(sln.name, 'PBXGroup'),
				isa = 'PBXGroup',
				children = { },
				sourceTree = '<group>'
			},
			targets = { }
		}
		sln.xcodeNode = pbxproject

		local targetsGroup = {
			_id = xcode6.newid(sln.name, 'Targets', 'PBXGroup'),
			_comment = 'Targets',
			isa = 'PBXGroup',
			children = { },
			name = 'Targets',
			sourceTree = '<group>'
		}
		local frameworksGroup = {
			_id = xcode6.newid(sln.name, 'Frameworks', 'PBXGroup'),
			_comment = 'Frameworks',
			isa = 'PBXGroup',
			children = { },
			name = 'Frameworks',
			sourceTree = '<group>'
		}
		local librariesGroup = {
			_id = xcode6.newid(sln.name, 'Libraries', 'PBXGroup'),
			_comment = 'Libraries',
			isa = 'PBXGroup',
			children = { },
			name = 'Libraries',
			sourceTree = '<group>'
		}
		local productsGroup = {
			_id = xcode6.newid(sln.name, 'Products', 'PBXGroup'),
			_comment = 'Products',
			isa = 'PBXGroup',
			children = { },
			name = 'Products',
			sourceTree = '<group>'
		}

		pbxproject.productRefGroup = productsGroup
		table.insert(pbxproject.mainGroup.children, targetsGroup)
		table.insert(pbxproject.mainGroup.children, frameworksGroup)
		table.insert(pbxproject.mainGroup.children, librariesGroup)
		table.insert(pbxproject.mainGroup.children, productsGroup)
		pbxproject._frameworksGroup = frameworksGroup
		pbxproject._librariesGroup = librariesGroup

		for cfg in solution.eachconfig(sln) do
			table.insert(pbxproject.buildConfigurationList.buildConfigurations, {
				_id = xcode6.newid(cfg.name, sln.name, 'XCBuildConfiguration'),
				_comment = cfg.name,
				isa = 'XCBuildConfiguration',
				buildSettings = xcode6.buildSettings(cfg),
				name = cfg.name
			})
		end

		local groups = { }
		for prj in solution.eachproject(sln) do
			local parentName = prj.group
			local parent = iif(parentName, groups[parentName], targetsGroup)
			if not parent then
				parent = {
					_id = xcode6.newid(parentName, 'PBXGroup'),
					_comment = parentName,
					isa = 'PBXGroup',
					children = { },
					name = parentName,
					sourceTree = '<group>'
				}
				groups[parentName] = parent
				table.insertsorted(targetsGroup.children, parent, function(a, b)
					return string.lower(a.name) < string.lower(b.name)
				end)
			end
			local prjNode = xcode6.buildProjectTree(prj, productsGroup)
			table.insertsorted(parent.children, prjNode._group, function(a, b)
				return string.lower(a.name) < string.lower(b.name)
			end)
			table.insertsorted(pbxproject.targets, prjNode, function(a, b)
				if a.productType ~= b.productType then
					if a.productType == "com.apple.product-type.application" then
						return true
					elseif b.productType == "com.apple.product-type.application" then
						return false
					elseif a.productType == "com.apple.product-type.tool" then
						return true
					elseif b.productType == "com.apple.product-type.tool" then
						return false
					elseif a.productType == "com.apple.product-type.framework" then
						return true
					elseif b.productType == "com.apple.product-type.framework" then
						return false
					end
				end

				return string.lower(a.name) < string.lower(b.name)
			end)
		end
		for prj in solution.eachproject(sln) do
			table.foreachi(project.getdependencies(prj), function(dep)
				local depNode = dep.xcodeNode
				table.insert(prj.xcodeNode.dependencies, {
					_id = xcode6.newid(prj.name, dep.name, 'PBXTargetDependency'),
					_comment = 'PBXTargetDependency',
					isa = 'PBXTargetDependency',
					target = depNode,
					targetProxy = {
						_id = xcode6.newid(dep.solution.name, dep.name, 'PBXContainerItemProxy'),
						_comment = 'PBXContainerItemProxy',
						isa = 'PBXContainerItemProxy',
						containerPortal = dep.solution.xcodeNode,
						proxyType = 1,
						remoteGlobalIDString = depNode._id,
						remoteInfo = dep.name
					}
				})
			end)
		end

		print('end buildSolutionTree')
		return pbxproject
	end

	function xcode6.buildProjectTree(prj, productsGroup)
		local pbxtarget = prj.xcodeNode
		if pbxtarget then
			return pbxtarget
		end

		local sln = prj.solution
		local prjName = prj.name
		local slnName = sln.name
		local parentGroup = {
			_id = xcode6.newid(prjName, sln.xcodeNode.mainGroup._id, 'PBXGroup'),
			_comment = prjName,
			isa = 'PBXGroup',
			children = { },
			name = prjName,
			sourceTree = '<group>'
		}

		local productName = prj.targetname or prjName
		if prj.kind == 'Utility' or prj.kind == 'None' then
			pbxtarget = {
				_id = xcode6.newid(prjName, slnName, 'PBXAggregateTarget'),
				isa = 'PBXAggregateTarget',
			}
		else
			local productPath = xcode6.getTargetName(prj, project.getfirstconfig(prj))
			pbxtarget = {
				_id = xcode6.newid(prjName, slnName, 'PBXNativeTarget'),
				isa = 'PBXNativeTarget',
				buildRules = { },
				productReference = {
					_id = xcode6.newid(prjName, productName, 'PBXFileReference'),
					_comment = path.getname(productPath),
					_formatStyle = 'compact',
					isa = 'PBXFileReference',
					includeInIndex = 0,
					path = productPath,
					sourceTree = 'BUILT_PRODUCTS_DIR'
				},
				productType = xcode6.getProductType(prj)
			}

			table.insertsorted(productsGroup.children, pbxtarget.productReference, function(a, b)
				return string.lower(path.getname(a.path)) < string.lower(path.getname(b.path))
			end)
		end

		pbxtarget._comment = prjName
		pbxtarget._group = parentGroup
		pbxtarget._project = prj
		pbxtarget.buildConfigurationList = {
			_id = xcode6.newid(prjName, slnName, 'XCConfigurationList'),
			_comment = string.format('Build configuration list for PBXNativeTarget "%s"', prjName),
			isa = 'XCConfigurationList',
			buildConfigurations = { },
			defaultConfigurationIsVisible = 0,
			defaultConfigurationName = project.getfirstconfig(prj).name
		}
		pbxtarget.buildPhases = { }
		pbxtarget.dependencies = { }
		pbxtarget.name = prjName
		pbxtarget.productName = productName
		prj.xcodeNode = pbxtarget

		for cfg in project.eachconfig(prj) do
			table.insert(pbxtarget.buildConfigurationList.buildConfigurations, {
				_id = xcode6.newid(cfg.name, slnName, prjName, 'XCBuildConfiguration'),
				_comment = cfg.name,
				isa = 'XCBuildConfiguration',
				buildSettings = xcode6.buildSettings(cfg),
				name = cfg.name
			})
		end

		local cmdCount = 0
		if prj.prebuildcommands then
			table.foreachi(prj.prebuildcommands, function(cmd)
				table.insert(pbxtarget.buildPhases, {
					_id = xcode6.newid(tostring(cmdCount), cmd, prjName, slnName, 'PBXShellScriptBuildPhase'),
					_comment = 'Run Script',
					isa = 'PBXShellScriptBuildPhase',
					buildActionMask = 2147483647,
					files = { },
					inputPaths = { },
					name = 'Run Script',
					outputPaths = { },
					runOnlyForDeploymentPostprocessing = 0,
					shellPath = '/bin/sh',
					shellScript = os.translateCommands(cmd)
				})
				cmdCount = cmdCount + 1
			end)
		end

		files = tree.new()
		table.foreachi(prj._.files, function(file)
			local path = file.abspath
			local node = tree.add(files, solution.getrelative(sln, path), { kind = 'group' })
			node.kind = 'file'
			node.file = file
			node.exclude = file.flags and file.flags.ExcludeFromBuild
			if path ~= prj.icon then -- icons handled elsewhere
				local category = xcode6.getBuildCategory(node.name)
				node.category = category
				node.action = category == 'Sources' and 'build' or
					category == 'Resources' and 'copy' or nil
			end
		end)
		table.foreachi(prj.xcode_resources, function(file)
			file = solution.getrelative(sln, file)
			local lproj = file:match('^.*%.lproj%f[/]')
			if lproj then
				local parentPath = path.getdirectory(lproj)
				local resPath = path.getrelative(lproj, file)
				local filePath = path.join(path.getname(lproj), resPath)
				local parentNode = tree.add(files, parentPath, { kind = 'group' })
				local variantGroup = parentNode.children[resPath]
				if not variantGroup then
					variantGroup = tree.new(resPath)
					variantGroup.path = path.join(parentNode.path, variantGroup.name)
					variantGroup.kind = 'variantGroup'
					variantGroup.action = 'copy'
					variantGroup.category = 'Resources'
					tree.insert(parentNode, variantGroup)
				end
				local node = tree.new(filePath)
				node.kind = 'file'
				node.variantGroup = variantGroup
				node.loc = path.getbasename(lproj)
				tree.insert(variantGroup, node)
			else
				local node = tree.add(files, file, { kind = 'group' })
				node.kind = 'file'
				node.action = 'copy'
				node.category = 'Resources'
			end
		end)
		tree.traverse(files, {
			onnode = function(node)
				local parentPath = node.parent.filepath
				if node.kind == 'variantGroup' then
					node.filepath = parentPath
				else
					local localPath = tree.getlocalpath(node)
					node.filepath = parentPath and
						path.join(parentPath, localPath) or
						localPath
				end
			end
		})
		tree.trimroot(files)

		local sourcesPhase = {
			_id = xcode6.newid('Sources', prjName, slnName, 'PBXSourcesBuildPhase'),
			_comment = 'Sources',
			isa = 'PBXSourcesBuildPhase',
			buildActionMask = 2147483647,
			files = { },
			runOnlyForDeploymentPostprocessing = 0
		}
		local copyPhase = {
			_id = xcode6.newid('Resources', prjName, slnName, 'PBXResourcesBuildPhase'),
			_comment = 'Resources',
			isa = 'PBXResourcesBuildPhase',
			buildActionMask = 2147483647,
			files = { },
			runOnlyForDeploymentPostprocessing = 0
		}

		files.xcodeNode = parentGroup
		tree.traverse(files, {
			onleaf = function(node)
				local parentPath = node.parent.filepath
				local nodePath = tree.getlocalpath(node)
				local ref = {
					_id = xcode6.newid(node.filepath, prjName, slnName, 'PBXFileReference'),
					_formatStyle = 'compact',
					isa = 'PBXFileReference',
					path = parentPath and nodePath or node.filepath,
					sourceTree = '<group>'
				}
				node.xcodeNode = ref
				if node.variantGroup then
					ref.name = node.loc
					ref._comment = node.loc
					table.insertsorted(node.variantGroup.xcodeNode.children, ref,
						function(a, b)
							return string.lower(a.name) < string.lower(b.name)
						end)
				else
					local nodeName = path.getname(nodePath)
					ref.name = nodeName ~= ref.path and nodeName or nil
					ref._comment = nodeName
					table.insertsorted(parentGroup.children, ref, groupsorter)
					if node.action and not node.exclude then
						local buildFile = {
								_id = xcode6.newid(node.filepath, prjName, slnName, 'PBXBuildFile'),
								_comment = string.format('%s in %s', nodeName, node.category),
								_formatStyle = 'compact',
								isa = 'PBXBuildFile',
								fileRef = ref
							}
						if node.action == 'build' then
							local settings = xcode6.filesettings(node.file)
							buildFile.settings = next(settings) and settings
							table.insert(sourcesPhase.files, buildFile)
						elseif node.action == 'copy' then
							table.insert(copyPhase.files, buildFile)
						end
					end
				end
			end,
			onbranchenter = function(node)
				local parentPath = node.parent.filepath
				local nodePath = tree.getlocalpath(node)
				local nodeName = path.getname(nodePath)
				local variantPath = node.kind == 'variantGroup' and path.join(node.filepath, nodeName) or nil
				local grp = variantPath and {
					_id = xcode6.newid(path.join(node.filepath, nodeName), prjName, slnName, 'PBXVariantGroup'),
					_comment = nodeName,
					isa = 'PBXVariantGroup',
					children = { },
					sourceTree = '<group>'
				} or {
					_id = xcode6.newid(node.filepath, prjName, slnName, 'PBXGroup'),
					_comment = nodeName,
					isa = 'PBXGroup',
					children = { },
					path = parentPath and nodePath or node.filepath,
					sourceTree = '<group>'
				}
				grp.name = nodeName ~= grp.path and nodeName or nil
				table.insertsorted(parentGroup.children, grp, groupsorter)
				node.xcodeNode = grp
				parentGroup = grp

				if node.action and not node.exclude then
					local buildFile = {
						_id = xcode6.newid(variantPath or node.filepath, prjName, slnName, 'PBXBuildFile'),
						_comment = string.format('%s in %s', nodeName, node.category),
						_formatStyle = 'compact',
						isa = 'PBXBuildFile',
						fileRef = grp,
						settings = node.settings
					}
					if node.action == 'copy' then
						table.insert(copyPhase.files, buildFile)
					end
				end
			end,
			onbranchexit = function(node)
				parentGroup = node.parent.xcodeNode
			end
		})

		if #sourcesPhase.files > 0 then
			table.insert(pbxtarget.buildPhases, sourcesPhase)
		end

		table.foreachi(prj._.files, function(fcfg)
			if fcfg.buildcommands and #fcfg.buildcommands > 0 then
				local cmd = table.concat(fcfg.buildcommands, '\n')
				table.insert(pbxtarget.buildPhases, {
					_id = xcode6.newid(tostring(cmdCount), cmd, prjName, slnName, 'PBXShellScriptBuildPhase'),
					_comment = 'Process ' .. fcfg.name,
					isa = 'PBXShellScriptBuildPhase',
					buildActionMask = 2147483647,
					files = { },
					inputPaths = table.join({ solution.getrelative(sln, fcfg.abspath) },
									solution.getrelative(sln, fcfg.buildinputs)),
					name = 'Process ' .. fcfg.name,
					outputPaths = solution.getrelative(sln, fcfg.buildoutputs),
					runOnlyForDeploymentPostprocessing = 0,
					shellPath = '/bin/sh',
					shellScript = os.translateCommands(cmd)
				})
			end
		end)

		if prj.prelinkcommands then
			table.foreachi(prj.prelinkcommands, function(cmd)
				table.insert(pbxtarget.buildPhases, {
					_id = xcode6.newid(cmdCount, cmd, prjName, slnName, 'PBXShellScriptBuildPhase'),
					_comment = 'Run Script',
					isa = 'PBXShellScriptBuildPhase',
					buildActionMask = 2147483647,
					files = { },
					inputPaths = { },
					name = 'Run Script',
					outputPaths = { },
					runOnlyForDeploymentPostprocessing = 0,
					shellPath = '/bin/sh',
					shellScript = os.translateCommands(cmd)
				})
				cmdCount = cmdCount + 1
			end)
		end

		if prj.kind == 'ConsoleApp' or prj.kind == 'WindowedApp' or prj.kind == 'SharedLib' then
			local frameworksPhase = {
				_id = xcode6.newid('Frameworks', prjName, slnName, 'PBXFrameworksBuildPhase'),
				_comment = 'Frameworks',
				isa = 'PBXFrameworksBuildPhase',
				buildActionMask = 2147483647,
				files = { },
				runOnlyForDeploymentPostprocessing = 0
			}
			table.foreachi(prj.links, function(link)
				local sibling = sln.projects[link]
				local buildFileRef
				if sibling then
					local siblingNode = xcode6.buildProjectTree(sibling, productsGroup)
					if siblingNode.productReference then
						buildFileRef = {
							_id = xcode6.newid(siblingNode.productReference.path, link, prjName, slnName, 'PBXBuildFile'),
							_comment = path.getname(siblingNode.productReference.path) .. ' in Frameworks',
							_formatStyle = 'compact',
							isa = 'PBXBuildFile',
							fileRef = siblingNode.productReference
						}
					end
				else
					local isFramework = link:find('.framework$')
					local isSystem = not path.isabsolute(link)
					local filePath = isSystem and
						path.join(isFramework and 'System/Library/Frameworks' or 'usr/lib', link) or
						solution.getrelative(sln, link)
					local fileName = path.getname(filePath)

					local slnNode = sln.xcodeNode
					local fileRef = slnNode._fileRefs[filePath]
					if not fileRef then
						fileRef = {
							_id = xcode6.newid(filePath, slnName, 'PBXFileReference'),
							_comment = fileName,
							_formatStyle = 'compact',
							isa = 'PBXFileReference',
							name = fileName,
							path = filePath,
							sourceTree = isSystem and 'SDKROOT' or '<group>'
						}

						local group = isFramework and slnNode._frameworksGroup or slnNode._librariesGroup
						table.insertsorted(group.children, fileRef, groupsorter)
						slnNode._fileRefs[filePath] = fileRef
					end

					buildFileRef = {
						_id = xcode6.newid(filePath, link, prjName, slnName, 'PBXBuildFile'),
						_comment = fileName .. ' in Frameworks',
						_formatStyle = 'compact',
						isa = 'PBXBuildFile',
						fileRef = fileRef
					}
				end
				if prj.xcode_weaklinks[link] then
					buildFileRef.settings = {
						ATTRIBUTES = { 'Weak' }
					}
				end
				table.insert(frameworksPhase.files, buildFileRef)
			end)

			table.insert(pbxtarget.buildPhases, frameworksPhase)
		end

		if #copyPhase.files > 0 then
			table.insert(pbxtarget.buildPhases, copyPhase)
		end

		if prj.postbuildcommands then
			table.foreachi(prj.postbuildcommands, function(cmd)
				table.insert(pbxtarget.buildPhases, {
					_id = xcode6.newid(cmdCount, cmd, prjName, slnName, 'PBXShellScriptBuildPhase'),
					_comment = 'Run Script',
					isa = 'PBXShellScriptBuildPhase',
					buildActionMask = 2147483647,
					files = { },
					inputPaths = { },
					name = 'Run Script',
					outputPaths = { },
					runOnlyForDeploymentPostprocessing = 0,
					shellPath = '/bin/sh',
					shellScript = os.translateCommands(cmd)
				})
				cmdCount = cmdCount + 1
			end)
		end

		return pbxtarget
	end

	-- TODO:
	-- Querying a bunch of individual values from configsets like this is awful.  What we
	-- need is a way to query all values at once and then act on what we get back.
	-- Something like:
	--	local settings = { }
	--	local values = xcode6.fetchall(cfg)
	--	for k, v in pairs(values.removed) do
	--		removeactions[k](v, settings)
	--	end
	--	for k, v in pairs(values.added) do
	--		addactions[k](v, settings)
	--	end
	--	return settings
	function xcode6.buildSettings(cfg)
		local sln = cfg.solution
		local prj = cfg.project
		local settings = { }

		local booleanMap = { On = true, Off = false }
		local optimizeMap = { Off = 0, Debug = 1, On = 2, Speed = 'fast', Size = 's', Full = 3 }

		local flags, newflags, delflags = xcode6.fetchlocal(cfg, 'flags')
		local exceptionhandling = booleanMap[xcode6.fetchlocal(cfg, 'exceptionhandling')]
		local rtti = booleanMap[xcode6.fetchlocal(cfg, 'rtti')]
		local editandcontinue = booleanMap[xcode6.fetchlocal(cfg, 'editandcontinue')]
		local optimize = optimizeMap[xcode6.fetchlocal(cfg, 'optimize')]
		local pchsource = xcode6.fetchlocal(cfg, 'pchsource')
		local pchheader = xcode6.fetchlocal(cfg, 'pchheader')
		local defines, newdefines, deldefines = xcode6.fetchlocal(cfg, 'defines')
		local architecture = xcode6.fetchlocal(cfg, 'architecture')
		local includedirs, newincludedirs, delincludedirs = xcode6.fetchlocal(cfg, 'includedirs')
		local libdirs, newlibdirs, dellibdirs = xcode6.fetchlocal(cfg, 'libdirs')
		local runpathdirs, newrunpathdirs, delrunpathdirs = xcode6.fetchlocal(cfg, 'xcode_runpathdirs')
		local targetprefix = xcode6.fetchlocal(cfg, 'targetprefix')
		local disablewarnings, newdisablewarnings, deldisablewarnings = xcode6.fetchlocal(cfg, 'disablewarnings')
		local buildoptions, newbuildoptions, delbuildoptions = xcode6.fetchlocal(cfg, 'buildoptions')
		local linkoptions, newlinkoptions, dellinkoptions = xcode6.fetchlocal(cfg, 'linkoptions')
		local warnings = xcode6.fetchlocal(cfg, 'warnings')
		local xcode_settings, newxcode_settings, delxcode_settings = xcode6.fetchlocal(cfg, 'xcode_settings')

		local inheritldflags = true
		local inheritcflags = true

		local checkflags = { }
		if flags then
			local noinheritflags = delflags.FloatFast or delflags.FloatStrict or delflags.NoFramePointer
			inheritcflags = not (noinheritflags or #delbuildoptions > 0)
			inheritldflags = not (noinheritflags or delflags.FatalLinkWarnings)

			if inheritcflags then
				buildoptions = newbuildoptions
			end
			if inheritldflags then
				linkoptions = newlinkoptions
			end

			local changedflags = { }
			for _, flag in ipairs(delflags) do
				changedflags[flag] = false
			end
			for _, flag in ipairs(newflags) do
				changedflags[flag] = true
			end

			if changedflags['C++14'] ~= nil or changedflags['C++11'] ~= nil then
				if flags['C++14'] then
					settings.CLANG_CXX_LANGUAGE_STANDARD = 'c++14'
					settings.CLANG_CXX_LIBRARY = 'libc++'
				elseif flags['C++11'] then
					settings.CLANG_CXX_LANGUAGE_STANDARD = 'c++0x'
					settings.CLANG_CXX_LIBRARY = 'libc++'
				else
					settings.CLANG_CXX_LANGUAGE_STANDARD = 'c++98'
					settings.CLANG_CXX_LIBRARY = 'libstdc++'
				end
			end

			if changedflags.Symbols ~= nil then
				settings.GCC_ENABLE_FIX_AND_CONTINUE = changedflags.Symbols and editandcontinue
				settings.LD_GENERATE_MAP_FILE = changedflags.Symbols
			end

			if changedflags.FatalCompileWarnings ~= nil then
				settings.GCC_TREAT_WARNINGS_AS_ERRORS = changedflags.FatalCompileWarnings
			end
			if newflags.FatalLinkWarnings or (not inheritldflags and flags.FatalLinkWarnings) then
				linkoptions = table.join({ '-Xlinker', '-fatal_warnings' }, linkoptions)
			end

			-- build list of "other" C/C++ flags
			local lflags = inheritldflags and newflags or flags
			local lchecks = {
				["-ffast-math"]			 = lflags.FloatFast,
				["-ffloat-store"]		 = lflags.FloatStrict,
				["-fomit-frame-pointer"] = lflags.NoFramePointer,
			}
			local cflags = inheritcflags and newflags or flags
			local cchecks = {
				["-ffast-math"]			 = cflags.FloatFast,
				["-ffloat-store"]		 = cflags.FloatStrict,
				["-fomit-frame-pointer"] = cflags.NoFramePointer,
			}

			for flag, check in pairs(lchecks) do
				if check then
					table.insert(checkflags, flag)
				end
			end
		end

		settings.GCC_ENABLE_CPP_EXCEPTIONS  = exceptionhandling
		settings.GCC_ENABLE_OBJC_EXCEPTIONS = exceptionhandling
		settings.GCC_ENABLE_CPP_RTTI        = rtti

		settings.GCC_OPTIMIZATION_LEVEL = optimize

		if pchheader and not (flags and flags.NoPCH) then
			settings.GCC_PRECOMPILE_PREFIX_HEADER = true
			settings.GCC_PREFIX_HEADER = solution.getrelative(sln, path.join(prj.basedir, pchsource or pchheader))
		end

		if defines then
			if #deldefines > 0 then
				settings.GCC_PREPROCESSOR_DEFINITIONS = premake.esc(defines)
			elseif #newdefines > 0 then
				settings.GCC_PREPROCESSOR_DEFINITIONS = table.join('$(inherited)', premake.esc(newdefines))
			end
		end

		if architecture == 'x86' then
			settings.ARCHS = '$(ARCHS_STANDARD_32_BIT)'
		elseif architecture == 'x86_64' then
			settings.ARCHS = '$(ARCHS_STANDARD_64_BIT)'
		elseif architecture == 'universal' then
			settings.ARCHS = '$(ARCHS_STANDARD_32_64_BIT)'
		end

		if includedirs then
			if #delincludedirs > 0 then
				settings.HEADER_SEARCH_PATHS = solution.getrelative(sln, includedirs)
			elseif #newincludedirs > 0 then
				settings.HEADER_SEARCH_PATHS = table.join('$(inherited)', solution.getrelative(sln, newincludedirs))
			end
		end

		-- get libdirs and links
		if libdirs then
			newlibdirs = solution.getrelative(sln, newlibdirs)
			dellibdirs = solution.getrelative(sln, dellibdirs)
			if #dellibdirs == 0 then
				libdirs = newlibdirs
			end
			if prj then
				libdirs = table.join(table.translate(config.getlinks(cfg, 'siblings', 'directory', nil), function(s)
					return path.rebase(s, prj.location, sln.location)
				end), libdirs)
			end
			if #dellibdirs > 0 then
				settings.LIBRARY_SEARCH_PATHS = table.unique(libdirs)
			elseif #libdirs > 0 then
				settings.LIBRARY_SEARCH_PATHS = table.unique(table.join('$(inherited)', libdirs))
			end
		end

		local fwdirs = xcode6.getFrameworkDirs(cfg)
		if fwdirs and #fwdirs > 0 then
			settings.FRAMEWORK_SEARCH_PATHS = table.join('$(inherited)', fwdirs)
		end

		if runpathdirs then
			if #delrunpathdirs > 0 then
				settings.LD_RUNPATH_SEARCH_PATHS = runpathdirs
			elseif #newrunpathdirs > 0 then
				settings.LD_RUNPATH_SEARCH_PATHS = table.join('$(inherited)', newrunpathdirs)
			end
		end

		if prj then
			settings.OBJROOT					= solution.getrelative(sln, cfg.objdir)
			settings.CONFIGURATION_BUILD_DIR	= solution.getrelative(sln, cfg.buildtarget.directory)
			settings.PRODUCT_NAME				= cfg.buildtarget.basename
		else
			settings.SDKROOT					= 'macosx'
			settings.USE_HEADERMAP				= false
			settings.GCC_WARN_ABOUT_RETURN_TYPE	= true
			settings.GCC_WARN_UNUSED_VARIABLE 	= true
			settings.LD_MAP_FILE_PATH			= '$(CONFIGURATION_BUILD_DIR)/$(PRODUCT_NAME).map'
		end

		settings.EXECUTABLE_PREFIX = targetprefix

		local warn = nil
		if warnings == 'Extra' then
			warn = { '-Wall' }
		elseif warnings == 'Off' then
			settings.GCC_WARN_INHIBIT_ALL_WARNINGS = true
		elseif warnings == 'Default' then
			settings.GCC_WARN_INHIBIT_ALL_WARNINGS = false
		end

		if disablewarnings then
			disablewarnings = #deldisablewarnings > 0 and disablewarnings or newdisablewarnings
			if #disablewarnings > 0 then
				warn = warn or { }
				table.insertflat(warn, table.translate(disablewarnings, function(warning)
					return '-Wno-' .. warning
				end))
				if #deldisablewarnings == 0 and #warn > 0 then
					warn = table.join('$(inherited)', warn)
				end
			end
		end
		local cflags = table.join(checkflags, buildoptions)
		if inheritcflags then
			cflags = #cflags > 0 and table.join('$(inherited)', cflags) or nil
		end
		local ldflags = table.join(checkflags, linkoptions)
		if inheritldflags then
			ldflags = #ldflags > 0 and table.join('$(inherited)', ldflags) or nil
		end
		settings.WARNING_CFLAGS = warn
		settings.OTHER_CFLAGS = cflags
		settings.OTHER_LDFLAGS = ldflags

		if newxcode_settings then
			settings = table.merge(settings, newxcode_settings)
		end

		return settings
	end

	function xcode6.filesettings(file)
		local booleanMap = { On = true, Off = false }
		local optimizeMap = { Off = 0, Debug = 1, On = 2, Speed = 'fast', Size = 's', Full = 3 }

		local flags, newflags, delflags = xcode6.fetchlocal(file, 'flags')
		local exceptionhandling = booleanMap[xcode6.fetchlocal(file, 'exceptionhandling')]
		local rtti = booleanMap[xcode6.fetchlocal(file, 'rtti')]
		local editandcontinue = booleanMap[xcode6.fetchlocal(file, 'editandcontinue')]	-- TODO
		local optimize = optimizeMap[xcode6.fetchlocal(file, 'optimize')]
		local defines, newdefines, deldefines = xcode6.fetchlocal(file, 'defines')
		local includedirs, newincludedirs, delincludedirs = xcode6.fetchlocal(file, 'includedirs')
		local disablewarnings, newdisablewarnings, deldisablewarnings = xcode6.fetchlocal(file, 'disablewarnings')
		local buildoptions, newbuildoptions, delbuildoptions = xcode6.fetchlocal(file, 'buildoptions')
		local warnings = xcode6.fetchlocal(file, 'warnings')
		local settings = xcode6.fetchlocal(file, 'xcode_filesettings')

		local compiler_flags = { }
		if newflags.FatalCompileWarnings then
			table.insert(compiler_flags, '-Werror')
		elseif delflags.FatalCompileWarnings then
			table.insert(compiler_flags, '-Wno-error')
		end

		if exceptionhandling ~= nil then
			table.insert(compiler_flags, exceptionhandling and '-fexceptions' or '-fno-exceptions')
		end
		if rtti ~= nil then
			table.insert(compiler_flags, rtti and '-frtti' or 'fno-rtti')
		end

		if optimize ~= nil then
			table.insert(compiler_flags, '-O' .. tostring(optimize))
		end

		if defines then
			for _, v in ipairs(deldefines) do
				table.insert(compiler_flags, '-U' .. v:match('[^=]+'))
			end
			for _, v in ipairs(newdefines) do
				table.insert(compiler_flags, '-D' .. v)
			end
		end

		if includedirs then
			-- no way to handle removed dirs
			for _, v in ipairs(newincludedirs) do
				table.insert(compiler_flags, '-I' .. xcode6.quoted(v))
			end
		end

		if disablewarnings then
			for _, v in ipairs(deldisablewarnings) do
				table.insert(compiler_flags, '-W' .. v)
			end
			for _, v in ipairs(newdisablewarnings) do
				table.insert(compiler_flags, '-Wno-' .. v)
			end
		end

		if buildoptions then
			-- no way to handle removed options
			for _, v in ipairs(newbuildoptions) do
				table.insert(compiler_flags, v)
			end
		end

		if warnings == 'Extra' then
			table.insert(compiler_flags, '-Wall')
		elseif warnings == 'Off' then
			table.insert(compiler_flags, '-w')
		elseif warnings == 'Default' then
			-- no way to handle this
		end

		if #compiler_flags > 0 then
			compiler_flags = { table.concat(compiler_flags, ' '), settings.COMPILER_FLAGS }
			settings.COMPILER_FLAGS = table.concat(compiler_flags, ' ')
		end
		return settings
	end