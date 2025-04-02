
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

local COR_SEAADVBOMB = WeaponDefNames['corsb_cor_seaadvbomb'].id --corsb gets a special ceg with less particles, because it has lots of bouncing bombs
local ARM_JUNO = WeaponDefNames['armjuno_juno_pulse'].id --juno can explode on water
local COR_JUNO = WeaponDefNames['corjuno_juno_pulse'].id --juno can explode on water
local COR_TRON = WeaponDefNames['cortron_cortron_weapon'].id
local LEG_PHOENIX = WeaponDefNames['legphoenix_legphtarg'] and WeaponDefNames['legphoenix_legphtarg'].id --targetting weapon aircraftbomb
-- maybe need addition of scav version or better solution

local splashCEG1 = "splash-tiny"
local splashCEG2 = "splash-small"
local splashCEG3 = "splash-medium"
local splashCEG4 = "splash-large"
local splashCEG5 = "splash-huge"
local splashCEG6 = "splash-gigantic"
local splashCEG7 = "splash-nuke"
local splashCEG8 = "splash-nukexl"


local weaponType = {}
local weaponAoe = {}
for weaponDefID, def in pairs(WeaponDefs) do
	weaponType[weaponDefID] = def.type
	weaponAoe[weaponDefID] = def.damageAreaOfEffect
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
		if not nonexplosiveWeapons[weaponType[weaponID]]  and abs(py) <= aoe and (not GetGroundBlocked(px, pz)) and weaponID ~= COR_SEAADVBOMB and weaponID ~= ARM_JUNO and weaponID ~= COR_JUNO and weaponID ~= LEG_PHOENIX then
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
		for _,wDef in pairs(WeaponDefs) do
			if wDef.damageAreaOfEffect ~= nil and wDef.damageAreaOfEffect >8 and (not nonexplosiveWeapons[wDef.type]) then
				Script.SetWatchExplosion(wDef.id, true)
			end
		end
	else
		gadgetHandler:RemoveGadget(self)
	end
end
