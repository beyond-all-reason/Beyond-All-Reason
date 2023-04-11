
if (gadgetHandler:IsSyncedCode()) then

function gadget:GetInfo()
	return {
		name = "Unit Evolution",
		desc = "Evolves a unit permanently into another unit when certain criteria are met",
		author = "Xehrath",
		date = "2023-03-31",
		license = "None",
		layer = 50,
		enabled = true
	}
end

local spCreateFeature         = Spring.CreateFeature
local spCreateUnit            = Spring.CreateUnit
local spDestroyUnit           = Spring.DestroyUnit
local spGetGameFrame          = Spring.GetGameFrame
local spGetProjectileDefID    = Spring.GetProjectileDefID
local spGetProjectileTeamID   = Spring.GetProjectileTeamID
local spGetUnitShieldState    = Spring.GetUnitShieldState
local spGiveOrderToUnit       = Spring.GiveOrderToUnit
local spSetFeatureDirection   = Spring.SetFeatureDirection
local spSetUnitRulesParam     = Spring.SetUnitRulesParam
local spGetUnitPosition       = Spring.GetUnitPosition
local SetUnitNoSelect         = Spring.SetUnitNoSelect
local spGetUnitRulesParam = Spring.GetUnitRulesParam
local spUseTeamResource = Spring.UseTeamResource --(teamID, "metal"|"energy", amount) return nil | bool hadEnough
local spGetTeamResources = Spring.GetTeamResources --(teamID, "metal"|"energy") return nil | currentLevel
local GetCommandQueue     = Spring.GetCommandQueue
local spSetUnitArmored = Spring.SetUnitArmored
local spGetUnitStates = Spring.GetUnitStates
local spGetUnitBasePosition = Spring.GetUnitBasePosition
local spGetUnitDefID        = Spring.GetUnitDefID
local spSetUnitVelocity     = Spring.SetUnitVelocity
local spGetUnitHeading      = Spring.GetUnitHeading
local spGetUnitVelocity     = Spring.GetUnitVelocity
local spGetUnitHealth 		= Spring.GetUnitHealth

local spGetUnitExperience	= Spring.GetUnitExperience
local spGetUnitTeam 		= Spring.GetUnitTeam
local spGetUnitDirection 	= Spring.GetUnitDirection
local spGetUnitStockpile 	= Spring.GetUnitStockpile
local spGetUnitCommands = Spring.GetUnitCommands
local spEcho = Spring.Echo
local spSetUnitHealth = Spring.SetUnitHealth

local spSetUnitExperience = Spring.SetUnitExperience
local spSetUnitStockpile = Spring.SetUnitStockpile
local spSetUnitDirection = Spring.SetUnitDirection
local spGetGameSeconds = Spring.GetGameSeconds
local spGetUnitNearestEnemy = Spring.GetUnitNearestEnemy


local mcSetVelocity         = Spring.MoveCtrl.SetVelocity
local mcSetPosition         = Spring.MoveCtrl.SetPosition

local mapsizeX 				  = Game.mapSizeX
local mapsizeZ 				  = Game.mapSizeZ

local random = math.random
local math_min = math.min
local sin    = math.sin
local cos    = math.cos

local GAME_SPEED = Game.gameSpeed
local TAU = 2 * math.pi
local PRIVATE = { private = true }
local CMD_WAIT = CMD.WAIT
local EMPTY_TABLE = {}

local noCreate = false

local spawnDefs = {}
local shieldCollide = {}
local wantedList = {}

local spawnList = {} -- [index] = {.spawnDef, .teamID, .x, .y, .z, .ownerID}, subtables reused
local spawnCount = 0


GG.carrierDockingList = {} -- [index] = {.spawnDef, .teamID, .x, .y, .z, .ownerID}, subtables reused
GG.carrierQueuedDockingCount = 0
local previousHealFrame = 0


local evolutionMetaList = {}
GG.droneMetaList = {}


local TIMER_CHECK_FREQUENCY = 30 -- gameframes


local coroutine = coroutine
local Sleep     = coroutine.yield
local assert    = assert



--TEMPORARY
local healcount = 0
local heallist = {}
local totalDroneCount = 0

-- ZECRUS, values can be tuned in the unitdef file. Add the section below to the unitdef list in the unitdef file.
--customparams = {
	--	-- Required:				
	-- evolution_target = "unitname"    Name of the unit this unit will evolve into. 
	
	
	--	-- Optional:
	-- evolution_announcement = "Unit Evolved",  Announcement printed when the unit is evolved. Currently using the Spring.Echo function.
	
	--	-- Has a default value, as indicated, if not chosen:
	-- evolution_condition = "timer"    condition type for the evolution. 
	-- evolution_timer = 600, 			set the timer used for the timer condition. Given in secons from when the unit was created. 
	-- combatRadius = 1000,				Range for setting in-combat status if enemies are within range, and disabling evolution while in-combat. 
	
	
	-- },							 









