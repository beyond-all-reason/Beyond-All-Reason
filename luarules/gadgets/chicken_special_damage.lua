--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:GetInfo()
  return {
    name      = "Chicken Special Damage",
    desc      = "Nerfs some weapons vs Chickens",
    author    = "TheFatController",
    date      = "Aug 31, 2013",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true  --  loaded by default?
  }
end

local teams = Spring.GetTeamList()
for i =1, #teams do
	local luaAI = Spring.GetTeamLuaAI(teams[i])
	if luaAI and luaAI ~= "" and string.sub(luaAI, 1, 9) == 'Chicken: ' then
		chickensEnabled = true
	end
end

if chickensEnabled == true then
	Spring.Echo("[ChickenDefense: Chicken Special Damage] Activated!")
else
	Spring.Echo("[ChickenDefense: Chicken Special Damage] Deactivated!")
	return false
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--There are some *A-isms in here, but they don't cause any issues, so I don't see the point in removing them and making some poor sap recreate them for his game.

if (not gadgetHandler:IsSyncedCode()) then
  return false  --  silent removal
end

local DAMAGE_LIMITS = {
	[WeaponDefNames['cordecom_disintegrator'].id] = 10,
	[WeaponDefNames['armdecom_disintegrator'].id] = 10,
	[WeaponDefNames['cordecom_bar_disintegrator'].id] = 10,
	[WeaponDefNames['armdecom_bar_disintegrator'].id] = 10,
}

local DGUN = {
	[WeaponDefNames['corcom_disintegrator'].id] = 15000,
	[WeaponDefNames['armcom_disintegrator'].id] = 15000,
	[WeaponDefNames['corcom_bar_disintegrator'].id] = 15000,
	[WeaponDefNames['armcom_bar_disintegrator'].id] = 15000,
}

local CHICKEN_RESISTS = {
	[UnitDefNames['chickenp1'].id] = {
		[WeaponDefNames['cormaw_dmaw'].id] = 0.4,
		[WeaponDefNames['corpyro_flamethrower'].id] = 0.4,
		[WeaponDefNames['corhurc_coradvbomb'].id] = 0.75,
		[WeaponDefNames['cortermite_core_termite_laser'].id] = 0.75,
		[WeaponDefNames['corkrog_corkrog_laser'].id] = 0.75,
	},
	[UnitDefNames['chickenc1'].id] = {
		[WeaponDefNames['armclaw_dclaw'].id] = 0.6,
		[WeaponDefNames['armzeus_lightning'].id] = 0.6,
		[WeaponDefNames['armlatnk_armlatnk_weapon'].id] = 0.6,
		[WeaponDefNames['armbanth_armbantha_fire'].id] = 0.6,
	},
	[UnitDefNames['chickenc3'].id] = {
		[WeaponDefNames['armclaw_dclaw'].id] = 0.5,
		[WeaponDefNames['armzeus_lightning'].id] = 0.5,
		[WeaponDefNames['armlatnk_armlatnk_weapon'].id] = 0.5,
		[WeaponDefNames['armbanth_armbantha_fire'].id] = 0.5,
	},
	[UnitDefNames['chickenc3b'].id] = {
		[WeaponDefNames['armclaw_dclaw'].id] = 0.5,
		[WeaponDefNames['armzeus_lightning'].id] = 0.5,
		[WeaponDefNames['armlatnk_armlatnk_weapon'].id] = 0.5,
		[WeaponDefNames['armbanth_armbantha_fire'].id] = 0.5,
	},
	[UnitDefNames['chickenc3b'].id] = {
		[WeaponDefNames['armclaw_dclaw'].id] = 0.5,
		[WeaponDefNames['armzeus_lightning'].id] = 0.5,
		[WeaponDefNames['armlatnk_armlatnk_weapon'].id] = 0.5,
		[WeaponDefNames['armbanth_armbantha_fire'].id] = 0.5,
	},
	[UnitDefNames['chickenh5'].id] = {
		[WeaponDefNames['corvipe_vipersabot'].id] = 0.5,
		[WeaponDefNames['armpb_armpb_weapon'].id] = 0.5,
	},
	[UnitDefNames['chicken2b'].id] = {
		[WeaponDefNames['cordoom_atadr'].id] = 0.666,
		[WeaponDefNames['armanni_ata'].id] = 0.666,
	},
}

function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, 
                            weaponID, projectileID, attackerID, attackerDefID, attackerTeam)
  
  if CHICKEN_RESISTS[unitDefID] and CHICKEN_RESISTS[unitDefID][weaponID] then
	return damage * CHICKEN_RESISTS[unitDefID][weaponID], CHICKEN_RESISTS[unitDefID][weaponID]
  end     
  
  if DAMAGE_LIMITS[weaponID] then
		return math.min(DAMAGE_LIMITS[weaponID],damage),1
  elseif (DGUN[weaponID] and (string.find(UnitDefs[unitDefID].name, "chickenq") ~= nil)) then
		return math.min(DGUN[weaponID],damage),1
  elseif ((damage > 50000) and (string.find(UnitDefs[unitDefID].name, "chickenq") ~= nil)) then
		return math.min(50000,damage),1
  else
		return damage,1
  end
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------