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

local UPGET_NAME = "modoption_disable_economic_sharing"


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

		-- set extractor upgrade behavior
		if globalScope['resource_spot_builder'] and globalScope['resource_spot_builder'].SetAllyExtractorCanBeUpgraded then
			globalScope['resource_spot_builder'].SetAllyExtractorCanBeUpgraded(false)
		else
			Spring.Echo("ERROR: " .. UPGET_NAME .. " Unable to access resource_spot_builder widget")
		end

		-- set share slider behavior
		if globalScope['topbar'] and globalScope['topbar'].setShareSliderEnabled then
			globalScope['topbar'].setShareSliderEnabled(false)
		else
			Spring.Echo("ERROR: " .. UPGET_NAME .. " Unable to access topbar widget")
		end

		-- set share unit button visibility
		if globalScope['sharecmd'] and globalScope['sharecmd'].setRestrictedUnits then
			globalScope['sharecmd'].setRestrictedUnits(restrictedUnits)
		else
			Spring.Echo("ERROR: " .. UPGET_NAME .. " Unable to access sharecmd widget")
		end

		-- disable share bars in playerlist
		if globalScope['advplayerlist_api'] and globalScope['advplayerlist_api'].SetModuleActive then
			globalScope['advplayerlist_api'].SetModuleActive({ 'share_resource', false })
		else
			Spring.Echo("ERROR: " .. UPGET_NAME .. " Unable to access advplayerlist widget")
		end
	end

	if gadget then

		-- set which units can be shared
		if globalScope['restrict_unit_sharing'] and globalScope['restrict_unit_sharing'].setBlacklist then
			globalScope['restrict_unit_sharing'].setBlacklist(restrictedUnits)
		else
			Spring.Echo("ERROR: " .. UPGET_NAME .. " Unable to access restrict_unit_sharing gadget")
		end

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
