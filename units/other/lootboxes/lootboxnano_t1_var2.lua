unitName = "lootboxnano_t1_var2"
humanName = Spring.I18N('units.names.lootboxnano_t1')
sizeMultiplier = 2
collisionVolumeScales = "47 48 47"
footprintx = 3
footprintz = 3

local Rmodel = math.random()
if Rmodel < 0.5 then
	objectName = "lootboxes/lootboxnanoarmT1.s3o"
	script = "lootboxes/lootboxnanoarm.cob"
else
	objectName = "lootboxes/lootboxnanocorT1.s3o"
	script = "lootboxes/lootboxnanocor.cob"
end

VFS.Include("unitbasedefs/lootboxes/lootboxnanounitlists.lua")

buildlistRNG = {}
for a = 1,10 do
	local choosenOne = buildPossibleOptionsT1[math.ceil(#buildPossibleOptionsT1*math.random())]
	buildlistRNG[a] = choosenOne
end


VFS.Include("unitbasedefs/lootboxes/lootboxnano.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------