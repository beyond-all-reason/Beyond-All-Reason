
local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name      = "Seismic Dots and Advanced Radar",
		desc      = "When in Seismic LOS, reveal a wobbling radar dot. And allow for custom wobble if in LOS of an advanced radar",
		author    = "Kyle Anthony Shepherd (Itanthias)",
		date      = "Aug 7, 2025",
		license   = "GNU GPL, v2 or later, and anyone who uses this gadget has to email me a rabbit with a sword at kyleanthonyshepherd@gmail.com",
		layer     = -1, -- to run after most gadgets have handled their stuff
		enabled   = Spring.GetModOptions().sensor_rework
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

local mRandom = math.random
local mSqrt = math.sqrt
local mFloor = math.floor
local mCos = math.cos
local mSin = math.sin
local mMax = math.max
local mMin = math.min

local unitCounter = 0

local spGetUnitAllyTeam = Spring.GetUnitAllyTeam
local spGetUnitPosition = Spring.GetUnitPosition
local spTraceRayGroundBetweenPositions = Spring.TraceRayGroundBetweenPositions
local spIsUnitInRadar = Spring.IsUnitInRadar
local spSetUnitLosState = Spring.SetUnitLosState
local spSetUnitLosMask = Spring.SetUnitLosMask
local spGetGameFrame = Spring.GetGameFrame
local spSetUnitPosErrorParams = Spring.SetUnitPosErrorParams
local spGetUnitPosErrorParams = Spring.GetUnitPosErrorParams
local spGetUnitIsStunned = Spring.GetUnitIsStunned
local spSetUnitSeismicSignature = Spring.SetUnitSeismicSignature
local scriptDelayByFrames = Script.DelayByFrames

-- Golden Ratio/Angle magic
-- This is my overengineered solution to prevent statistical "runs"
-- of identical wobble locations that occur with standard use of RNG.
-- We choose the next location of the wobble based on the Golden Angle, the "most irrational" number
-- To remove any clockwise rotation bias, on each wobble advance a random number of Golden Angle "steps", from a small set of possible "steps", the set selected to:
-- A. Average to approximately 180 degree rotation per wobble
-- B. Rotate more than 90 degrees per step
-- https://github.com/beyond-all-reason/Beyond-All-Reason/pull/5693#discussion_r2296246178
local goldenAngle = (2-(1 + math.sqrt(5))/2)*math.pi*2
local goldenSteps = {1,4,7,9,12,14}
-- cache sin and cos calcs for wobble rotation
local mathSinCache = {}
for ix = 1, #goldenSteps do
    mathSinCache[ix] = mSin(goldenSteps[ix]*goldenAngle)
end
local mathCosCache = {}
for ix = 1, #goldenSteps do
    mathCosCache[ix] = mCos(goldenSteps[ix]*goldenAngle)
end

-- hyperparameter for wobble drift time for seismic dots, in slowUpdates (15 frame increments)
-- 4 seems like reasonable minimum (2 second drift time), any faster looks weird to me.
-- 15 is the drift time of standard radar wobble. Seismic is desired to wobble as fast or faster than radar, so this is a reasonable max drift time.  
local minRandDriftTime = 4
local maxRandDriftTime = 4 --15

-- How long a seismic dot should last after last seismic ping, in frames
-- (after target leaves seismic range or stops moving)
local seismicDotTime = 2 * Game.gameSpeed

-- controls how often units search for advanced radars while in enemy radar
local basicRadarUpdateRate = 2 * Game.gameSpeed

-- controls drift time of radar dots in advanced radar, and when to re-check for advanced radars
local advancedRadarUpdateRate = 7.5 * Game.gameSpeed

-- individual unit value caches
local unitSpeeds = {}
local unitAllyTeamCache = {}
local unitInEnemyRadar = {}
local unitInSeismic = {}
local unitPendingWobble = {}
local advancedRadars = {}

