--
-- xcode6_action.lua
-- Define the Apple XCode action and support functions.
-- Copyright (c) 2015 Blizzard Entertainment
--
	premake.xcode6 = { }
	local api	   = premake.api
	local xcode6   = premake.xcode6
	local config   = premake.config
	local project  = premake.project
	local solution = premake.solution

	function xcode6.solution(sln)
		local pbxproject = xcode6.getSolutionTree(sln)
		local objects = { }
		local objectsByType = { }

		xcode6.catalogObjects(sln.xcodeNode, objects, objectsByType)
		table.sort(objectsByType)

		_p('// !$*UTF8*$!')
		_p('{')
		_p(1, 'archiveVersion = 1;')
		_p(1, 'classes = {')
		_p(1, '};')
		_p(1, 'objectVersion = 46;')
		_p(1, 'objects = {')

		table.foreachi(objectsByType, function(category)
			_p('')
			_p('/* Begin %s section */', category)
			table.foreachi(objectsByType[category], function(obj)
				xcode6.printObject(obj, 2)
			end)
			_p('/* End %s section */', category)
		end)

		_p(1, '};')
		_p(1, 'rootObject = %s /* %s */;', objectsByType.PBXProject[1]._id, objectsByType.PBXProject[1]._comment)
		_p('}')
	end

	function xcode6.catalogObjects(obj, objects, objectsByType)
		if obj._id and obj.isa then
			objects[obj._id] = obj
			if not objectsByType[obj.isa] then
				objectsByType[obj.isa] = { obj }
				table.insert(objectsByType, obj.isa)
			else
				table.insertsorted(objectsByType[obj.isa], obj, function(a, b)
					return a._id < b._id
				end)
			end
		end

		for k, v in pairs(obj) do
			if (type(k) == 'number' or not k:find('^_')) and type(v) == 'table' and not (v._id and objects[v._id]) then
				xcode6.catalogObjects(v, objects, objectsByType)
			end
		end
	end

	function xcode6.printObject(obj, indent)
		local a = obj._comment and string.format('%s /* %s */', obj._id, obj._comment) or obj._id
		local b = xcode6.formatObject(obj, indent, true)
		local c = string.format('%s = %s;', a, b)
		premake.outln(string.rep("\t", indent) .. c)
	end

	function xcode6.formatObject(obj, indent, expand, style)
		if type(obj) == 'string' then
			return xcode6.quoted(obj)
		elseif type(obj) == 'number' then
			return tostring(obj)
		elseif type(obj) == 'boolean' then
			return obj and 'YES' or 'NO'
		elseif not expand and obj._id then
			return obj._comment and string.format("%s /* %s */", obj._id, obj._comment) or obj._id
		else
			style = style or obj._formatStyle

			local indentStr = ''
			local indent1Str = ''
			local newline = ' '
			if style ~= 'compact' then
				indentStr = string.rep('\t', indent)
				indent1Str = indentStr .. '\t'
				newline = '\n'
			end
			if #obj == 0 and next(obj) ~= nil then
				local fields = { }
				for k in pairs(obj) do
					table.insertsorted(fields, k, function(a, b)
						if a == 'isa' then
							return a ~= b
						elseif b == 'isa' then
							return false
						end
						return a < b
					end)
				end

				local str = '{' .. newline
				table.foreachi(fields, function(k)
					if not k:find('^_') then
						str = str .. string.format('%s%s = %s;%s', indent1Str, k, xcode6.formatObject(obj[k], indent + 1, false, style), newline)
					end
				end)
				return str .. string.format('%s}', indentStr)
			else
				local str = '(' .. newline
				table.foreachi(obj, function(v)
					str = str .. string.format('%s%s,%s', indent1Str, xcode6.formatObject(v, indent + 1, false, style), newline)
				end)
				return str .. string.format('%s)', indentStr)
			end
		end
	end

