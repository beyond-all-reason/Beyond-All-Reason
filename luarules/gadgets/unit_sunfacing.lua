local gadget = gadget ---@type Gadget

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

local spCallCOBScript = Spring.CallCOBScript
local mathAtan2 = math.atan2
local mathDeg = math.deg
local mathTau = math.tau
local mathPi = math.pi

local sundir, mapinfo
local success = false

local function solarpoint(unitID, unitDefID, team)
	if success then
		local sunheading = mathAtan2(sundir[1], sundir[3]) * ((COBSCALE / mathDeg(mathTau)) / mathPi) -- WIZARDRY INTENSIFIES (182.04)
		spCallCOBScript(unitID, "solarreturn", 3, 1, sunheading)
	else
		spCallCOBScript(unitID, "solarreturn", 3, 0, 0)
	end
	return 1
end

function gadget:Initialize()
	gadgetHandler:RegisterGlobal("solarpoint", solarpoint)

	success, mapinfo = pcall(VFS.Include,"mapinfo.lua")
	if success and mapinfo then
		sundir = mapinfo.lighting.sundir
	end
end
