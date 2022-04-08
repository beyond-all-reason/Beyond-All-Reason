local factories = {
	"armaap",
	"armalab",
	"armap",
	"armavp",
	"armhp",
	"armlab",
	"armshltx",
	"armvp",
	"armamsub",
	"armasy",
	"armfhp",
	"armplat",
	"armshltxuw",
	"armsy",
	"coraap",
	"coralab",
	"corap",
	"coravp",
	"corgant",
	"corhp",
	"corlab",
	"corvp",
	"coramsub",
	"corasy",
	"corfhp",
	"corplat",
	"corgantuw",
	"corsy",
	"lootboxnano_t1_var1",
	"lootboxnano_t1_var2",
	"lootboxnano_t1_var3",
	"lootboxnano_t1_var4",
	"lootboxnano_t1_var5",
	"lootboxnano_t1_var6",
	"lootboxnano_t1_var7",
	"lootboxnano_t1_var8",
	"lootboxnano_t1_var9",
	"lootboxnano_t2_var1",
	"lootboxnano_t2_var2",
	"lootboxnano_t2_var3",
	"lootboxnano_t2_var4",
	"lootboxnano_t2_var5",
	"lootboxnano_t2_var6",
	"lootboxnano_t2_var7",
	"lootboxnano_t2_var8",
	"lootboxnano_t2_var9",
	"lootboxnano_t3_var1",
	"lootboxnano_t3_var2",
	"lootboxnano_t3_var3",
	"lootboxnano_t3_var4",
	"lootboxnano_t3_var5",
	"lootboxnano_t3_var6",
	"lootboxnano_t3_var7",
	"lootboxnano_t3_var8",
	"lootboxnano_t3_var9",
	"lootboxnano_t4_var1",
	"lootboxnano_t4_var2",
	"lootboxnano_t4_var3",
	"lootboxnano_t4_var4",
	"lootboxnano_t4_var5",
	"lootboxnano_t4_var6",
	"lootboxnano_t4_var7",
	"lootboxnano_t4_var8",
	"lootboxnano_t4_var9",
}

local scavFactories = {}
for _, name in ipairs(factories) do
	table.insert(scavFactories, name .. scavconfig.unitnamesuffix)
end

for _, name in ipairs(scavFactories) do
	table.insert(factories, name)
end

local factoriesID = {}
for _, unitName in ipairs(factories) do
	local unitDefID = UnitDefNames[unitName].id
	factoriesID[unitDefID] = true
end

local factoryBannedUnits = {
	"armdfly_scav",
	"armatlas_scav",
	"corvalk_scav",
	"corseah_scav",
	"corthovr_scav",
	"armthovr_scav",
	"armtship_scav",
	"cortship_scav",
	"corintr_scav",
}

return {
	Factories = factories,
	FactoriesID = factoriesID,
	FactoryBannedUnits = factoryBannedUnits,
}