-- cache UnitDefs at start
local unitDefSpeeds = {}
local unitDefSeismicSignature = {}
local unitDefRadarEmitHeight = {}
local unitDefRadarRadius = {}
local unitDefWobbleRatio = {}
local unitDefIsHover = {}
for unitDefID, unitDef in pairs(UnitDefs) do

	unitDefSpeeds[unitDefID] = UnitDefs[unitDefID].speed
	unitDefSeismicSignature[unitDefID] = UnitDefs[unitDefID].seismicSignature

	if UnitDefs[unitDefID].customParams then
		if UnitDefs[unitDefID].customParams.advancedradarwobbleratio ~= nil then
			unitDefRadarEmitHeight[unitDefID] = UnitDefs[unitDefID].radarEmitHeight
			unitDefRadarRadius[unitDefID] = mMax(UnitDefs[unitDefID].radarRadius,UnitDefs[unitDefID].sonarRadius)
			unitDefWobbleRatio[unitDefID] = UnitDefs[unitDefID].customParams.advancedradarwobbleratio
		end
	end

	if unitDef.moveDef.smClass == Game.speedModClasses.Hover then --units must have "hover" in their movedef name in order to be treated as hovercraft
		unitDefIsHover[unitDefID] = true
	end

end

-- Spring.X caches, as it is expected these functions may be called on the same unitID many times in 1 sim frame
local unitIsStunnedCache = {}
local function spGetUnitIsStunnedCache(unitID)
	if unitIsStunnedCache[unitID] == nil then
		unitIsStunnedCache[unitID] = spGetUnitIsStunned(unitID)
	end
	return unitIsStunnedCache[unitID]
end

local unitPositionCache = {}
local function spGetUnitPositionCache(unitID)
	if unitPositionCache[unitID] == nil then
		unitPositionCache[unitID] = {spGetUnitPosition(unitID, true)}
	end
	return unpack(unitPositionCache[unitID])	
end

local function tableLen(table) -- Because Lua is dumb and determining the number of entries of a table requires looping over it
	local count = 0
	for _ in pairs(table) do count = count + 1 end
	return count
end

