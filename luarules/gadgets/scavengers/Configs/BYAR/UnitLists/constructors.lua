local function getUnitIDList(unitNameList)
	local unitDefIDList = {}
	for _, unitName in ipairs(unitNameList) do
		local unitDefID = UnitDefNames[unitName].id
		unitDefIDList[unitDefID] = true
	end

	return unitDefIDList
end

local constructors = {
	"armcom_scav",
	"corcom_scav",
	"legcom_scav",
	"legcomoff_scav",
	"legcomt2def_scav",
	"legcomt2com_scav",
}

local constructorsT1 = {
	"armcom_scav",
	"corcom_scav",
	"legcom_scav",
}

local constructorsT2 = {
	"armcom_scav",
	"corcom_scav",
	"legcom_scav",
	"legcomoff_scav",
}

local constructorsT3 = {
	"legcomoff_scav",
	"legcomt2def_scav",
	"legcomt2com_scav",
}

local constructorsT4 = {
	"legcomoff_scav",
	"legcomt2def_scav",
	"legcomt2com_scav",
}

local swapUnitsToScav = {
	[UnitDefNames["armcomcon_scav"].id] = "corcom_scav",
	[UnitDefNames["corcomcon_scav"].id] = "armcom_scav",
}

local swapUnitsFromScav = {
	[UnitDefNames["armcom_scav"].id] = "armcomcon_scav",
	[UnitDefNames["corcom_scav"].id] = "corcomcon_scav",
}


local playerCommanders = {
	"armcom",
	"corcom",
	"armdecom",
	"cordecom",
	"armcomcon",
	"corcomcon",
	"armdecom_scav",
	"cordecom_scav",
	"armcomcon_scav",
	"corcomcon_scav",
	"armrespawn",
	"correspawn",
}

local assisters = {
	"armnanotc_scav",
	"cornanotc_scav",
	"armnanotcplat_scav",
	"cornanotcplat_scav",
	"armrespawn",
	"correspawn",
}

local resurrectors = {
	"armrectr_scav",
	"cornecro_scav",
}

local resurrectorsSea = {
	"armrectr_scav",
	"cornecro_scav",
}

local collectors = {
	"armck_scav",
	"armack_scav",
	"armdecom_scav",
	"armcv_scav",
	"armbeaver_scav",
	"armacv_scav",
	"armca_scav",
	"armcsa_scav",
	"armaca_scav",
	"armcs_scav",
	"armacsub_scav",
	"armch_scav",
	"corck_scav",
	"corack_scav",
	"cordecom_scav",
	"corcv_scav",
	"cormuskrat_scav",
	"coracv_scav",
	"corca_scav",
	"corcsa_scav",
	"coraca_scav",
	"corcs_scav",
	"coracsub_scav",
	"corch_scav",
	"corfast_scav",
	"armassistdrone_scav",
	"corassistdrone_scav",
}

local constructorsID = getUnitIDList(constructors)
local constructorsT1ID = getUnitIDList(constructorsT1)
local constructorsT2ID = getUnitIDList(constructorsT2)
local constructorsT3ID = getUnitIDList(constructorsT3)
local constructorsT4ID = getUnitIDList(constructorsT4)
local playerCommandersID = getUnitIDList(playerCommanders)
local assistersID = getUnitIDList(assisters)
local resurrectorsID = getUnitIDList(resurrectors)
local resurrectorsSeaID = getUnitIDList(resurrectorsSea)
local collectorsID = getUnitIDList(collectors)

return {
	Constructors = constructors,
	ConstructorsID = constructorsID,
	ConstructorsT1 = constructorsT1,
	ConstructorsT1ID = constructorsT1ID,
	ConstructorsT2 = constructorsT2,
	ConstructorsT2ID = constructorsT2ID,
	ConstructorsT3 = constructorsT3,
	ConstructorsT3ID = constructorsT3ID,
	ConstructorsT4 = constructorsT4,
	ConstructorsT4ID = constructorsT4ID,
	SwapUnitsToScav = swapUnitsToScav,
	SwapUnitsFromScav = swapUnitsFromScav,
	PlayerCommanders = playerCommanders,
	PlayerCommandersID = playerCommandersID,
	Assisters = assisters,
	AssistersID = assistersID,
	Resurrectors = resurrectors,
	ResurrectorsID = resurrectorsID,
	ResurrectorsSea = resurrectorsSea,
	ResurrectorsSeaID = resurrectorsSeaID,
	Collectors = collectors,
	CollectorsID = collectorsID,
}