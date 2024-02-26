local function getUnitIDList(unitNameList)
	local unitDefIDList = {}
	for _, unitName in ipairs(unitNameList) do
		local unitDefID = UnitDefNames[unitName].id
		unitDefIDList[unitDefID] = true
	end

	return unitDefIDList
end

local constructors = {
	"armada_commander_scav",
	"cortex_commander_scav",
	"legcom_scav",
	"legcomoff_scav",
	"legcomt2def_scav",
	"legcomt2com_scav",
}

local constructorsT1 = {
	"armada_commander_scav",
	"cortex_commander_scav",
	"legcom_scav",
}

local constructorsT2 = {
	"armada_commander_scav",
	"cortex_commander_scav",
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
	[UnitDefNames["armada_commandercon_scav"].id] = "cortex_commander_scav",
	[UnitDefNames["cortex_commandercon_scav"].id] = "armada_commander_scav",
}

local swapUnitsFromScav = {
	[UnitDefNames["armada_commander_scav"].id] = "armada_commandercon_scav",
	[UnitDefNames["cortex_commander_scav"].id] = "cortex_commandercon_scav",
}


local playerCommanders = {
	"armada_commander",
	"cortex_commander",
	"armada_decoycommander",
	"cortex_decoycommander",
	"armada_commandercon",
	"cortex_commandercon",
	"armada_decoycommander_scav",
	"cortex_decoycommander_scav",
	"armada_commandercon_scav",
	"cortex_commandercon_scav",
	"armrespawn",
	"correspawn",
}

local assisters = {
	"armada_constructionturret_scav",
	"cortex_constructionturret_scav",
	"armada_navalconstructionturret_scav",
	"cortex_navalconstructionturret_scav",
	"armrespawn",
	"correspawn",
}

local resurrectors = {
	"armada_lazarus_scav",
	"cortex_graverobber_scav",
}

local resurrectorsSea = {
	"armada_lazarus_scav",
	"cortex_graverobber_scav",
}

local collectors = {
	"armada_constructionbot_scav",
	"armada_advancedconstructionbot_scav",
	"armada_decoycommander_scav",
	"armada_constructionvehicle_scav",
	"armada_beaver_scav",
	"armada_advancedconstructionvehicle_scav",
	"armada_constructionaircraft_scav",
	"armada_constructionseaplane_scav",
	"armada_advancedconstructionaircraft_scav",
	"armada_constructionship_scav",
	"armada_advancedconstructionsub_scav",
	"armada_constructionhovercraft_scav",
	"cortex_constructionbot_scav",
	"cortex_advancedconstructionbot_scav",
	"cortex_decoycommander_scav",
	"corcv_scav",
	"cormuskrat_scav",
	"coracv_scav",
	"cortex_constructionaircraft_scav",
	"cortex_constructionseaplane_scav",
	"cortex_advancedconstructionaircraft_scav",
	"cortex_constructionship_scav",
	"cortex_advancedconstructionsub_scav",
	"cortex_constructionhovercraft_scav",
	"cortex_twitcher_scav",
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