-- If I understand CGame::SimFrame() correctly,
-- First, UpdatePreFrame events happens
-- then script.DelayByFrames functions happen, immediately before eventHandler.GameFrame [gadget:GameFrame] happens
-- then rest of synced game logic happens [Which makes the below callins happen]
-- then GameFramePost happens
local function customWobble(unitID)
	-- So, SetUnitPosErrorParams is on a *Per Unit* basis, and *every* team in the game sees the same radar dot position.
	-- [Technically, the same radar dot Angle, and the distance from true unit center is scaled based on the number of pinpointers on the team]
	-- Which means, we cannot show "low wobble" to team A and "high wobble" to team C at the same time.
	-- Therefore, until deeper engine changes are made, the "radar wobble" of a unit will be based on the "best" radar of all enemy teams that is painting the unit
	-- So, a unit on team B in advanced radar via Team A, but in seismic in Team C, will exhibit low wobble to *both* teams
	-- Should only be seen in FFA and other formats with more than 2 teams.

	-- first, check if the unit is in any enemy radar
	if (unitInEnemyRadar[unitID] == nil) then
		return 0
	end

	if (tableLen(unitInEnemyRadar[unitID]) == 0) then
		-- do NOT spin up a scriptDelayByFrames. When unit re-enters radar a new customWobble will be spun up
		return 0
	end

	-- then, check if this is the "correct" customWobble function to run.
	-- Currently, there is no way to "signal-kill" a pending DelayByFrames function, so we want to make sure only one customWobble is spun up for each unit
	if unitPendingWobble[unitID] ~= spGetGameFrame() then
		return 0
	end

	-- then, determine if the unit is in enemy advanced radar
	local unitAllyTeam = unitAllyTeamCache[unitID]
	local unitPointX, unitPointY, unitPointZ = spGetUnitPosition(unitID) -- use basepoint as radar "paints" the ground
	local wobbleRadiusFraction = 1

	Spring.Echo("checking arads")
	for advancedRadar, tableValues in pairs(advancedRadars) do
		local a,b,c,d,e = Spring.GetUnitHealth (advancedRadar)
		Spring.Echo(a,b,c,d,e)
		local stunned_or_inbuild = spGetUnitIsStunnedCache(advancedRadar)
		Spring.Echo("stunned_or_inbuild",stunned_or_inbuild)
		if (stunned_or_inbuild == false and unitAllyTeam ~= unitAllyTeamCache[advancedRadar]) then
			Spring.Echo("checking arad dist")
			-- check if the unit is within cylinder distance of the radar
			local basePointX, basePointY, basePointZ, midPointX, midPointY, midPointZ = spGetUnitPositionCache(advancedRadar)
			local dist2Dsq = (basePointX-unitPointX)^2 + (basePointZ-unitPointZ)^2
			if ((tableValues.radarRadius+unitSpeeds[unitID])^2 >= dist2Dsq) then
				Spring.Echo("checking arad ray")
				-- +unitspeed on radarRadius to help catch units just walking into radar range, it seems unitspeed is accounted for when determining when to trigger UnitEnteredRadar
				local raylength,_,_,_ = spTraceRayGroundBetweenPositions(basePointX, midPointY+tableValues.radarEmitHeight, basePointZ, unitPointX, unitPointY + 5, unitPointZ, false)
				-- use midPointY to match engine, `const float losHeight  = std::max(unit->midPos.y + emitHeight, 0.0f);`
				-- +5 on unitPointY to match engine `constexpr float LOS_BONUS_HEIGHT = 5.0f;`
				if raylength == nil then -- returns nil if no ground collision detected
					Spring.Echo("wobbleRatio",tableValues.wobbleRatio)
					wobbleRadiusFraction = mMax(0.0000152587890625,mMin(wobbleRadiusFraction,tableValues.wobbleRatio))
					-- arbitrary declare smallest possible wobbleRadiusFraction = 1/2^16 [so that a zero-vector is not created]
				end
			end
		end
	end

	if (wobbleRadiusFraction == 1 and tableLen(unitInSeismic[unitID]) == 0) then
		-- Case no fancy wobble, just let engine use default behavior
		local delay = mMax(basicRadarUpdateRate,mFloor(225*unitCounter/32000)) -- if there are more units, increase delay for searching for adv radar (from 2 seconds up to 7.5 seconds), for performace reasons
		unitPendingWobble[unitID] = spGetGameFrame() + delay
		scriptDelayByFrames(delay,customWobble,unitID)
		return 0
	end

	local driftTime = advancedRadarUpdateRate
	if (wobbleRadiusFraction == 1 and tableLen(unitInSeismic[unitID]) > 0) then
		driftTime = mRandom(minRandDriftTime,maxRandDriftTime)*15 -- randomly set time of seismic wobble drift, in frames
	end

	-- rotates the wobble/error vector
	local posErrorVectorx,_,posErrorVectorz,_,_,_,_ = spGetUnitPosErrorParams(unitID)
	if (posErrorVectorx == 0 and posErrorVectorz == 0) then
		posErrorVectorx = 0.0000152587890625 -- *slim* chance the current error vector of the unit is zero, so make it non-zero so it can be rotated
	end
	local mag = wobbleRadiusFraction/mSqrt(posErrorVectorx^2 + posErrorVectorz^2)
	local goldenStep = mRandom(#goldenSteps)
	local newposErrorVectorx = (posErrorVectorx * mathCosCache[goldenStep] - posErrorVectorz * mathSinCache[goldenStep]) * mag
	local newposErrorVectorz = (posErrorVectorx * mathSinCache[goldenStep] + posErrorVectorz * mathCosCache[goldenStep]) * mag

	-- set up drift vector
	local posErrorDeltax = (newposErrorVectorx - posErrorVectorx)/driftTime
	local posErrorDeltaz = (newposErrorVectorz - posErrorVectorz)/driftTime

	spSetUnitPosErrorParams(unitID,posErrorVectorx,0,posErrorVectorz,posErrorDeltax,0,posErrorDeltaz,1+driftTime/15)
	-- Please note, final parameter of SetUnitPosErrorParams is in number of slowUpdates, 15 frame intervals.
	-- and 1+ because engine checks as "if ((--nextPosErrorUpdate) > 0)"

	unitPendingWobble[unitID] = spGetGameFrame() + driftTime
	scriptDelayByFrames(driftTime,customWobble,unitID)
	return 0
end

local function restoreEngineRadarControl(unitID,allyteam)
	if unitInSeismic[unitID][allyteam] == spGetGameFrame() then
		spSetUnitLosMask(unitID,allyteam,0) -- returns unit los states to engine control, seismicDotTime after last seismic ping
		unitInSeismic[unitID][allyteam] = nil
	end
end

function gadget:UnitSeismicPing(x,y,z,strength,allyteam,unitID,unitDefID)

	if ((allyteam ~= unitAllyTeamCache[unitID]) and (spIsUnitInRadar(unitID,allyteam) == false))then
		if (unitInSeismic[unitID][allyteam] == nil) then -- no need to repeatedly set UnitLosState and UnitLosMask on every ping
			unitInSeismic[unitID][allyteam] = spGetGameFrame() + seismicDotTime

			-- These trigger gadget:UnitEnteredRadar immedately, which will spin up an instance of customWobble if it is not already running
			-- so unitInSeismic needs to be set already
			spSetUnitLosState(unitID,allyteam,2) -- makes unit unconditionally show up as a radar dot, bitmask
			spSetUnitLosMask(unitID,allyteam,2) -- stops engine from overwriting SetUnitLosState, bitmask
		end
		unitInSeismic[unitID][allyteam] = spGetGameFrame() + seismicDotTime
		scriptDelayByFrames(seismicDotTime,restoreEngineRadarControl,unitID,allyteam)
	end

end

function gadget:MetaUnitAdded(unitID, unitDefID, unitTeam)

	Spring.Echo('MetaUnitAdded',unitDefWobbleRatio[unitDefID],unitID)
	unitCounter = unitCounter + 1
	unitPendingWobble[unitID] = 0
	unitInEnemyRadar[unitID] = {}
	unitInSeismic[unitID] = {}
	unitAllyTeamCache[unitID] = spGetUnitAllyTeam(unitID)
	unitSpeeds[unitID] = unitDefSpeeds[unitDefID]

	-- if the unit is an advanced radar, save it to the local table
	if unitDefWobbleRatio[unitDefID] then
		advancedRadars[unitID] = {}
		advancedRadars[unitID].radarEmitHeight = unitDefRadarEmitHeight[unitDefID]
		advancedRadars[unitID].radarRadius = unitDefRadarRadius[unitDefID]
		advancedRadars[unitID].wobbleRatio = unitDefWobbleRatio[unitDefID]
	end

end

function gadget:MetaUnitRemoved(unitID, unitDefID, unitTeam)
	-- MetaUnitAdded is run AFTER MetaUnitRemoved

	Spring.Echo('MetaUnitRemoved',unitDefWobbleRatio[unitDefID],unitID)
	unitCounter = unitCounter - 1
	unitPendingWobble[unitID] = nil
	unitInEnemyRadar[unitID] = nil
	unitInSeismic[unitID] = nil
	unitAllyTeamCache[unitID] = nil
	unitSpeeds[unitID] = nil
	advancedRadars[unitID] = nil

end

-- To make Amphibious units under water hidden from seismic sensors
function gadget:UnitEnteredUnderwater(unitID, unitDefID, unitTeam)
	spSetUnitSeismicSignature(unitID,0)
end

function gadget:UnitLeftUnderwater(unitID, unitDefID, unitTeam)
	spSetUnitSeismicSignature(unitID,unitDefSeismicSignature[unitDefID])
end

-- To make Hover units hidden from seismic sensors when on water
function gadget:UnitEnteredWater(unitID, unitDefID, unitTeam)
	if unitDefIsHover[unitDefID] then
		spSetUnitSeismicSignature(unitID,0)
	end
end

function gadget:UnitLeftWater(unitID, unitDefID, unitTeam)
	if unitDefIsHover[unitDefID] then
		spSetUnitSeismicSignature(unitID,unitDefSeismicSignature[unitDefID])
	end
end

function gadget:UnitEnteredRadar(unitID, unitTeam, allyTeam, unitDefID)

	Spring.Echo("UnitEnteredRadar")
	if (unitAllyTeamCache[unitID] ~= allyTeam) then
		unitInEnemyRadar[unitID][allyTeam] = true
		Spring.Echo(tableLen(unitInEnemyRadar[unitID]))
		if tableLen(unitInEnemyRadar[unitID]) == 1 then
			unitPendingWobble[unitID] = spGetGameFrame()
			customWobble(unitID) -- spin up the customWobble function
		end
	end

end

function gadget:UnitLeftRadar(unitID, unitTeam, allyTeam, unitDefID)

	Spring.Echo("UnitLeftRadar")
	if (unitAllyTeamCache[unitID] ~= allyTeam) then
		unitInEnemyRadar[unitID][allyTeam] = nil
		Spring.Echo(tableLen(unitInEnemyRadar[unitID]))
	end
end

function gadget:GameFramePost(nn)

	-- clear Spring.X caches at end of sim frame
	unitIsStunnedCache = {}
	unitPositionCache = {}

end
