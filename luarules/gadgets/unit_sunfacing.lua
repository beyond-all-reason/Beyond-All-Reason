--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:GetInfo()
	return {
		name = "Sunfacer",
		desc = "Attempts to have advsolars face the sun",
		author = "Hornet",
		date = "March 18, 2024",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end
local sundir
local success
local mapinfo
success = false

local function solarpoint(unitID, unitDefID, team) 
	
	if success then

		local sunheading = math.atan2(sundir[1], sundir[3]) * ((COBSCALE / math.deg(math.tau)) / math.pi)--WIZARDRY INTENSIFIES (182.04)
		Spring.CallCOBScript(unitID, "solarreturn", 3, 1, sunheading)
	else
		Spring.CallCOBScript(unitID, "solarreturn", 3, 0, 0)
	end
	
	return 1
end




function gadget:Initialize()

	gadgetHandler:RegisterGlobal("solarpoint", solarpoint)

	if UnitDefNames.armadvsol then
		local advsols = {}
		advsols[UnitDefNames.armadvsol.id] = true

		if (UnitDefNames.armadvsol_scav) then
			advsols[UnitDefNames.armadvsol_scav.id] = true
		end

		--only look for advsols that care about the sun (coradvsol sun agnostic chad)
		if (UnitDefNames.legadvsol) then
			advsols[UnitDefNames.legadvsol.id] = true
		end

		if (UnitDefNames.legadvsol_scav) then
			advsols[UnitDefNames.legadvsol_scav.id] = true
		end

		success, mapinfo = pcall(VFS.Include,"mapinfo.lua")
				
		if success and mapinfo then
			sundir = mapinfo.lighting.sundir
		end
	

	else
		gadgetHandler:RemoveGadget(self)
	end
end