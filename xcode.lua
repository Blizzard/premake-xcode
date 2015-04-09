---
-- xcode/xcode.lua
-- Common support code for the Apple Xcode exporters.
-- Copyright (c) 2009-2015 Jason Perkins and the Premake project
---

	local p = premake

	p.modules.xcode = {}

	local m = p.modules.xcode
	m.elements = {}

	include("_preload.lua")
	include("xcode_action.lua")
	include("xcode_api.lua")
	include("xcode_config.lua")
	include("xcode_tree.lua")
	include("xcode_utils.lua")

	return m
