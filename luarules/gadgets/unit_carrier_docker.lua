
if (not gadgetHandler:IsSyncedCode()) then
	return false
end

function gadget:GetInfo()
	return {
		name = "Unit Carrier Docker",
 		desc = "Handles docking for carrier units",
		author = "Xehrath, Inspiration taken from zeroK carrier authors: TheFatConroller, KingRaptor",
		date = "2023-03-15",
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


local mcSetVelocity         = Spring.MoveCtrl.SetVelocity
local mcSetPosition         = Spring.MoveCtrl.SetPosition

local mapsizeX 				  = Game.mapSizeX
local mapsizeZ 				  = Game.mapSizeZ

local random = math.random
local math_min = math.min
local sin    = math.sin
local cos    = math.cos

local GAME_SPEED = Game.gameSpeed


GG.carrierActiveDockingList = {} -- [index] = {.spawnDef, .teamID, .x, .y, .z, .ownerID}, subtables reused
GG.carrierAvailableDockingCount = 1000
GG.dockingQueueOffset = 0



local DEFAULT_DOCK_CHECK_FREQUENCY = 10--13 -- gameframes


local coroutine = coroutine
local Sleep     = coroutine.yield
local assert    = assert

local coroutines = {}

local spUnitAttach = Spring.UnitAttach  --can attach to  specific pieces using pieceID
local spUnitDetach = Spring.UnitDetach


local function GetDistance(x1, x2, y1, y2)
	if x1 and x2 then
		return ((x1-x2)^2 + (y1-y2)^2)^0.5
	else
		return
	end
end

local function GetDirectionalVector(speed, x1, x2, y1, y2, z1, z2)
	local magnitude
	local vx, vy, vz
	if z1 then
		vx, vy, vz = x2-x1, y2-y1, z2-z1
		magnitude = ((vx)^2 + (vy)^2 + (vz)^2)^0.5
		return speed*vx/magnitude, speed*vy/magnitude, speed*vz/magnitude
	else
		vx, vy = x2-x1, y2-y1
		magnitude = ((vx)^2 + (vy)^2)^0.5
		return speed*vx/magnitude, speed*vy/magnitude
	end
end


local function StartScript(fn)
	local co = coroutine.create(fn)
	coroutines[#coroutines + 1] = co
end

local function UpdateCoroutines()
	local newCoroutines = {}
	for i=1, #coroutines do
		local co = coroutines[i]
		if (coroutine.status(co) ~= "dead") then
			newCoroutines[#newCoroutines + 1] = co
		end
	end
	coroutines = newCoroutines
	for i=1, #coroutines do
		assert(coroutine.resume(coroutines[i]))
	end
end




local function DockUnits(dockingqueue, queuestart, queueend)
	for i = queuestart, queueend do
		local unitID = dockingqueue[i].ownerID
		local subUnitID = dockingqueue[i].subunitID
		local subunitDefID	= spGetUnitDefID(subUnitID)
		local subunitDef = UnitDefs[subunitDefID]
		local ox, oy, oz = spGetUnitPosition(unitID)
		local subx, suby, subz = spGetUnitPosition(subUnitID)
		local dockingSnapRange


		if unitID and subUnitID and GG.carrierMetaList[unitID] then
			
			if GG.carrierMetaList[unitID].subUnitsList[subUnitID] then
				if GG.carrierMetaList[unitID].subUnitsList[subUnitID].dockingPiece then
					local pieceNumber = GG.carrierMetaList[unitID].subUnitsList[subUnitID].dockingPiece
					--local distance = GetDistance(ox, subx, oz, subz)
						local function LandLoop()
							if not GG.carrierMetaList[unitID] then
								return
							elseif not GG.carrierMetaList[unitID].subUnitsList[subUnitID] then
								return
							end
							while not GG.carrierMetaList[unitID].subUnitsList[subUnitID].docked do
			
								local px, py, pz = Spring.GetUnitPiecePosDir(unitID, pieceNumber)
								
			
			
								ox, oy, oz = spGetUnitPosition(unitID)
								subx, suby, subz = spGetUnitPosition(subUnitID)
								local distance = GetDistance(px, subx, pz, subz)
								local heightDifference = GetDistance(py, suby, 0, 0)
								
			
								
								if not distance then
									return
								end
								if distance < 25 and subunitDef.isAirUnit then
									local landingspeed = GG.carrierMetaList[unitID].dockHelperSpeed
									if 0.2*heightDifference > landingspeed then
										landingspeed = 0.2*heightDifference
									end
									local vx, vy, vz = GetDirectionalVector(landingspeed, subx, px, suby, py, subz, pz)
									spSetUnitVelocity(subUnitID, vx, vy, vz)
			
								elseif distance < GG.carrierMetaList[unitID].dockRadius then
									local vx, vy, vz = GetDirectionalVector(GG.carrierMetaList[unitID].dockHelperSpeed, subx, px, suby, py, subz, pz)
									Spring.MoveCtrl.Enable(subUnitID)
									mcSetPosition(subUnitID, subx+vx, suby, subz+vz)
									Spring.MoveCtrl.Disable(subUnitID)
									spSetUnitVelocity(subUnitID, vx, 0, vz)
									heightDifference = 0
			
								else
									spGiveOrderToUnit(subUnitID, CMD.STOP, {}, 0)
									spGiveOrderToUnit(subUnitID, CMD.MOVE, {px, py, pz}, 0)
								end
			
								
								GG.carrierMetaList[unitID].activeDocking = true
								if GG.carrierMetaList[unitID].dockHelperSpeed == 0 then
									dockingSnapRange = GG.carrierMetaList[unitID].dockRadius
								else
									dockingSnapRange = GG.carrierMetaList[unitID].dockHelperSpeed
								end
							
			
								if distance < dockingSnapRange and heightDifference < dockingSnapRange and GG.carrierMetaList[unitID].subUnitsList[subUnitID].docked ~= true then
									spUnitAttach(unitID, subUnitID, pieceNumber)
									spGiveOrderToUnit(subUnitID, CMD.STOP, {}, 0)
									Spring.MoveCtrl.Disable(subUnitID)
									spSetUnitVelocity(subUnitID, 0, 0, 0)
									SetUnitNoSelect(subUnitID, true)
									GG.carrierMetaList[unitID].subUnitsList[subUnitID].docked = true
									GG.carrierMetaList[unitID].subUnitsList[subUnitID].activeDocking = false
									if GG.carrierMetaList[unitID].dockArmor then
										spSetUnitArmored(subUnitID, true, GG.carrierMetaList[unitID].dockArmor)
									end
								end
			
								Sleep()
								if not GG.carrierMetaList[unitID] then
									return
								elseif not GG.carrierMetaList[unitID].subUnitsList[subUnitID] then
									return
								end
							end
						end
			
						StartScript(LandLoop)
		
				end
			end
		end
	end
end



function gadget:GameFrame(f)
	UpdateCoroutines()
	if f % GAME_SPEED ~= 0 then
		return
	end



	if ((f % DEFAULT_DOCK_CHECK_FREQUENCY) == 0) then
		if GG.carrierQueuedDockingCount > 0 then -- Initiate docking for units in the docking queue and reset the queue.
			local availableDockingCount = (GG.carrierAvailableDockingCount-#coroutines)
			local carrierActiveDockingList = {}
			local carrierDockingCount = 0
			if (GG.carrierQueuedDockingCount - GG.dockingQueueOffset) > availableDockingCount then 
				carrierActiveDockingList = GG.carrierDockingList
				DockUnits(carrierActiveDockingList, (GG.dockingQueueOffset+1), (GG.dockingQueueOffset+availableDockingCount))
				GG.dockingQueueOffset = GG.dockingQueueOffset+availableDockingCount
			else
				carrierActiveDockingList = GG.carrierDockingList
				carrierDockingCount = GG.carrierQueuedDockingCount
				GG.carrierQueuedDockingCount = 0
				DockUnits(carrierActiveDockingList, (GG.dockingQueueOffset+1), carrierDockingCount)
				GG.dockingQueueOffset = 0
			end
		end
	end

end







