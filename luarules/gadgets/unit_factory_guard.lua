
if not gadgetHandler:IsSyncedCode() then
	return
end


function gadget:GetInfo()
	return {
		name      = "Factory Guard",
		desc      = "Adds a factory guard state command to factories",
		author    = "Hobo Joe",
		date      = "Feb 2024",
		license   = "GNU GPL, v2 or later",
		layer     = 0,
		enabled   = true
	}
end


local spFindUnitCmdDesc    = Spring.FindUnitCmdDesc
local spInsertUnitCmdDesc  = Spring.InsertUnitCmdDesc
local spEditUnitCmdDesc    = Spring.EditUnitCmdDesc

include("luarules/configs/customcmds.h.lua")

local factoryGuardCmdDesc = {
	id = CMD_FACTORY_GUARD,
	type = CMDTYPE.ICON_MODE,
	tooltip = 'factoryguard_tooltip',
	name = 'factoryguard',
	cursor = 'cursornormal',
	action = 'factoryguard',
	params = { 0, "factoryguard", "factoryguard" }, -- named like this for translation - 0 is off, 1 is on
}


local isFactory = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.isFactory then
		local buildOptions = unitDef.buildOptions

		for i = 1, #buildOptions do
			local boDefID = buildOptions[i]
			local bod = UnitDefs[boDefID]

			if (bod and bod.isBuilder and bod.canAssist) then
				isFactory[unitDefID] = true  -- only factories that can build builders are included
				break
			end
		end
	end
end


local function setFactoryGuardState(unitID, state)
	Spring.Echo("setting guard state for " .. unitID .. " to", state)
	local cmdDescID = spFindUnitCmdDesc(unitID, CMD_FACTORY_GUARD)
	if cmdDescID then
		factoryGuardCmdDesc.params[1] = state
		spEditUnitCmdDesc(unitID, cmdDescID, {params = factoryGuardCmdDesc.params})
	end
end


function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions)
	if cmdID == CMD_FACTORY_GUARD and isFactory[unitDefID] then
		setFactoryGuardState(unitID, cmdParams[1])
		return false  -- command was used
	end
	return true  -- command was not used
end

--------------------------------------------------------------------------------
-- Unit Handling

function gadget:UnitCreated(unitID, unitDefID, _)
	if isFactory[unitDefID] then
		factoryGuardCmdDesc.params[1] = 0
		spInsertUnitCmdDesc(unitID, factoryGuardCmdDesc)
	end
end

function gadget:Initialize()
	Spring.Echo("factory guard widget enabled")
	for _, unitID in ipairs(Spring.GetAllUnits()) do
		gadget:UnitCreated(unitID, Spring.GetUnitDefID(unitID))
	end
end
--------------------------------------------------------------------------------
