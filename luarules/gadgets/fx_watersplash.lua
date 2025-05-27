
local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name      = "Watereffects",
		desc      = "Make splash sound in water",
		version   = "1.1",
		author    = "Jools ,Nixtux",
		date      = "April,2012",
		license   = "GNU GPL, v2 or later",
		layer     = 0,
		enabled   = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
    return false
end

local abs = math.abs
local GetGroundBlocked = Spring.GetGroundBlocked
local nonexplosiveWeapons = {
	LaserCannon = true,
	BeamLaser = true,
	EmgCannon = true,
	Flame = true,
	LightningCannon = true,
}

local splashCEGs = {
	"splash-tiny",
	"splash-small",
	"splash-medium",
	"splash-large",
	"splash-huge",
	"splash-gigantic",
	"splash-nuke",
	"splash-nukexl",
}

local function getWeaponAOE(weaponDef, waterSplash)
	local aoe = weaponDef.damageAreaOfEffect
	-- add damage bonus, since LRPC dont have a lot of AoE, but do pack a punch
	if weaponDef.type == 'DGun' then
		aoe = aoe + 80
	else
		if weaponDef.damages and waterSplash ~= 0 then
			local maxDmg = 0
			for _,v in pairs(weaponDef.damages) do
				if v > maxDmg then
					maxDmg = v
				end
			end
			if weaponDef.paralyzer then
				maxDmg = maxDmg / 25
			end
			aoe = (aoe + (maxDmg/20))
		end
	end
	return aoe / 2
end

local function getSplashSize(weaponDef, aoe)
	local splashSize
	if aoe >= 6 and aoe < 12 then
		splashSize = 1
	elseif  aoe >= 12 and aoe < 24 then
		splashSize = 2
	elseif aoe >= 24 and aoe < 48 then
		splashSize = 3
	elseif aoe >= 48 and aoe < 64 then
		splashSize = 4
	elseif aoe >= 64 and aoe < 200 then
		splashSize = 5
	elseif aoe >= 200 and aoe < 400 then
		splashSize = 6
	elseif aoe >= 400 and aoe < 600 then
		splashSize = 7
	elseif aoe >= 600 then
		splashSize = 8
	end
	return splashSize
end

local weaponNoSplash = {}
local weaponAoe = {}
local weaponSplashCEG = {}
for weaponDefID, def in pairs(WeaponDefs) do

	local waterSplash = def.customParams.water_splash and tonumber(def.customParams.water_splash)
	waterSplash = waterSplash or (nonexplosiveWeapons[def.type] and 0 or 1)

	if waterSplash == 0 then
		weaponNoSplash[weaponDefID] = true
	end

	weaponAoe[weaponDefID] = getWeaponAOE(def, waterSplash)

	if def.damages and waterSplash ~= 0 then
		local splashCEG = def.customParams.water_splash_ceg
		if not splashCEG then
			local splashSize = getSplashSize(def, weaponAoe[weaponDefID])
			if splashSize then
				splashCEG = splashCEGs[splashSize]
			end
		end
		if splashCEG then
			weaponSplashCEG[weaponDefID] = splashCEG
		end
	end
end

function gadget:Explosion(weaponID, px, py, pz, ownerID)
	if Spring.GetGroundHeight(px,pz) < 0 then
		local aoe = weaponAoe[weaponID]
		if not weaponNoSplash[weaponID] and abs(py) <= aoe and (not GetGroundBlocked(px, pz)) then
			local splashCEG = weaponSplashCEG[weaponID]
			if splashCEG then
				Spring.Echo(splashCEG)
				Spring.SpawnCEG(splashCEG, px, 0, pz)
			end
			return true
		else
			return false
		end
	else
		return false
	end
end

function gadget:Initialize()
	local minHeight, maxHeight = Spring.GetGroundExtremes()
	if minHeight < 100 then
		for wDefID, wDef in pairs(WeaponDefs) do
			if wDef.damageAreaOfEffect ~= nil and wDef.damageAreaOfEffect > 8 and (not weaponNoSplash[wDefID]) then
				Script.SetWatchExplosion(wDef.id, true)
			end
		end
	else
		gadgetHandler:RemoveGadget(self)
	end
end
