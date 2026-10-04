local gadget = gadget ---@type Gadget

function gadget:GetInfo()
    return {
        name      = "Resurrection Behavior",
        desc      = "Handles starting health, wait until repair, and transferring oldUnit > corpse > newUnit data.",
        author    = "Floris, Chronographer, SethDGamre",
        date      = "4 November 2025",
        license   = "GNU GPL, v2 or later",
        layer     = 5, -- FIXME why?
        enabled   = true
    }
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

local CMD_RESURRECT = CMD.RESURRECT
local CMD_WAIT = CMD.WAIT
local CMD_FIRE_STATE = CMD.FIRE_STATE
local CMD_MOVE_STATE = CMD.MOVE_STATE
local VISIBILITY_INLOS = {inlos = true}
local UPDATE_INTERVAL = Game.gameSpeed
local TIMEOUT_FRAMES = Game.gameSpeed * 3 -- long enough to get grabbed by FeatureCreated callback

local spGetUnitHealth = Spring.GetUnitHealth
local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spGetUnitCurrentCommand = Spring.GetUnitCurrentCommand
local spGetFeatureRulesParam = Spring.GetFeatureRulesParam
local spSetFeatureRulesParam = Spring.SetFeatureRulesParam

local shouldWaitForHealing = {}
local toBeUnWaited = {}
local prevHealth = {}
local priorStates = {} -- unitID = { timeout, firestate, movestate, xp }

for unitDefID, unitDef in pairs(UnitDefs) do
	shouldWaitForHealing[unitDefID] = (not unitDef.isBuilding) and (not unitDef.isBuilder)
end

local function RestoreStateMechanics(unitID, featureID)
	Spring.SetUnitExperience(unitID, spGetFeatureRulesParam(featureID, "previous_xp") or 0)
end

local function RestoreStateGUI(unitID, featureID)
	local firestate = spGetFeatureRulesParam(featureID, "previous_firestate")
	if firestate then
		spGiveOrderToUnit(unitID, CMD_FIRE_STATE, firestate, 0)
	end

	local movestate = spGetFeatureRulesParam(featureID, "previous_movestate")
	if movestate then
		spGiveOrderToUnit(unitID, CMD_MOVE_STATE, movestate, 0)
	end
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	if not builderID then
		return
	end

	local cmdID, featureID = Spring.GetUnitWorkerTask(builderID)
	if cmdID ~= CMD_RESURRECT then
		return
	end
	if not Engine.FeatureSupport.noOffsetForFeatureID then
		featureID = featureID - Game.maxUnits
	end

	-- Wait combat units so they don't wander off before they get repaired
	if shouldWaitForHealing[unitDefID] then
		toBeUnWaited[unitID] = true
		prevHealth[unitID] = 0
		spGiveOrderToUnit(unitID, CMD_WAIT, 0, 0)
	end

	-- FIXME: 1 -> true (0 is truthy in lua too), but would need to be fixed elsewhere as well
	Spring.SetUnitRulesParam(unitID, "resurrected", 1, VISIBILITY_INLOS)

	Spring.SetUnitHealth(unitID, spGetUnitHealth(unitID) * 0.05)

	RestoreStateMechanics(unitID, featureID)

	-- Don't retain GUI settings (movestate etc) from other players
	if Spring.GetFeatureTeam(featureID) == Spring.GetUnitTeam(unitID) then
		RestoreStateGUI(unitID, featureID)
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam)
	local states = Spring.GetUnitStates(unitID)
	priorStates[unitID] = {
		timeout = Spring.GetGameFrame() + TIMEOUT_FRAMES,
		firestate = states.firestate,
		movestate = states.movestate,
		xp = Spring.GetUnitExperience(unitID)
	}
end

function gadget:FeatureCreated(featureID, _, sourceID)
	if not sourceID then
		return
	end

	local states = priorStates[sourceID]
	if not states then
		return
	end

	spSetFeatureRulesParam(featureID, "previous_firestate", states.firestate)
	spSetFeatureRulesParam(featureID, "previous_movestate", states.movestate)
	spSetFeatureRulesParam(featureID, "previous_xp", states.xp)
end

function gadget:GameFrame(frame)
	if frame % UPDATE_INTERVAL ~= 0 then
		return
	end

	for unitID, state in pairs(priorStates) do
		if state.timeout < frame then
			priorStates[unitID] = nil
		end
	end

	if next(toBeUnWaited) ~= nil then
		for unitID, check in pairs(toBeUnWaited) do
			local health = spGetUnitHealth(unitID)
			if not health then
				toBeUnWaited[unitID] = nil
				prevHealth[unitID] = nil
			elseif health <= prevHealth[unitID] then -- stopped healing
				toBeUnWaited[unitID] = nil
				prevHealth[unitID] = nil
				local currentCmdID = spGetUnitCurrentCommand(unitID)
				if currentCmdID == CMD_WAIT then
					spGiveOrderToUnit(unitID, CMD_WAIT, 0, 0)
				end
			else
				prevHealth[unitID] = health
			end
		end
	end
end