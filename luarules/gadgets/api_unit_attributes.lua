local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Unit Attributes API",
		desc = "Unitdef and unit attribute overrides and modifiers via GG.UnitAttributes",
		author = "efrec",
		date = "September 2026",
		license = "GNU GPL, v2 or later",
		layer = 1, -- after unit_custommaxranges, which overwrites a def maxWeaponRange attrib -- TODO: fix
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local attributes = VFS.Include("luarules/gadgets/include/unit_attributes_control.lua")

GG.UnitAttributes = {
	Definitions = attributes.Definitions,

	SetUnitDefAttribute = attributes.SetUnitDefAttribute,
	SetUnitAttribute = attributes.SetUnitAttribute,
	SetUnitDefModifier = attributes.SetUnitDefModifier,
	SetUnitModifier = attributes.SetUnitModifier,

	GetUnitAttributeValue = attributes.GetUnitAttributeValue,
}

local updateAll = attributes.UpdateAll
function gadget:GameFrame(frame)
	updateAll(frame)
end

local onCreated = attributes.ApplyOnCreated
function gadget:UnitCreated(unitID, unitDefID)
	onCreated(unitID, unitDefID)
end

local onDestroyed = attributes.ApplyOnDestroyed
function gadget:UnitDestroyed(unitID)
	onDestroyed(unitID)
end

local onGiven = attributes.ApplyOnGiven
function gadget:UnitGiven(unitID, unitDefID, newTeamID, oldTeamID)
	onGiven(unitID, unitDefID, newTeamID, oldTeamID)
end

local onExperience = attributes.ApplyOnExperience
function gadget:UnitExperience(unitID, unitDefID, unitTeam, experience, oldExperience)
	onExperience(unitID)
end

function gadget:Shutdown()
	GG.UnitAttributes = nil
	-- TODO: full save/load/reload
	attributes.ClearAll()
end
