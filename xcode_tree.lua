--
-- xcode6_tree.lua
-- Define the Apple XCode action and support functions.
-- Copyright (c) 2015 Tom van Dijck
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
				productT.buildId = xcode6.newid(productT.name, "PBXBuildFile")
			end

			-- create project node.
			local group = tree.add(slnT, path.join('Targets', prj.group), { kind = 'group' } )
			xcode6.setProductGroupId(group)
			local prjT = tree.insert(group, tree.new(prj.name))

			prjT.kind                   = 'project'
			prjT.project                = prj
			prjT.solution               = sln
			prjT.targetId               = xcode6.newid(prj.name, 'PBXNativeTarget')
			prjT.containerItemProxyId   = xcode6.newid(prj.name, 'PBXContainerItemProxy')
			prjT.targetDependencyId     = xcode6.newid(prj.name, 'PBXTargetDependency')
			prjT.sourcesBuildPhaseId    = xcode6.newid(prj.name, 'PBXSourcesBuildPhase')
			prjT.productGroupId         = xcode6.newid(prj.name, 'project', 'PBXGroup')
			prjT.dependencies           = project.getdependencies(prj)
			prjT.frameworks             = {}
			prjT.product                = productT
			prj.xcodeNode               = prjT

			if #prjT.dependencies > 0 then
			    prjT.frameworkBuildPhaseId = xcode6.newid(prj.name, 'PBXFrameworksBuildPhase')
			end

			-- add files to project.
			table.foreachi(prj._.files, function(fcfg)
				local flags =
				{
					trim = (fcfg.vpath == fcfg.relpath),
					kind = 'group'
				}

				local parent = tree.add(prjT, path.getdirectory(fcfg.vpath), flags)
				xcode6.setProductGroupId(parent)

				local fcfgT = tree.insert(parent, tree.new(path.getname(fcfg.vpath)))
				fcfgT.kind = 'fileConfig'
				fcfgT.fileConfig    = fcfg
				fcfgT.project       = prj
				fcfgT.solution      = sln
				fcfgT.relpath       = path.getrelative(sln.location, fcfg.abspath)
				fcfgT.id            = xcode6.newid(fcfg.abspath, "PBXFileReference")
				fcfgT.fileType      = xcode6.getFileType(fcfg.abspath)
				fcfgT.isResource    = xcode6.isItemResource(prj, fcfg)
				fcfgT.buildCategory = xcode6.getBuildCategory(fcfg.abspath)

				if fcfgT.buildCategory then
					fcfgT.buildId = xcode6.newid(fcfg.abspath, "PBXBuildFile")
				end

				if string.endswith(fcfg.abspath, "Info.plist") then
					prjT.infoplist = fcfgT
				end

				if path.getextension(fcfg.abspath) == '.mig' then
					prjT.needsMigRule = true
					slnT.needsMigRule = true
				end

				fcfg.xcodeNode = fcfgT
			end)

			-- add configs to project.
			prjT.configList = tree.new(prj.name)
			prjT.configList.kind = 'configList'
			prjT.configList.id   = xcode6.newid(prj.name, 'project', 'XCConfigurationList')

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
							linkT.buildId = xcode6.newid(link, "PBXBuildFile")
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