function Evolve(unitID, newUnit)
	local health = spGetUnitHealth(unitID)
	local experience = spGetUnitExperience(unitID)
	local x,y,z = spGetUnitPosition(unitID)
	local team = spGetUnitTeam(unitID)
	local states = spGetUnitStates(unitID)
	local dx, dy, dz = spGetUnitDirection(unitID)
	local stockpile, stockpilequeued, stockpilebuildpercent = spGetUnitStockpile(unitID)
	local commandQueue = spGetUnitCommands(unitID, -1)

	--commandQueue[1].id
	--commandQueue[1].params
	--commandQueue[1].options

	if evolutionMetaList[unitID].evolution_announcement then
		spEcho(evolutionMetaList[unitID].evolution_announcement)
	end

	spSetUnitRulesParam(unitID, "disable_tombstone", "disabled", PRIVATE)
	
	local newUnitID = spCreateUnit(newUnit, x,y,z, 0, team)
	SendToUnsynced("unit_evolve_finished", unitID, newUnitID)
	spDestroyUnit(unitID, false, true)
	spSetUnitHealth(newUnitID, health)
	spSetUnitExperience(newUnitID, experience)
	spSetUnitStockpile(newUnitID, stockpile, stockpilebuildpercent)
	spSetUnitDirection(newUnitID, dx, dy, dz)

	if commandQueue[1] then
		for _,command in pairs(commandQueue) do
			spGiveOrderToUnit(newUnitID, command.id, command.params, command.options)
		end
	end
	

    spGiveOrderToUnit(newUnitID, CMD.FIRE_STATE, { states.firestate },             { })
    spGiveOrderToUnit(newUnitID, CMD.MOVE_STATE, { states.movestate },             { })
    spGiveOrderToUnit(newUnitID, CMD.REPEAT,     { states["repeat"] and 1 or 0 },  { })
    spGiveOrderToUnit(newUnitID, CMD.CLOAK,      { states.cloak     and 1 or 0 },  { })
    spGiveOrderToUnit(newUnitID, CMD.ONOFF,      { 1 },                            { })
    spGiveOrderToUnit(newUnitID, CMD.TRAJECTORY, { states.trajectory and 1 or 0 }, { })
  	


	
end


function gadget:UnitCreated(unitID, unitDefID, unitTeam)
	local udcp = UnitDefs[unitDefID].customParams

	if udcp.evolution_target then
		evolutionMetaList[unitID] = {
			evolution_target = udcp.evolution_target,
			evolution_condition = udcp.evolution_condition or "timer",
			evolution_timer = tonumber(udcp.evolution_timer) or 600,
			evolution_announcement = udcp.evolution_announcement,
			combatRadius = tonumber(udcp.combatRadius) or 1000,


			timeCreated = spGetGameSeconds(),
			combatTimer = spGetGameSeconds(),
			inCombat = false,
		}
	end
end

function gadget:UnitCommand(unitID, unitDefID, unitTeamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua)



	if evolutionMetaList[unitID] and (cmdID == CMD.STOP) then
		Evolve(unitID, evolutionMetaList[unitID].evolution_target)
	end
end

function gadget:UnitDestroyed(unitID)

	if evolutionMetaList[unitID] then
		evolutionMetaList[unitID] = nil
	end

end




function gadget:GameFrame(f)
	if f % GAME_SPEED ~= 0 then
		return
	end



	if ((f % TIMER_CHECK_FREQUENCY) == 0) then
		for unitID, _ in pairs(evolutionMetaList) do
			local currentTime =  spGetGameSeconds()
			if evolutionMetaList[unitID].evolution_condition == "timer" and (currentTime-evolutionMetaList[unitID].timeCreated) >= evolutionMetaList[unitID].evolution_timer then
				local enemyNearby = spGetUnitNearestEnemy(unitID, evolutionMetaList[unitID].combatRadius)
				local inCombat = false
				if enemyNearby then
					inCombat = true
					evolutionMetaList[unitID].combatTimer = spGetGameSeconds()
				end

				if not inCombat and (currentTime-evolutionMetaList[unitID].combatTimer) >= 5 then
					Evolve(unitID, evolutionMetaList[unitID].evolution_target)
				end
			end
		end
	end
end




else


local spSelectUnitArray = Spring.SelectUnitArray
local spGetSelectedUnits = Spring.GetSelectedUnits


local function SelectSwap(cmd, oldID, newID)
	local selUnits = spGetSelectedUnits()
	for i=1,#selUnits do
	  local unitID = selUnits[i]
	  if (unitID == oldID) then
		selUnits[i] = newID
		spSelectUnitArray(selUnits)
		break
	  end
	end
end

function gadget:Initialize()
	gadgetHandler:AddSyncAction("unit_evolve_finished", SelectSwap)

end

function gadget:Shutdown()
	gadgetHandler:RemoveSyncAction("unit_evolve_finished")
end

end