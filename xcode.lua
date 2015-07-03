---
-- xcode/xcode.lua
-- Common support code for the Apple Xcode exporters.
-- Copyright (c) 2015 Blizzard Entertainment
---

	local p = premake

	p.modules.xcode = {}

	local m = p.modules.xcode
	m.elements = {}

	dofile("_preload.lua")
	dofile("xcode_action.lua")
	dofile("xcode_tree.lua")
	dofile("xcode_utils.lua")

	return m
