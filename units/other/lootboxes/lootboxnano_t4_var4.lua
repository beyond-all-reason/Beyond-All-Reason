unitName = "lootboxnano_t4_var4"
humanName = Spring.I18N('units.names.lootboxnano_t4')
sizeMultiplier = 16
collisionVolumeScales = "93 94 93"
footprintx = 4
footprintz = 4

local Rmodel = math.random()
if Rmodel < 0.5 then
	objectName = "lootboxes/lootboxnanoarmT4.s3o"
	script = "lootboxes/lootboxnanoarm.cob"
else
	objectName = "lootboxes/lootboxnanocorT4.s3o"
	script = "lootboxes/lootboxnanocor.cob"
end

VFS.Include("unitbasedefs/lootboxes/lootboxnanounitlists.lua")

buildlistRNG = {}
for a = 1,4 do
	local choosenOne = buildPossibleOptionsT4[math.ceil(#buildPossibleOptionsT4*math.random())]
	buildlistRNG[a] = choosenOne
end


VFS.Include("unitbasedefs/lootboxes/lootboxnano.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------