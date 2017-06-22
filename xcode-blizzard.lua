---
-- xcode/xcode.lua
-- Common support code for the Apple Xcode exporters.
-- Copyright (c) 2015 Blizzard Entertainment
---

	local p = premake

	p.modules.xcode_blizzard = {}
	p.modules.xcode_blizzard._VERSION = p._VERSION

	include("xcode_action.lua")
	include("xcode_tree.lua")
	include("xcode_utils.lua")

	return p.modules.xcode_blizzard
