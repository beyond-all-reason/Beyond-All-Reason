--------------------------------------------------------------------------------
-- Default Engine Weapon Definitions Post-processing
--------------------------------------------------------------------------------
-- BAR stores weapondefs in the unitdef files
-- Here we load those defs into the WeaponDefs table
-- Then we call alldefs_post.lua, in which post processing of defs should take place
-- basically, DONT TOUCH this!
--------------------------------------------------------------------------------

-- see alldefs.lua for documentation
-- load the games _Post functions for defs, and find out if saving to custom params is wanted
VFS.Include("gamedata/alldefs_post.lua")
-- load functionality for saving to custom params
VFS.Include("gamedata/post_save_to_customparams.lua")

--------------------------------------------------------------------------------

local function ExtractWeaponDefs(unitDefName, unitDef)
	local unitWeaponDefs = unitDef.weapondefs
	if not unitWeaponDefs then
		return
	end

	local prefix = unitDefName .. "_"

	-- add this unitDef's weaponDefs
	for weaponDefName, weaponDef in pairs(unitWeaponDefs) do
		local fullName = prefix .. weaponDefName
		WeaponDefs[fullName] = weaponDef

		if SaveDefsToCustomParams then
			MarkDefOmittedInCustomParams("WeaponDefs", fullName, weaponDef)
		end
	end

	-- convert the weapon names
	local weapons = unitDef.weapons
		for _, weapon in pairs(weapons) do
			local fullName = prefix .. weapon.def:lower()
			local weaponDef = WeaponDefs[fullName]

			if weaponDef then
				weapon.name = fullName
			end

			weapon.def = nil
		end

	-- convert the death explosions
	if unitDef.explodeas then
		local fullName = prefix .. unitDef.explodeas

		if (WeaponDefs[fullName]) then
			unitDef.explodeas = fullName
		end
	end

	if unitDef.selfdestructas then
		local fullName = prefix .. unitDef.selfdestructas

		if (WeaponDefs[fullName]) then
			unitDef.selfdestructas = fullName
		end
	end
end

--------------------------------------------------------------------------------

-- extract weapondefs from the unitdefs
local UnitDefs = DEFS.unitDefs
for name, unitDef in pairs(UnitDefs) do
	ExtractWeaponDefs(name, unitDef)
end

-- postprocess weapondefs
for name, weaponDef in pairs(WeaponDefs) do
	WeaponDef_Post(name, weaponDef)

	if SaveDefsToCustomParams then
		SaveDefToCustomParams("WeaponDefs", name, weaponDef)
	end
end


-- apply mod options that need _post
ModOptions_Post(UnitDefs, WeaponDefs)
