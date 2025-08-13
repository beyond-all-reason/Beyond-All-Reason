local widget = widget ---@type Widget
function widget:GetInfo()
	return {
		name = "Modoption: Disable Economic Sharing",
		desc = "UI behavior for disabled economic sharing",
		author = "Hobo Joe",
		date = "August 2025",
		license = "GNU GPL, v2 or later",
		layer = 9999, -- run this after all the UI widgets we touch have been initialized
		enabled = true,
	}
end

local enabled = Spring.GetModOptions().disable_economic_sharing
if not enabled then
	return false
end

local restrictedUnits = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.canAssist or unitDef.isFactory then
		restrictedUnits[unitDefID] = true
	end
	if unitDef.customparams and (unitDef.customparams.unitgroup == "energy" or unitDef.customparams.unitgroup == "metal") then
		restrictedUnits[unitDefID] = true
	end
end

function widget:Initialize()
	WG['resource_spot_builder'].SetAllyExtractorCanBeUpgraded(true)
	WG['topbar'].setShareSliderEnabled(false)
	WG['sharecmd'].setRestrictedUnits(restrictedUnits)
end
