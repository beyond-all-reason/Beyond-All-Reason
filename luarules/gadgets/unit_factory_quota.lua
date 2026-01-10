if not gadgetHandler:IsSyncedCode() then
	return
end

local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name      = "Factory Quotas",
		desc      = "Adds a queue mode toggle to factories",
		author    = "hihoman23",
		date      = "Aug 2024",
		license   = "GNU GPL, v2 or later",
		layer     = 0,
		enabled   = true
	}
end

local SpringFindUnitCmdDesc = Spring.FindUnitCmdDesc
local SpringEditUnitCmdDesc = Spring.EditUnitCmdDesc
local SpringInsertUnitCmdDesc = Spring.InsertUnitCmdDesc
local SpringGetAllUnits = Spring.GetAllUnits
local SpringGetUnitDefID = Spring.GetUnitDefID

local CMD_QUOTA_BUILD_TOGGLE = GameCMD.QUOTA_BUILD_TOGGLE

local isFactory = {}
for unitDefID, unitDef in pairs(UnitDefs) do
    isFactory[unitDefID] = unitDef.isFactory
end

local factoryQuotaCmdDesc = {
	id = CMD_QUOTA_BUILD_TOGGLE,
	type = CMDTYPE.ICON_MODE,
	tooltip = 'factoryqueuemode_tooltip',
	name = 'Factory Queue Mode',
	cursor = 'cursornormal',
	action = 'factoryqueuemode',
	params = { 0, "factoryqueuemode_normal", "factoryqueuemode_quota" }, -- named like this for translation - 0 is off, 1 is on
}

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions)
	-- accepts: CMD_QUOTA_BUILD_TOGGLE
	if isFactory[unitDefID] then
        local cmdDescID = SpringFindUnitCmdDesc(unitID, CMD_QUOTA_BUILD_TOGGLE)
        if cmdDescID then
            factoryQuotaCmdDesc.params[1] = cmdParams[1]
            SpringEditUnitCmdDesc(unitID, cmdDescID, {params = factoryQuotaCmdDesc.params})
        end
		return false  -- command was used
	end
	return true  -- command was not used
end

function gadget:UnitCreated(unitID, unitDefID, _)
	if isFactory[unitDefID] then
		factoryQuotaCmdDesc.params[1] = 0
		SpringInsertUnitCmdDesc(unitID, factoryQuotaCmdDesc)
	end
end

function gadget:Initialize()
	gadgetHandler:RegisterAllowCommand(CMD_QUOTA_BUILD_TOGGLE)
	local allUnits = SpringGetAllUnits()
	for i = 1, #allUnits do
		local unitID = allUnits[i]
		gadget:UnitCreated(unitID, SpringGetUnitDefID(unitID))
	end
end
