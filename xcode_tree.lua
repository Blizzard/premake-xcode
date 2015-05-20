--
-- xcode6_tree.lua
-- Define the Apple XCode action and support functions.
-- Copyright (c) 2015 Blizzard Entertainment
--

	local api      = premake.api
	local xcode6   = premake.xcode6
	local project  = premake.project
	local solution = premake.solution
	local tree     = premake.tree


	function xcode6.getSolutionTree(sln, sorter)
		if sln.xcodeNode then
			return sln.xcodeNode
		end
		return xcode6.buildSolutionTree(sln, sorter)
	end


	function xcode6.setProductGroupId(node)
		if not node.productGroupId then
			local id = node.name
			if node.parent then
				id = id .. xcode6.setProductGroupId(node.parent)
			end

			node.productGroupId = xcode6.newid(id, 'group', 'PBXGroup')
		end

		return node.productGroupId
	end


	function xcode6.buildSolutionTree(sln, sorter)
		print('start buildSolutionTree')

		local slnT = tree.new(sln.name)
		slnT.kind           = 'solution'
		slnT.solution       = sln
		slnT.id             = xcode6.newid(sln.name, 'PBXProject')
		slnT.productGroupId = xcode6.newid(sln.name, 'solution', 'PBXGroup')
		sln.xcodeNode = slnT

		local frameworks = tree.new("Frameworks")
		frameworks.kind           = 'frameworks'
		frameworks.productGroupId = xcode6.newid('Frameworks', 'PBXGroup')

		local libraries = tree.new("Libraries")
		libraries.kind           = 'libraries'
		libraries.productGroupId = xcode6.newid('Libraries', 'PBXGroup')

		local products = tree.new("Products")
		products.kind           = 'products'
		products.productGroupId = xcode6.newid('Products', 'PBXGroup')

		for prj in solution.eachproject(sln) do
			-- create product node.
			local productT = tree.insert(products, tree.new(prj.name))
			productT.kind           = 'product'
			productT.id             = xcode6.newid(prj.name, 'PBXFileReference')
			productT.project        = prj
			productT.name           = xcode6.getTargetName(prj, project.getfirstconfig(prj))
			productT.productType    = xcode6.getProductType(prj)
			productT.targetType     = xcode6.getTargetType(prj)
			productT.buildCategory  = xcode6.getBuildCategory(productT.name)

			if productT.buildCategory then
				productT.buildId = xcode6.newid(productT.name, "PBXBuildFile", productT.buildCategory)
			end

			-- create project node.
			--- first, save and remove special items
			local specials = { }
			for n = #prj._.files, 1, -1 do
			    local fcfg = prj._.files[n]
                if fcfg.vpath ~= fcfg.relpath then
                    table.insert(specials, fcfg)
                    table.remove(prj._.files, n)
                end
			end

            --- next, construct the source tree as usual
			local prjT = project.getsourcetree(prj)

			--- re-insert the specials
			prj._.files = table.join(specials, prj._.files)
			table.foreachi(specials, function(fcfg)
                local node = tree.add(prjT, fcfg.vpath)
                setmetatable(node, { __index = fcfg })
			end)

			local group = tree.add(slnT, path.join('Targets', prj.group), { kind = 'group' } )
			xcode6.setProductGroupId(group)
			tree.insert(group, prjT)

			prjT.kind                   = 'project'
			prjT.project                = prj
			prjT.solution               = sln
			prjT.targetId               = xcode6.newid(prj.name, 'PBXNativeTarget')
			prjT.containerItemProxyId   = xcode6.newid(prj.name, 'PBXContainerItemProxy')
			prjT.targetDependencyId     = xcode6.newid(prj.name, 'PBXTargetDependency')
			prjT.sourcesBuildPhaseId    = xcode6.newid(prj.name, 'PBXSourcesBuildPhase')
			prjT.productGroupId         = xcode6.newid(prj.name, 'project', 'PBXGroup')
			prjT.resBuildPhaseId		= xcode6.newid(prj.name, 'PBXResourceBuildPhase')
			prjT.dependencies           = project.getdependencies(prj)
			prjT.linkdeps               = project.getdependencies(prj, 'linkOnly')
			prjT.frameworks             = {}
			prjT.product                = productT
			prjT.prebuild               = {}
			prjT.prelink                = {}
			prjT.postbuild              = {}
			prj.xcodeNode               = prjT

			if #prj.links > 0 then
			    prjT.frameworkBuildPhaseId = xcode6.newid(prj.name, 'PBXFrameworksBuildPhase')
			end

            -- configure custom commands
            table.foreachi(prj.prebuildcommands, function(cmd)
                table.insert(prjT.prebuild, {
                    id = xcode6.newid(tostring(prj.prebuildcommands), cmd),
                    cmd = os.translateCommands(cmd)
                })
            end)

            table.foreachi(prj.prelinkcommands, function(cmd)
                table.insert(prjT.prelink, {
                    id = xcode6.newid(tostring(prj.prelinkcommands), cmd),
                    cmd = os.translateCommands(cmd)
                })
            end)

            table.foreachi(prj.postbuildcommands, function(cmd)
                table.insert(prjT.postbuild, {
                    id = xcode6.newid(tostring(prj.postbuildcommands), cmd),
                    cmd = os.translateCommands(cmd)
                })
            end)

			-- configure file settings.
			table.foreachi(prj._.files, function(fcfg)
				fcfg.fileConfig     = fcfg -- allows getting fcfg from fcfgT
				fcfg.solution       = sln
				fcfg.relpath        = path.getrelative(sln.location, fcfg.abspath)
				fcfg.id             = xcode6.newid(prj.name, fcfg.abspath, "PBXFileReference")
				fcfg.fileType       = xcode6.getFileType(fcfg.abspath)
				fcfg.isResource     = xcode6.isItemResource(prj, fcfg)
				fcfg.buildCategory  = xcode6.getBuildCategory(fcfg.abspath)

				if fcfg.buildCategory then
					fcfg.buildId = xcode6.newid(fcfg.abspath, "PBXBuildFile", fcfg.buildCategory, prj.name)
				end
			end)

			tree.traverse(prjT, {
			    onbranch = function(node)
			        node.kind = 'group'
				    xcode6.setProductGroupId(node)
			    end,
			    onleaf = function(node)
                    node.kind = 'fileConfig'

                    if string.endswith(node.abspath, "Info.plist") then
                        prjT.infoplist = node
                    end

                    node.fileConfig.xcodeNode = node
			    end
		    })

			-- add localized and non-localized resources
			prj.resourceIds = { }
			local resT = tree.new("Resources")
			table.foreachi(prj.xcode_resources, function(res)
				local respath, lproj, loc, item = res:match('^(.*)/(([%w_%-]+)%.lproj)/(.*)$')
				respath = solution.getrelative(sln, respath or res)
				if lproj then
					local key = path.join(respath, item)
					local parent = tree.add(resT, key, { kind = 'group' })
					if not parent.id then
						xcode6.setProductGroupId(parent)
						parent.relpath = key
						parent.kind = 'variant'
						parent.id = xcode6.newid(key, 'PBXVariantGroup')
						parent.buildId = xcode6.newid(key, 'PBXBuildFile')
						parent.buildCategory = xcode6.getBuildCategory(key)
						table.insert(prj.resourceIds, { id = parent.buildId, name = item })
					end

					local node = tree.add(parent, loc)
					node.relpath = path.join(lproj, item)
					node.kind = 'fileConfig'
					node.id = xcode6.newid(path.join(respath, lproj, item, 'PBXFileReference'))
					node.fileType = xcode6.getFileType(item)
				else
					local parent = tree.add(resT, path.getdirectory(respath), { kind = 'group' })
					xcode6.setProductGroupId(parent)
					local node = tree.add(parent, path.getname(respath))
					node.relpath = respath
					node.kind = 'fileConfig'
					node.id = xcode6.newid(respath, 'PBXFileReference')
					node.buildId = xcode6.newid(respath, 'PBXBuildFile')
					node.fileType = xcode6.getFileType(respath)
					table.insert(prj.resourceIds, { id = node.buildId, name = path.getname(respath) })
				end
			end)

			if #resT.children > 0 then
				tree.trimroot(resT)
				tree.insert(prjT, resT)
			end

			-- add configs to project.
			prjT.configList = tree.new(prj.name)
			prjT.configList.kind = 'configList'
			prjT.configList.id   = xcode6.newid(prj.name, 'project', 'XCConfigurationList')
			prjT.configList.isa  = 'PBXNativeTarget'

			for cfg in project.eachconfig(prj) do
				local cfgT = tree.insert(prjT.configList, tree.new(cfg.name))
				cfgT.kind     = 'config'
				cfgT.config   = cfg
				cfgT.project  = prj
				cfgT.id       = xcode6.newid(cfg.name, prj.name, 'project', 'XCBuildConfiguration')
				cfgT.links    = {}
				cfg.xcodeNode = cfgT

				local links = premake.config.getlinks(cfg, "system", "fullpath")
				for _, link in ipairs(links) do
					local name = path.getname(link)
					local linkT = frameworks.children[name] or libraries.children[name]
					if not linkT then
						linkT = tree.new(name)
						linkT.kind          = 'link'
						linkT.id            = xcode6.newid(link, "PBXFileReference")
						linkT.fileType      = xcode6.getFileType(link)
						linkT.buildCategory = xcode6.getBuildCategory(link)

						if linkT.buildCategory then
							linkT.buildId = xcode6.newid(link, "PBXBuildFile", linkT.buildCategory, prjT.frameworkBuildPhaseId)
						end

						if path.isframework(name) then
							local dir, sourceTree = xcode6.getFrameworkPath(link)
							linkT.path       = dir
							linkT.sourceTree = sourceTree

							if sourceTree == 'SOURCE_ROOT' then
								linkT.path = path.getrelative(sln.location, path.join(prj.location, dir))
							end

							tree.insert(frameworks, linkT)

						else
							linkT.path       = path.getrelative(sln.location, path.join(prj.location, link))
							linkT.sourceTree = 'SOURCE_ROOT'

							tree.insert(libraries, linkT)
						end
					end

					if path.isframework(name) then
						if not table.contains(prjT.frameworks, linkT) then
							table.insert(prjT.frameworks, linkT)
						end
					else
						table.insert(cfgT.links, linkT)
					end
				end
			end
		end

		-- only add frameworks to the tree if there are any.
		if #frameworks.children > 0 then
			tree.insert(slnT, frameworks)
			slnT.frameworks = frameworks
		end

		-- only add libraries to the tree if there are any.
		if #libraries.children > 0 then
			tree.insert(slnT, libraries)
			slnT.libraries = libraries
		end

		-- only add products to the tree if there are any.
		if #products.children > 0 then
			tree.insert(slnT, products)
			slnT.products = products
		end

		-- add solution configs to solution
		slnT.configList = tree.new(sln.name)
		slnT.configList.kind = 'configList'
		slnT.configList.id   = xcode6.newid(sln.name, 'solution', 'XCConfigurationList')
		slnT.configList.isa  = 'PBXProject'

		for cfg in solution.eachconfig(sln) do
			local cfgT = tree.insert(slnT.configList, tree.new(cfg.name))
			cfgT.kind     = 'config'
			cfgT.config   = cfg
			cfgT.id       = xcode6.newid(cfg.name, sln.name, 'solution', 'XCBuildConfiguration')
			cfg.xcodeNode = cfgT
		end

		tree.trimroot(slnT)
		tree.sort(slnT, sorter)

		print('end buildSolutionTree')
		return slnT
	end
