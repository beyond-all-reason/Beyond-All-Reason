--------------------------------------------------------------------------------
-- Default Engine Weapon Definitions Post-processing
--------------------------------------------------------------------------------
-- BAR stores weapondefs in the unitdef files
-- Here we load those defs into the WeaponDefs table
-- Then we call alldefs_post.lua, in which post processing of defs should take place
-- basically, DONT TOUCH this!
--------------------------------------------------------------------------------

-- see alldefs.lua for documentation
local system = VFS.Include("gamedata/system.lua")
local alldefs = VFS.Include("gamedata/alldefs_post.lua")
local savedefs = VFS.Include("gamedata/post_save_to_customparams.lua")

local weaponDefPost = alldefs.WeaponDef_Post
local modOptionsPost = alldefs.ModOptions_Post
local saveDefToCustomParams = savedefs.SaveDefToCustomParams
local markDefOmittedInCustomParams = savedefs.MarkDefOmittedInCustomParams

--------------------------------------------------------------------------------

local function normalizeWeaponDef(weaponDef)
	system.lowerkeys(weaponDef)
	table.ensureTable(weaponDef, "customparams")
	-- TODO: there are individual shield keys, also, not just a shield subtable
	if weaponDef.weapontype == "Shield" then
		table.ensureTable(weaponDef, "shield")
		weaponDef.damage = nil
	else
		table.ensureTable(weaponDef, "damage")
		weaponDef.shield = nil
	end
end

local function ExtractWeaponDefs(unitDefName, unitDef)
	local unitWeaponDefs = unitDef.weapondefs

	local prefix = unitDefName .. "_"

	-- add this unitDef's weaponDefs
	for weaponDefName, weaponDef in pairs(unitWeaponDefs) do
		local fullName = prefix .. weaponDefName
		WeaponDefs[fullName] = weaponDef
		normalizeWeaponDef(weaponDef)

		if SaveDefsToCustomParams then
			markDefOmittedInCustomParams("WeaponDefs", fullName, weaponDef)
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

		if WeaponDefs[fullName] then
			unitDef.explodeas = fullName
		end
	end

	if unitDef.selfdestructas then
		local fullName = prefix .. unitDef.selfdestructas

		if WeaponDefs[fullName] then
			unitDef.selfdestructas = fullName
		end
	end
end

--------------------------------------------------------------------------------

-- preprocess existing weapondefs entries
for name, weaponDef in pairs(WeaponDefs) do
	normalizeWeaponDef(weaponDef)
end

-- extract weapondefs from the unitdefs
local UnitDefs = DEFS.unitDefs
for name, unitDef in pairs(UnitDefs) do
	ExtractWeaponDefs(name, unitDef)
end

-- postprocess weapondefs
for name, weaponDef in pairs(WeaponDefs) do
	weaponDefPost(name, weaponDef)

	if SaveDefsToCustomParams then
		saveDefToCustomParams("WeaponDefs", name, weaponDef)
	end
end

-- apply mod options that need _post
modOptionsPost(UnitDefs, WeaponDefs)
