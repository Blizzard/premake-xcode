--
-- xcode6_tree.lua
-- Define the Apple XCode action and support functions.
-- Copyright (c) 2015 Blizzard Entertainment
--

	local p         = premake
	local api       = p.api
	local config    = p.config
	local context   = p.context
	local xcode6    = p.modules.xcode_blizzard
	local project   = p.project
	local workspace = p.workspace
	local tree      = p.tree

	local function removeUniqueTag(s)
		local i = string.find(s, "#")
		if i == nil then
			return s
		else
			return string.sub(s, 0, i-1)
		end
	end

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

	function xcode6.getSolutionTree(wks)
		if wks.xcodeNode then
			return wks.xcodeNode
		end
		return xcode6.buildSolutionTree(wks)
	end


	function xcode6.buildSolutionTree(wks)
		print('start buildSolutionTree')
		local pbxproject = {
			_id = xcode6.newid(wks.name, 'PBXProject'),
			_comment = 'Project object',
			_fileRefs = { }, -- contains only files used by multiple targets (e.g. libraries, not source files)
			isa = 'PBXProject',
			attributes = {
				BuildIndependentTargetsInParallel = 'YES',
				ORGANIZATIONNAME = 'Blizzard Entertainment'
			},
			buildConfigurationList = {
				_id = xcode6.newid(wks.name, 'XCConfigurationList'),
				_comment = string.format('Build configuration list for PBXProject "%s"', wks.name),
				isa = 'XCConfigurationList',
				buildConfigurations = { },
				defaultConfigurationIsVisible = 0,
				defaultConfigurationName = wks.configs[1].name
			},
			compatibilityVersion = 'Xcode 3.2',
			developmentRegion = 'English',
			hasScannedForEncodings = 0,
			knownRegions = {
				'Base'
			},
			mainGroup = {
				_id = xcode6.newid(wks.name, 'PBXGroup'),
				isa = 'PBXGroup',
				children = { },
				sourceTree = '<group>'
			},
			targets = { },
		}
		wks.xcodeNode = pbxproject

		local targetsGroup = {
			_id = xcode6.newid(wks.name, 'Targets', 'PBXGroup'),
			_comment = 'Targets',
			isa = 'PBXGroup',
			children = { },
			name = 'Targets',
			sourceTree = '<group>'
		}
		local frameworksGroup = {
			_id = xcode6.newid(wks.name, 'Frameworks', 'PBXGroup'),
			_comment = 'Frameworks',
			isa = 'PBXGroup',
			children = { },
			name = 'Frameworks',
			sourceTree = '<group>'
		}
		local librariesGroup = {
			_id = xcode6.newid(wks.name, 'Libraries', 'PBXGroup'),
			_comment = 'Libraries',
			isa = 'PBXGroup',
			children = { },
			name = 'Libraries',
			sourceTree = '<group>'
		}
		local productsGroup = {
			_id = xcode6.newid(wks.name, 'Products', 'PBXGroup'),
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

		for cfg in workspace.eachconfig(wks) do
			table.insert(pbxproject.buildConfigurationList.buildConfigurations, {
				_id = xcode6.newid(cfg.name, wks.name, 'XCBuildConfiguration'),
				_comment = cfg.name,
				isa = 'XCBuildConfiguration',
				buildSettings = xcode6.buildSettings(cfg),
				name = cfg.name
			})
		end

		local groups = { }
		for prj in workspace.eachproject(wks) do
			local parentName = prj.group
			local parent = iif(parentName and #parentName ~= 0, groups[parentName], targetsGroup)
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
		for prj in workspace.eachproject(wks) do
			table.foreachi(project.getdependencies(prj), function(dep)
				local depNode = dep.xcodeNode
				table.insert(prj.xcodeNode.dependencies, {
					_id = xcode6.newid(prj.name, dep.name, 'PBXTargetDependency'),
					_comment = 'PBXTargetDependency',
					isa = 'PBXTargetDependency',
					target = depNode,
					targetProxy = {
						_id = xcode6.newid(dep.workspace.name, dep.name, 'PBXContainerItemProxy'),
						_comment = 'PBXContainerItemProxy',
						isa = 'PBXContainerItemProxy',
						containerPortal = dep.workspace.xcodeNode,
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

		local wks = prj.workspace
		local prjName = prj.name
		local wksName = wks.name
		local parentGroup = {
			_id = xcode6.newid(prjName, wks.xcodeNode.mainGroup._id, 'PBXGroup'),
			_comment = prjName,
			isa = 'PBXGroup',
			children = { },
			name = prjName,
			sourceTree = '<group>'
		}

		local productName = prj.targetname or prjName
		if prj.kind == 'Utility' or prj.kind == 'None' then
			pbxtarget = {
				_id = xcode6.newid(prjName, wksName, 'PBXAggregateTarget'),
				isa = 'PBXAggregateTarget',
			}
		else
			local productPath = xcode6.getTargetName(prj, project.getfirstconfig(prj))
			pbxtarget = {
				_id = xcode6.newid(prjName, wksName, 'PBXNativeTarget'),
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
			_id = xcode6.newid(prjName, wksName, 'XCConfigurationList'),
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
				_id = xcode6.newid(cfg.name, wksName, prjName, 'XCBuildConfiguration'),
				_comment = cfg.name,
				isa = 'XCBuildConfiguration',
				buildSettings = xcode6.buildSettings(cfg),
				name = cfg.name,
			})
		end

		local cmdCount = 0
		if prj.prebuildcommands then
			table.foreachi(prj.prebuildcommands, function(cmd)
				table.insert(pbxtarget.buildPhases, {
					_id = xcode6.newid(tostring(cmdCount), cmd, prjName, wksName, 'PBXShellScriptBuildPhase'),
					_comment = 'Run Script',
					isa = 'PBXShellScriptBuildPhase',
					buildActionMask = 2147483647,
					files = { },
					inputPaths = { },
					name = 'Run Script',
					outputPaths = { },
					runOnlyForDeploymentPostprocessing = 0,
					shellPath = '/bin/sh',
					shellScript = xcode6.resolveShellScript(wks, prj, cmd)
				})
				cmdCount = cmdCount + 1
			end)
		end

		-- add build rules.
		for i = 1, #prj.rules do
			local rule = premake.global.getRule(prj.rules[i])

			-- create shadow contexts.
			local outputsContext = xcode6.buildOutputsEnvironment(rule)
			local cmdContext = xcode6.buildCommandsEnvironment(rule)

			-- create table entry.
			local cmd = table.concat(cmdContext.buildcommands, '\n')

			table.insert(pbxtarget.buildRules, {
				_id = xcode6.newid(rule.name, wks.name, 'PBXBuildRule'),
				_comment      = 'PBXBuildRule',
				isa           = 'PBXBuildRule',
				compilerSpec  = 'com.apple.compilers.proxy.script',
				filePatterns  = '*' .. table.concat(rule.fileextension, ';*'),
				fileType      = 'pattern.proxy',
				isEditable    = 1;
				outputFiles   = outputsContext.buildoutputs,
				script        = xcode6.resolveShellScript(wks, prj, cmd)
			})
		end

		files = tree.new()
		vfiles = tree.new()
		table.foreachi(prj._.files, function(file)
			local path = file.abspath
			local vpath = project.getvpath(prj, path)
			local isvpath = vpath ~= path
			local uniquifier = ""
			if isvpath then
				uniquifier = "#" .. path:sha1()
			end
			local node = tree.add(isvpath and vfiles or files, workspace.getrelative(wks, vpath .. uniquifier), { kind = 'group', isvpath = isvpath })
			node.relativepath = workspace.getrelative(wks, path)
			node.kind = 'file'
			node.file = file
			node.exclude = file.flags and file.flags.ExcludeFromBuild
			if path ~= prj.icon then -- icons handled elsewhere
				local category = xcode6.getBuildCategory(isvpath and removeUniqueTag(node.name) or node.name)
				node.category = category
				node.action = category == 'Sources' and 'build' or
					category == 'Resources' and 'copy' or nil
			end
		end)
		table.foreachi(prj.xcode_resources, function(file)
			local vpath = project.getvpath(prj, file)
			local isvpath = vpath ~= file
			file = workspace.getrelative(wks, file)
			local uniquifier = ""
			if isvpath then
				uniquifier = "#" .. file:sha1()
			end
			local lproj = file:match('^.*%.lproj%f[/]')
			if lproj then
				local parentPath = path.getdirectory(isvpath and vpath or lproj)
				local resPath = path.getrelative(lproj, file)
				local filePath = path.join(path.getname(lproj), resPath)
				local parentNode = tree.add(isvpath and vfiles or files, parentPath, { kind = 'group', isvpath = isvpath })
  				local fspath = path.join(parentPath, resPath)
  				local uniquifier = ""
  				if isvpath then
  					uniquifier = "#" .. fspath:sha1()
  				end
  				local uniquerespath = resPath .. uniquifier
				local variantGroup = parentNode.children[uniquerespath]
				if not variantGroup then
					variantGroup = tree.new(uniquerespath)
					variantGroup.isvpath = isvpath
					variantGroup.relativepath = path.getdirectory(lproj)
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
				local node = tree.add(isvpath and vfiles or files, workspace.getrelative(wks, vpath .. uniquifier), { kind = 'group', isvpath = isvpath })
				node.relativepath = file
				node.kind = 'file'
				node.action = 'copy'
				node.category = 'Resources'
			end
		end)
		local setvpaths = function(node)
			local parentPath = node.parent.vpath
			if node.kind == 'variantGroup' then
				node.vpath = parentPath
			else
				local localPath = tree.getlocalpath(node)
				node.vpath = parentPath and
					path.join(parentPath, localPath) or
					localPath
			end
		end
		tree.traverse(files, { onnode = setvpaths })
		tree.traverse(vfiles, { onnode = setvpaths })
		tree.trimroot(files)
		for i, v in ipairs(vfiles.children) do
			tree.insert(files, v)
		end

		local sourcesPhase = {
			_id = xcode6.newid('Sources', prjName, wksName, 'PBXSourcesBuildPhase'),
			_comment = 'Sources',
			isa = 'PBXSourcesBuildPhase',
			buildActionMask = 2147483647,
			files = { },
			runOnlyForDeploymentPostprocessing = 0
		}
		local copyPhase = {
			_id = xcode6.newid('Resources', prjName, wksName, 'PBXResourcesBuildPhase'),
			_comment = 'Resources',
			isa = 'PBXResourcesBuildPhase',
			buildActionMask = 2147483647,
			files = { },
			runOnlyForDeploymentPostprocessing = 0
		}

		table.foreachi(prj._.files, function(fcfg)
			if fcfg.buildcommands and #fcfg.buildcommands > 0 then
				local cmd = table.concat(fcfg.buildcommands, '\n')
				local inputPath = workspace.getrelative(wks, fcfg.abspath)
				table.insert(pbxtarget.buildPhases, {
					_id = xcode6.newid(cmd, inputPath, prjName, wksName, 'PBXShellScriptBuildPhase'),
					_comment = 'Process ' .. fcfg.name,
					isa = 'PBXShellScriptBuildPhase',
					buildActionMask = 2147483647,
					files = { },
					inputPaths = table.join({ inputPath }, workspace.getrelative(wks, fcfg.buildinputs)),
					name = 'Process ' .. fcfg.name,
					outputPaths = workspace.getrelative(wks, fcfg.buildoutputs),
					runOnlyForDeploymentPostprocessing = 0,
					shellPath = '/bin/sh',
					shellScript = xcode6.resolveShellScript(wks, prj, cmd)
				})
			end
		end)

		files.xcodeNode = parentGroup
		tree.traverse(files, {
			onleaf = function(node)
				local nodePath = tree.getlocalpath(node)
				local ref = {
					_id = xcode6.newid(node.vpath, prjName, wksName, 'PBXFileReference'),
					_formatStyle = 'compact',
					isa = 'PBXFileReference',
					path = node.parent.vpath and nodePath or node.vpath,
					sourceTree = '<group>',
				}

				if node.isvpath then
					ref.path = removeUniqueTag(node.relativepath)
				end

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
					if node.isvpath then
						nodeName = removeUniqueTag(nodeName)
					end
					ref.name = nodeName ~= ref.path and nodeName or nil
					ref._comment = nodeName
					local fileType = xcode6.fetchlocal(node.file, "xcode_filetype")
					if (fileType) then
						ref.explicitFileType = fileType
					end
					table.insertsorted(parentGroup.children, ref, groupsorter)
					if node.action and not node.exclude then
						local buildFile = {
								_id = xcode6.newid(node.vpath, prjName, wksName, 'PBXBuildFile'),
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
				local nodePath = tree.getlocalpath(node)
				local nodeName = path.getname(nodePath)
				if node.isvpath then
					nodeName = removeUniqueTag(nodeName)
				end
				local variantPath = node.kind == 'variantGroup' and path.join(node.vpath, nodeName) or nil
				local grp = variantPath and {
					_id = xcode6.newid(path.join(node.vpath, nodeName), prjName, wksName, 'PBXVariantGroup'),
					_comment = nodeName,
					isa = 'PBXVariantGroup',
					children = { },
					sourceTree = '<group>'
				} or {
					_id = xcode6.newid(node.vpath, prjName, wksName, 'PBXGroup'),
					_comment = nodeName,
					isa = 'PBXGroup',
					children = { },
					path = node.parent.vpath and nodePath or node.vpath,
					sourceTree = '<group>'
				}

				if node.isvpath then
					grp.path = nil
					if node.kind ~= 'group' then
						grp.path = removeUniqueTag(node.relativepath)
					end
				end


				grp.name = nodeName ~= grp.path and nodeName or nil
				table.insertsorted(parentGroup.children, grp, groupsorter)
				node.xcodeNode = grp
				parentGroup = grp

				if node.action and not node.exclude then
					local buildFile = {
						_id = xcode6.newid(variantPath or node.vpath, prjName, wksName, 'PBXBuildFile'),
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

		if prj.prelinkcommands then
			table.foreachi(prj.prelinkcommands, function(cmd)
				table.insert(pbxtarget.buildPhases, {
					_id = xcode6.newid(cmdCount, cmd, prjName, wksName, 'PBXShellScriptBuildPhase'),
					_comment = 'Run Script',
					isa = 'PBXShellScriptBuildPhase',
					buildActionMask = 2147483647,
					files = { },
					inputPaths = { },
					name = 'Run Script',
					outputPaths = { },
					runOnlyForDeploymentPostprocessing = 0,
					shellPath = '/bin/sh',
					shellScript = xcode6.resolveShellScript(wks, prj, cmd)
				})
				cmdCount = cmdCount + 1
			end)
		end

		if prj.kind == 'ConsoleApp' or prj.kind == 'WindowedApp' or prj.kind == 'SharedLib' then
			local frameworksPhase = {
				_id = xcode6.newid('Frameworks', prjName, wksName, 'PBXFrameworksBuildPhase'),
				_comment = 'Frameworks',
				isa = 'PBXFrameworksBuildPhase',
				buildActionMask = 2147483647,
				files = { },
				runOnlyForDeploymentPostprocessing = 0
			}
			table.foreachi(prj.links, function(link)
				local sibling = wks.projects[link]
				local buildFileRef
				if sibling then
					local siblingNode = xcode6.buildProjectTree(sibling, productsGroup)
					if siblingNode.productReference then
						buildFileRef = {
							_id = xcode6.newid(siblingNode.productReference.path, link, prjName, wksName, 'PBXBuildFile'),
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
						workspace.getrelative(wks, link)
					local fileName = path.getname(filePath)

					local wksNode = wks.xcodeNode
					local fileRef = wksNode._fileRefs[filePath]
					if not fileRef then
						fileRef = {
							_id = xcode6.newid(filePath, wksName, 'PBXFileReference'),
							_comment = fileName,
							_formatStyle = 'compact',
							isa = 'PBXFileReference',
							name = fileName,
							path = filePath,
							sourceTree = isSystem and 'SDKROOT' or '<group>'
						}

						local group = isFramework and wksNode._frameworksGroup or wksNode._librariesGroup
						table.insertsorted(group.children, fileRef, groupsorter)
						wksNode._fileRefs[filePath] = fileRef
					end

					buildFileRef = {
						_id = xcode6.newid(filePath, link, prjName, wksName, 'PBXBuildFile'),
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
					_id = xcode6.newid(cmdCount, cmd, prjName, wksName, 'PBXShellScriptBuildPhase'),
					_comment = 'Run Script',
					isa = 'PBXShellScriptBuildPhase',
					buildActionMask = 2147483647,
					files = { },
					inputPaths = { },
					name = 'Run Script',
					outputPaths = { },
					runOnlyForDeploymentPostprocessing = 0,
					shellPath = '/bin/sh',
					shellScript = xcode6.resolveShellScript(wks, prj, cmd)
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
		local wks = cfg.workspace
		local prj = cfg.project
		local settings = { }

		local booleanMap = { On = true, Off = false }
		local optimizeMap = { Off = 0, Debug = 1, On = 2, Speed = 'fast', Size = 's', Full = 3 }
		local symbolsMap = { Default = nil, On = true, Off = false, FastLink = true, Full = true }


		local flags, newflags, delflags = xcode6.fetchlocal(cfg, 'flags')
		local exceptionhandling = booleanMap[xcode6.fetchlocal(cfg, 'exceptionhandling')]
		local cdialect = xcode6.fetchlocal(cfg, 'cdialect')
		local cppdialect = xcode6.fetchlocal(cfg, 'cppdialect')
		local rtti = booleanMap[xcode6.fetchlocal(cfg, 'rtti')]
		local editandcontinue = booleanMap[xcode6.fetchlocal(cfg, 'editandcontinue')]
		local optimize = optimizeMap[xcode6.fetchlocal(cfg, 'optimize')]
		local pchsource = xcode6.fetchlocal(cfg, 'pchsource')
		local pchheader = xcode6.fetchlocal(cfg, 'pchheader')
		local defines, newdefines, deldefines = xcode6.fetchlocal(cfg, 'defines')
		local architecture = xcode6.fetchlocal(cfg, 'architecture')
		local includedirs, newincludedirs, delincludedirs = xcode6.fetchlocal(cfg, 'includedirs')
		local libdirs, newlibdirs, dellibdirs = xcode6.fetchlocal(cfg, 'libdirs')
		local bindirs = xcode6.fetchlocal(cfg, 'bindirs')
		local runpathdirs, newrunpathdirs, delrunpathdirs = xcode6.fetchlocal(cfg, 'xcode_runpathdirs')
		local targetprefix = xcode6.fetchlocal(cfg, 'targetprefix')
		local disablewarnings, newdisablewarnings, deldisablewarnings = xcode6.fetchlocal(cfg, 'disablewarnings')
		local buildoptions, newbuildoptions, delbuildoptions = xcode6.fetchlocal(cfg, 'buildoptions')
		local linkoptions, newlinkoptions, dellinkoptions = xcode6.fetchlocal(cfg, 'linkoptions')
		local warnings = xcode6.fetchlocal(cfg, 'warnings')
		local symbols = symbolsMap[xcode6.fetchlocal(cfg, 'symbols')]
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

		-- deal with cdialect.
		if cdialect ~= nil then
			local c_langmap = {
				["C89"]     = "c89",
				["C90"]     = "c99",   -- no c90 support
				["C99"]     = "c99",
				["C11"]     = "c11",
				["gnu89"]   = "gnu89",
				["gnu90"]   = "gnu99", -- no c90 support
				["gnu99"]   = "gnu99",
				["gnu11"]   = "gnu11",
			}
			settings.GCC_C_LANGUAGE_STANDARD = c_langmap[cdialect]
		end

		-- deal with cppdialect.
		if cppdialect ~= nil then
			local cpp_langmap = {
				["C++98"]   = "c++98",
				["C++11"]   = "c++11",
				["C++14"]   = "c++14",
				["C++17"]   = "c++1z",
				["gnu++98"] = "gnu++98",
				["gnu++11"] = "gnu++11",
				["gnu++14"] = "gnu++14",
				["gnu++17"] = "gnu++1z",
			}
			local cpp_libmap = {
				["C++98"]   = "libstdc++",
				["C++11"]   = "libc++",
				["C++14"]   = "libc++",
				["C++17"]   = "libc++",
				["gnu++98"] = "libstdc++",
				["gnu++11"] = "libc++",
				["gnu++14"] = "libc++",
				["gnu++17"] = "libc++",
			}
			settings.CLANG_CXX_LANGUAGE_STANDARD = cpp_langmap[cppdialect]
			settings.CLANG_CXX_LIBRARY           = cpp_libmap[cppdialect]
		end

		--
		if symbols ~= nil then
			settings.GCC_ENABLE_FIX_AND_CONTINUE = symbols and editandcontinue
			settings.LD_GENERATE_MAP_FILE = symbols
		end

		settings.GCC_ENABLE_CPP_EXCEPTIONS  = exceptionhandling
		settings.GCC_ENABLE_OBJC_EXCEPTIONS = exceptionhandling
		settings.GCC_ENABLE_CPP_RTTI        = rtti

		settings.GCC_OPTIMIZATION_LEVEL = optimize

		if pchheader and not (flags and flags.NoPCH) then
			settings.GCC_PRECOMPILE_PREFIX_HEADER = true
			settings.GCC_PREFIX_HEADER = workspace.getrelative(wks, path.join(prj.basedir, pchsource or pchheader))
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
				settings.HEADER_SEARCH_PATHS = workspace.getrelative(wks, includedirs)
			elseif #newincludedirs > 0 then
				settings.HEADER_SEARCH_PATHS = table.join('$(inherited)', workspace.getrelative(wks, newincludedirs))
			end
		end

		-- get libdirs and links
		if libdirs then
			newlibdirs = workspace.getrelative(wks, newlibdirs)
			dellibdirs = workspace.getrelative(wks, dellibdirs)
			if #dellibdirs == 0 then
				libdirs = newlibdirs
			end
			if prj then
				libdirs = table.join(table.translate(config.getlinks(cfg, 'siblings', 'directory', nil), function(s)
					return path.rebase(s, prj.location, wks.location)
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
			settings.OBJROOT					= workspace.getrelative(wks, cfg.objdir)
			settings.CONFIGURATION_BUILD_DIR	= workspace.getrelative(wks, cfg.buildtarget.directory)
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
		if warnings == 'Extra' or warnings == 'High' then
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

		local ldflags = table.join(checkflags, linkoptions)
		if cfg ~= prj and cfg ~= wks then
			local newlinks = table.arraycopy(cfg.links)
			local parent = prj or wks
			for _,link in ipairs(parent.links) do
				table.remove(newlinks, table.indexof(newlinks, link))
			end
			for _,link in ipairs(newlinks) do
				if not wks.projects[link] then
					table.insert(ldflags, workspace.getrelative(wks, link))
				end
			end
		end

		local cflags = table.join(checkflags, buildoptions)
		if inheritcflags then
			cflags = #cflags > 0 and table.join('$(inherited)', cflags) or nil
		end
		if inheritldflags then
			ldflags = #ldflags > 0 and table.join('$(inherited)', ldflags) or nil
		end
		settings.WARNING_CFLAGS = warn
		settings.OTHER_CFLAGS = cflags
		settings.OTHER_LDFLAGS = ldflags

		if bindirs then
			settings.EXECUTABLE_PATHS = table.concat(workspace.getrelative(wks, bindirs), ':')
		end

		-- add rule properties.
		for i = 1, #cfg.rules do
			local rule = premake.global.getRule(cfg.rules[i])

			for prop in premake.rule.eachProperty(rule) do
				local fld = premake.rule.getPropertyField(rule, prop)
				local value = cfg[fld.name]
				if value ~= nil then
					if fld.kind == "path" then
						value = xcode6.path(wks, '$(SRCROOT)', value)
					elseif fld.kind == "list:path" then
						value = xcode6.path(wks, '$(SRCROOT)', value)
					end

					settings[prop.name] = premake.rule.expandString(rule, prop, value)
				end
			end
		end

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
			table.insert(compiler_flags, rtti and '-frtti' or '-fno-rtti')
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

		if warnings == 'Extra' or warnings == 'High' then
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
