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
}

local playerCommanders = {
	"armcom",
	"corcom",
	"armdecom",
	"cordecom",
	"armcomcon",
	"corcomcon",
}

local assisters = {
	"armnanotc_scav",
	"cornanotc_scav",
	"armnanotcplat_scav",
	"cornanotcplat_scav",
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
	"armrectrt4_scav",
	"armassistdrone",
	"corassistdrone",
}

local constructorsID = getUnitIDList(constructors)
local playerCommandersID = getUnitIDList(playerCommanders)
local assistersID = getUnitIDList(assisters)
local resurrectorsID = getUnitIDList(resurrectors)
local resurrectorsSeaID = getUnitIDList(resurrectorsSea)
local collectorsID = getUnitIDList(collectors)

return {
	Constructors = constructors,
	ConstructorsID = constructorsID,
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