local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Cursors",
		desc = "Assigns some UI related mouse cursors",
		author = "Floris",
		date = "August 2021",
		license   = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true
	}
end

if not gadgetHandler:IsSyncedCode() then return end

local cursors = {
	'uiresizev',
	'uiresizeh',
	'uiresized1',
	'uiresized2',
	'uimove',
}

function gadget:Initialize()
	for k, cursor in pairs(cursors) do
		Spring.AssignMouseCursor(cursor, cursor, false)
	end
end

