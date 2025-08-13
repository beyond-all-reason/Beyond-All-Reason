local gadget = gadget ---@type Gadget

local enabled = Spring.GetModOptions().disable_economic_sharing
if not enabled then
	return false
end

function gadget:GetInfo()
	return {
		name = "Modoption: Disable Economic Sharing",
		desc = "Rules behavior for disabled economic sharing",
		author = "Hobo Joe",
		date = "August 2025",
		license = "GNU GPL, v2 or later",
		layer   = 9999, -- run this after other gadgets have initialized
		enabled = true
	}
end

----------------------------------------------------------------
-- Synced only
----------------------------------------------------------------
if not gadgetHandler:IsSyncedCode() then
	return false
end

----------------------------------------------------------------
-- Modoption behavior
----------------------------------------------------------------

-- cache unshareable units
local unshareable = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.canAssist or unitDef.isFactory then
		unshareable[unitDefID] = true
	end
	if unitDef.customparams and (unitDef.customparams.unitgroup == "energy" or unitDef.customparams.unitgroup == "metal") then
		unshareable[unitDefID] = true
	end
end


function gadget:Initialize()
	-- set share level to max
	local teams = Spring.GetTeamList()
	for _, teamID in ipairs(teams) do
		Spring.SetTeamShareLevel(teamID, 'metal', 0)
		Spring.SetTeamShareLevel(teamID, 'energy', 0)
	end
end


-- once it is available we'll use a callin like gadget:OnResourceExcess, either here or in a standalone gadget


function gadget:AllowUnitTransfer(unitID, unitDefID, fromTeamID, toTeamID, capture)
	if capture then
		return true
	end
	if unshareable[unitDefID] then
		return false
	end
	return true
end
