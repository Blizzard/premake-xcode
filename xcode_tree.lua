--
-- xcode6_tree.lua
-- Define the Apple XCode action and support functions.
-- Copyright (c) 2015 Blizzard Entertainment
--

	local api      = premake.api
	local config   = premake.config
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
		local pbxnativetarget = prj.xcodeNode
		if pbxnativetarget then
			return pbxnativetarget
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
		local productPath = xcode6.getTargetName(prj, project.getfirstconfig(prj))
		pbxnativetarget = {
			_id = xcode6.newid(prjName, slnName, 'PBXNativeTarget'),
			_comment = prjName,
			_group = parentGroup,
			_project = prj,
			isa = 'PBXNativeTarget',
			buildConfigurationList = {
				_id = xcode6.newid(prjName, slnName, 'XCConfigurationList'),
				_comment = string.format('Build configuration list for PBXNativeTarget "%s"', prjName),
				isa = 'XCConfigurationList',
				buildConfigurations = { },
				defaultConfigurationIsVisible = 0,
				defaultConfigurationName = project.getfirstconfig(prj).name
			},
			buildPhases = { },
			buildRules = { },
			dependencies = { },
			name = prjName,
			productName = productName,
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
		prj.xcodeNode = pbxnativetarget

		for cfg in project.eachconfig(prj) do
			table.insert(pbxnativetarget.buildConfigurationList.buildConfigurations, {
				_id = xcode6.newid(cfg.name, slnName, prjName, 'XCBuildConfiguration'),
				_comment = cfg.name,
				isa = 'XCBuildConfiguration',
				buildSettings = xcode6.buildSettings(cfg),
				name = cfg.name
			})
		end

		table.insertsorted(productsGroup.children, pbxnativetarget.productReference, function(a, b)
			return string.lower(path.getname(a.path)) < string.lower(path.getname(b.path))
		end)

		local cmdCount = 0
		if prj.prebuildcommands then
			table.foreachi(prj.prebuildcommands, function(cmd)
				table.insert(pbxnativetarget.buildPhases, {
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
		table.foreachi(prj.files, function(file)
			local node = tree.add(files, solution.getrelative(sln, file), { kind = 'group' })
			node.kind = 'file'
			if file ~= prj.icon then -- icons handled elsewhere
				local settings = prj._.files[file].xcode_filesettings
				node.settings = next(settings) and settings
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
					if node.action then
						local buildFile = {
								_id = xcode6.newid(node.filepath, prjName, slnName, 'PBXBuildFile'),
								_comment = string.format('%s in %s', nodeName, node.category),
								_formatStyle = 'compact',
								isa = 'PBXBuildFile',
								fileRef = ref,
								settings = node.settings
							}
						if node.action == 'build' then
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

				if node.action then
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
			table.insert(pbxnativetarget.buildPhases, sourcesPhase)
		end

		table.foreachi(prj._.files, function(fcfg)
			if fcfg.buildcommands and #fcfg.buildcommands > 0 then
				local cmd = table.concat(fcfg.buildcommands, '\n')
				table.insert(pbxnativetarget.buildPhases, {
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
				table.insert(pbxnativetarget.buildPhases, {
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
					buildFileRef = {
						_id = xcode6.newid(siblingNode.productReference.path, link, prjName, slnName, 'PBXBuildFile'),
						_comment = path.getname(siblingNode.productReference.path) .. ' in Frameworks',
						_formatStyle = 'compact',
						isa = 'PBXBuildFile',
						fileRef = siblingNode.productReference
					}
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

			table.insert(pbxnativetarget.buildPhases, frameworksPhase)
		end

		if #copyPhase.files > 0 then
			table.insert(pbxnativetarget.buildPhases, copyPhase)
		end

		if prj.postbuildcommands then
			table.foreachi(prj.postbuildcommands, function(cmd)
				table.insert(pbxnativetarget.buildPhases, {
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

		return pbxnativetarget
	end

	function xcode6.buildSettings(cfg)
		local sln = cfg.solution
		local prj = cfg.project
		local settings = { }

		if cfg.flags['C++14'] then
			settings['CLANG_CXX_LANGUAGE_STANDARD'] = 'c++14'
			settings['CLANG_CXX_LIBRARY'] = 'libc++'
		elseif cfg.flags['C++11'] then
			settings['CLANG_CXX_LANGUAGE_STANDARD'] = 'c++0x'
			settings['CLANG_CXX_LIBRARY'] = 'libc++'
		end

		local booleanMap = { On = 'YES', Off = 'NO' }
		settings['GCC_ENABLE_CPP_EXCEPTIONS']  = booleanMap[cfg.exceptionhandling] or nil
		settings['GCC_ENABLE_OBJC_EXCEPTIONS'] = booleanMap[cfg.exceptionhandling] or nil
		settings['GCC_ENABLE_CPP_RTTI']        = booleanMap[cfg.rtti] or nil

		if cfg.flags.Symbols then
			settings['GCC_ENABLE_FIX_AND_CONTINUE'] = booleanMap[cfg.editandcontinue] or nil
		end

		local optimizeMap = { Off = 0, Debug = 1, On = 2, Speed = 3, Size = 's', Full = 'fast' }
		settings['GCC_OPTIMIZATION_LEVEL'] = optimizeMap[cfg.optimize] or nil

		if cfg.pchheader and not cfg.flags.NoPCH then
			settings['GCC_PRECOMPILE_PREFIX_HEADER'] = 'YES'
			settings['GCC_PREFIX_HEADER'] = solution.getrelative(sln, path.join(prj.basedir, cfg.pchsource or cfg.pchheader))
		end

		if cfg.defines and #cfg.defines > 0 then
			settings['GCC_PREPROCESSOR_DEFINITIONS'] = table.join('$(inherited)', premake.esc(cfg.defines))
		end

		if cfg.flags.FatalWarnings then
			settings['GCC_TREAT_WARNINGS_AS_ERRORS'] = 'YES'
		end

		settings['GCC_WARN_ABOUT_RETURN_TYPE'] = 'YES'
		settings['GCC_WARN_UNUSED_VARIABLE'] = 'YES'

		if cfg.architecture == 'x86' then
			settings['ARCHS'] = '$(ARCHS_STANDARD_32_BIT)'
		elseif cfg.architecture == 'x86_64' then
			settings['ARCHS'] = '$(ARCHS_STANDARD_64_BIT)'
		elseif cfg.architecture == 'universal' then
			settings['ARCHS'] = '$(ARCHS_STANDARD_32_64_BIT)'
		end

		settings['SDKROOT'] = 'macosx'

		if #cfg.includedirs > 0 then
			settings['HEADER_SEARCH_PATHS']		 = table.join('$(inherited)', solution.getrelative(sln, cfg.includedirs))
		end

		-- get libdirs and links
		local libdirs = solution.getrelative(sln, cfg.libdirs)
		if prj then
			libdirs = table.join(table.translate(config.getlinks(cfg, 'siblings', 'directory', nil), function(s)
				return path.rebase(s, prj.location, sln.location)
			end), libdirs)
		end
		if #libdirs > 0 then
			settings['LIBRARY_SEARCH_PATHS'] = table.unique(table.join('$(inherited)', libdirs))
		end

		local fwdirs = xcode6.getFrameworkDirs(cfg)
		if fwdirs and #fwdirs > 0 then
			settings['FRAMEWORK_SEARCH_PATHS']	 = table.join('$(inherited)', fwdirs)
		end

		if cfg.xcode_runpathdirs and #cfg.xcode_runpathdirs > 0 then
			settings['LD_RUNPATH_SEARCH_PATHS'] = cfg.xcode_runpathdirs
		end

		if prj then
			settings['OBJROOT']					 = solution.getrelative(sln, cfg.objdir)
			settings['CONFIGURATION_BUILD_DIR']	 = solution.getrelative(sln, cfg.buildtarget.directory)
			settings['PRODUCT_NAME']			 = cfg.buildtarget.basename
		else
			settings['USE_HEADERMAP']			 = 'NO'
		end

		settings['EXECUTABLE_PREFIX'] = cfg.targetprefix

		-- build list of "other" C/C++ flags
		local checks = {
			["-ffast-math"]			 = cfg.flags.FloatFast,
			["-ffloat-store"]		 = cfg.flags.FloatStrict,
			["-fomit-frame-pointer"] = cfg.flags.NoFramePointer,
		}

		local flags = { }
		for flag, check in pairs(checks) do
			if check then
				table.insert(flags, flag)
			end
		end

		local nowarn = table.translate(cfg.disablewarnings or { }, function(warning)
			return '-Wno-' .. warning
		end)
		settings['OTHER_CFLAGS'] = table.join(flags, cfg.buildoptions, nowarn)
		settings['OTHER_LDFLAGS'] = table.join(flags, cfg.linkoptions)

		if cfg.warnings == "Extra" then
			settings['WARNING_CFLAGS'] = '-Wall'
		elseif cfg.warnings == "Off" then
			settings['GCC_WARN_INHIBIT_ALL_WARNINGS'] = 'YES'
		end

		if cfg.xcode_settings then
			settings = table.merge(settings, cfg.xcode_settings)
		end

		return settings
	end
