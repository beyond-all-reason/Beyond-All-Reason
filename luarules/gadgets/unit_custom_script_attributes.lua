local gadget = gadget ---@type Gadget

if not gadgetHandler:IsSyncedCode() then
	return false
end

function gadget:GetInfo()
	return {
		name = "Unit Script Attributes",
		desc = "Sends customparam values to COB scripts at unit creation",
		author = "efrec",
		version = "1.0",
		date = "2026-06",
		license = "GNU GPL, v2 or later",
		layer = -1, -- try to complete init/creation early
		enabled = true,
	}
end

local debug = false

local spCallCobScript = Spring.CallCOBScript
local UnitScriptAttributes = VFS.Include("common/unit_script_attributes.lua")

-- Engine callins

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	local attributes = UnitScriptAttributes.IsCob(unitDefID) and UnitScriptAttributes.Get(unitDefID)
	if attributes then
		for methodName, arguments in pairs(attributes) do
			if type(arguments) == "table" then
				spCallCobScript(unitID, methodName, 0, unpack(arguments))
			else
				spCallCobScript(unitID, methodName, 0, arguments)
			end
		end
	end
end

-- Debug

if debug then
	local __CallCobScript = spCallCobScript
	spCallCobScript = function(unitID, funcName, retArgs, ...)
		Spring.Echo(("Script attribute: %d, %s, %s"):format(unitID, funcName, table.concat({ ... }, ", ")))
		__CallCobScript(unitID, funcName, retArgs, ...)
	end
end
