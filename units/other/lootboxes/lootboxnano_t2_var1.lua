unitName = "lootboxnano_t2_var1"
humanName = "Specialist NanoTurret T2"
sizeMultiplier = 1.875
collisionVolumeScales = "59 60 59"

local Rmodel = math.random()
if Rmodel < 0.5 then
	objectName = "lootboxes/lootboxnanoarmT2.s3o"
	script = "lootboxes/lootboxnanoarm.cob"
else
	objectName = "lootboxes/lootboxnanocorT2.s3o"
	script = "lootboxes/lootboxnanocor.cob"
end

VFS.Include("unitbasedefs/lootboxes/lootboxnanounitlists.lua")

buildlistRNG = {}
for a = 1,8 do
	local choosenOne = buildPossibleOptionsT2[math.ceil(#buildPossibleOptionsT2*math.random())]
	buildlistRNG[a] = choosenOne
end


VFS.Include("unitbasedefs/lootboxes/lootboxnano.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------