local upget = gadget or widget ---@type Addon
local globalScope = gadget and GG or WG

local enabled = Spring.GetModOptions().disable_economic_sharing
if not enabled then
	return false
end


function upget:GetInfo()
	return {
		name = "Modoption: Disable Economic Sharing",
		desc = "modoption behavior for disabled economic sharing",
		author = "Hobo Joe",
		date = "August 2025",
		license = "GNU GPL, v2 or later",
		layer = 9999, -- run this after all the widgets and gadgets we touch have been initialized
		enabled = true,
	}
end

if gadget then
	if not gadgetHandler:IsSyncedCode() then
		return
	end
end


local restrictedUnits = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.canAssist or unitDef.isFactory or unitDef.isBuilder then
		restrictedUnits[unitDefID] = true
	end
	if unitDef.customParams and (unitDef.customParams.unitgroup == "energy" or unitDef.customParams.unitgroup == "metal") then
		restrictedUnits[unitDefID] = true
	end
end


function upget:Initialize()
	if widget then
		globalScope['resource_spot_builder'].SetAllyExtractorCanBeUpgraded(true)
		globalScope['topbar'].setShareSliderEnabled(false)
		globalScope['sharecmd'].setRestrictedUnits(restrictedUnits)
		globalScope['advplayerlist_api'].SetModuleActive({ 'share_resource', false })
	end
	if gadget then
		globalScope['restrict_unit_sharing'].setBlacklist(restrictedUnits)

		-- set share level to max
		local teams = Spring.GetTeamList()
		for _, teamID in ipairs(teams) do
			Spring.SetTeamShareLevel(teamID, 'metal', 1)
			Spring.SetTeamShareLevel(teamID, 'energy', 1)
		end

	end
end


function upget:AllowResourceTransfer(senderId, receiverId, resourceType, amount)
	return false
end
