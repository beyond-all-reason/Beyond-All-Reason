
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

local cortronWeaponDef = WeaponDefNames['cortron_cortron_weapon']
local COR_TRON = cortronWeaponDef and cortronWeaponDef.id

local splashCEG1 = "splash-tiny"
local splashCEG2 = "splash-small"
local splashCEG3 = "splash-medium"
local splashCEG4 = "splash-large"
local splashCEG5 = "splash-huge"
local splashCEG6 = "splash-gigantic"
local splashCEG7 = "splash-nuke"
local splashCEG8 = "splash-nukexl"


local weaponAoe = {}
local weaponNoSplash = {}
for weaponDefID, def in pairs(WeaponDefs) do
	weaponAoe[weaponDefID] = def.damageAreaOfEffect

	local waterSplash = def.customParams.water_splash and tonumber(def.customParams.water_splash)
	waterSplash = waterSplash or (nonexplosiveWeapons[def.type] and 0 or 1)

	if waterSplash == 0 then
		weaponNoSplash[weaponDefID] = true
	end
	-- add damage bonus, since LRPC dont have a lot of AoE, but do pack a punch
	if def.type == 'DGun' then
		weaponAoe[weaponDefID] = weaponAoe[weaponDefID] + 80
	else
		if def.damages then
			-- get highest damage category
			local maxDmg = 0
			for _,v in pairs(def.damages) do
				if v > maxDmg then
					maxDmg = v
				end
			end
			if def.paralyzer then
				maxDmg = maxDmg / 25
			end
			weaponAoe[weaponDefID] = weaponAoe[weaponDefID] + (maxDmg/20)
		end
	end
end

function gadget:Explosion(weaponID, px, py, pz, ownerID)
	if Spring.GetGroundHeight(px,pz) < 0 then
		local aoe = weaponAoe[weaponID] / 2
		if not weaponNoSplash[weaponID] and abs(py) <= aoe and (not GetGroundBlocked(px, pz)) then
			if aoe >= 6 and aoe < 12 then
				Spring.SpawnCEG(splashCEG1, px, 0, pz)
			elseif  aoe >= 12 and aoe < 24 then
				Spring.SpawnCEG(splashCEG2, px, 0, pz)
			elseif aoe >= 24 and aoe < 48 then
				Spring.SpawnCEG(splashCEG3, px, 0, pz)
			elseif aoe >= 48 and aoe < 64 then
				Spring.SpawnCEG(splashCEG4, px, 0, pz)
			elseif aoe >= 64 and aoe < 200 then
				if weaponID == COR_TRON then
					Spring.SpawnCEG(splashCEG6, px, 0, pz)
				end
				Spring.SpawnCEG(splashCEG5, px, 0, pz)
			elseif aoe >= 200 and aoe < 400 then
				Spring.SpawnCEG(splashCEG6, px, 0, pz)
			elseif aoe >= 400 and aoe < 600 then
				Spring.SpawnCEG(splashCEG7, px, 0, pz)
			elseif aoe >= 600 then
				Spring.SpawnCEG(splashCEG8, px, 0, pz)
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
