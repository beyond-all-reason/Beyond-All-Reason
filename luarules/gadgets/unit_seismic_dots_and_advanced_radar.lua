
local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name      = "Seismic Dots and Advanced Radar",
		desc      = "When in Seismic LOS, reveal a wobbling radar dot. And remove wobble if in LOS of a T2 radar",
		author    = "Kyle Anthony Shepherd (Itanthias)",
		date      = "Aug 7, 2025",
		license   = "GNU GPL, v2 or later, and anyone who uses this gadget has to email me a rabbit with a sword",
		layer     = -1,
		enabled   = Spring.GetModOptions().sensor_rework
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

local spGetUnitAllyTeam = Spring.GetUnitAllyTeam
local spGetUnitPosition = Spring.GetUnitPosition
local spTraceRayGroundBetweenPositions = Spring.TraceRayGroundBetweenPositions
local spIsUnitInRadar = Spring.IsUnitInRadar
local spSetUnitLosState = Spring.SetUnitLosState
local spSetUnitLosMask = Spring.SetUnitLosMask
local spGetGameFrame = Spring.GetGameFrame
local spSetUnitPosErrorParams = Spring.SetUnitPosErrorParams

local allyteamlist = Spring.GetAllyTeamList() --grab the ally team list at gadget load

local restoreUnitLOS = {} -- list of units to hand off los control back to engine after X frames

local advancedRadars = {} -- table to hold all advanced radars currently in the game, partitioned by allyTeam
for key, values in pairs(allyteamlist) do
	advancedRadars[values] = {} 
end

local inBasicRadar = {} -- table to hold units currently in basic radar, partitioned by allyTeam
local basicRadarUpdateRate = 90
for key, values in pairs(allyteamlist) do
	inBasicRadar[values] = {}
	for i=0,basicRadarUpdateRate-1 do
		inBasicRadar[values][i] = {} -- segment the table into basicRadarUpdateRate slices
		-- a slice will be processed each frame.
		-- so, every basicRadarUpdateRate/30 seconds a unit will be checked to see if it enters advanced radar range.
	end
end

local inAdvancedRadar = {} -- table to hold units currently in advanced radar, partitioned by allyTeam
local advancedRadarUpdateRate = 180
for key, values in pairs(allyteamlist) do
	inAdvancedRadar[values] = {}
	for i=0,advancedRadarUpdateRate-1 do
		inAdvancedRadar[values][i] = {} -- segment the table into advancedRadarUpdateRate slices
		-- a slice will be checked each frame.
		-- so, every advancedRadarUpdateRate/30 seconds a unit will be checked to see if it enters advanced radar range.
	end
end

local unitInBasicRadar = {} -- table to lookup if allyTeam is seeing unitID in basic radar
for key, values in pairs(allyteamlist) do 
	unitInBasicRadar[values] = {} 
end

local unitInAdvancedRadar = {} -- table to lookup if allyTeam is seeing unitID in advanced radar
for key, values in pairs(allyteamlist) do 
	unitInAdvancedRadar[values] = {} 
end

local unitspeeds = {}

function gadget:UnitSeismicPing(x,y,z,strength,allyteam,unitID,unitDefID) -- when engine decides to make a seismic ping, run this stuff
	
	if (allyteam ~= spGetUnitAllyTeam(unitID)) and (spIsUnitInRadar(unitID,allyteam) == false) then
		-- only run if the unit is being seen by a different allyTeam, and is not in radar.

		if (restoreUnitLOS[unitID]==nil) then -- no need to repeatedly set UnitLosState and UnitLosMask on every ping
			spSetUnitLosState(unitID,allyteam,2) -- makes unit unconditionally show up as a radar dot
			spSetUnitLosMask(unitID,allyteam,2) -- stops engine from overwriting SetUnitLosState
			restoreUnitLOS[unitID] = {}
		end
		restoreUnitLOS[unitID].allyteam = allyteam
		restoreUnitLOS[unitID].restoretime = spGetGameFrame() + 60 -- after 2 seconds, remove the seismic dot

		local basePointX, basePointY, basePointZ = spGetUnitPosition(unitID)
		-- Currently, just place radar dot directly on the seismic ping.
		-- "wobble" is decreased by pinpointers.
		-- TODO: If desired, use RNG on lua side to place the seismic dot, and completly blank the engine seismic texture, and perhaps add our own emitceg via Spring.SpawnCEG("seismic_ping",x,y,z,0,10,0)
		spSetUnitPosErrorParams(unitID,(x-basePointX)/128,(y-basePointY)/128,(z-basePointZ)/128,0,0,0,4)
		-- last parameter is in *number of slowupdates*

	end
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam)
	-- save unit speed on a quick reference local table, when unit is created
	unitspeeds[unitID] = UnitDefs[unitDefID].speed

end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	-- if the unit is a T2 radar, save it to the local table
	-- TODO: currently hardcoded by unitname, might be ideal to set a customdef, that could also be read to set the "advanced" radar wobble.
	if ((UnitDefs[unitDefID].name == "corarad") or (UnitDefs[unitDefID].name == "armarad") or (UnitDefs[unitDefID].name == "legarad")) then
		advancedRadars[spGetUnitAllyTeam(unitID)][unitID] = {}
		advancedRadars[spGetUnitAllyTeam(unitID)][unitID].radarEmitHeight = UnitDefs[unitDefID].radarEmitHeight
		advancedRadars[spGetUnitAllyTeam(unitID)][unitID].radarRadius = UnitDefs[unitDefID].radarRadius
	end

end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
	-- remove dead T2 radars from the local table
	advancedRadars[spGetUnitAllyTeam(unitID)][unitID] = nil

	-- remove dead units from the InRadar lists
	for key, values in pairs(allyteamlist) do
		unitInAdvancedRadar[values][unitID] = nil
		unitInBasicRadar[values][unitID] = nil
	end

	unitspeeds[unitID] = nil
end

function gadget:UnitGiven(unitID, unitDefID, newTeam, oldTeam)

	-- deal with any shared or captured T2 radars
	if ((UnitDefs[unitDefID].name == "corarad") or (UnitDefs[unitDefID].name == "armarad") or (UnitDefs[unitDefID].name == "legarad")) then
		advancedRadars[oldTeam][unitID]  = nil
		advancedRadars[newTeam][unitID] = {}
		advancedRadars[newTeam][unitID].radarEmitHeight = UnitDefs[unitDefID].radarEmitHeight
		advancedRadars[newTeam][unitID].radarRadius = UnitDefs[unitDefID].radarRadius
	end

end

local function advancedRadarCheck(unitID,allyTeam)
	-- this function determines if a specific unit can be seen by the advanced radars of the allyTeam
	local basePointX, basePointY, basePointZ -- not 100% sure if it is more performent to keep setting a local every time this function is called, or set the local outside this function. 
	local unitPointX, unitPointY, unitPointZ
	local advancedRadarFreeLineOfFire = false

	for advancedRadar, tableValues in pairs(advancedRadars[allyTeam]) do -- loop over every aradar on the allyTeam
		local radarEmitHeight = tableValues.radarEmitHeight
		local radarRadius = tableValues.radarRadius

		local basePointX, basePointY, basePointZ = spGetUnitPosition(advancedRadar)
		local unitPointX, unitPointY, unitPointZ = spGetUnitPosition(unitID) -- use basepoint as radar "paints" the ground
		local dist2D = (basePointX-unitPointX)^2 + (basePointZ-unitPointZ)^2
		local dist3D = (basePointX-unitPointX)^2 + (basePointY+radarEmitHeight-unitPointY-1)^2 + (basePointZ-unitPointZ)^2
		-- check if the unit is within cylinder distance of the radar

		-- check if the radar can see the unit without being obstructed by terrain
		local raylength,_,_,_ = spTraceRayGroundBetweenPositions(basePointX, basePointY+radarEmitHeight, basePointZ, unitPointX, unitPointY + 1, unitPointZ)
		if raylength == nil then -- returns nil if no ground collision detected
			advancedRadarFreeLineOfFire = ((radarRadius+unitspeeds[unitID])^2 >= dist2D)
		end
		-- +1 on unitPointX to prevent false ground collision positives at the terminal point.
		-- +unitspeed on radarRadius to help catch units just walking into radar range, it seems unitspeed is accounted for when determining when to trigger UnitEnteredRadar

		if advancedRadarFreeLineOfFire == true then -- break early if an advanced radar sees the unit
			break
		end
	end

	if advancedRadarFreeLineOfFire then
		--TODO: allow for custom "advanced" radar wobble parameters. Hardcoded to "perfect" for now
		if restoreUnitLOS[unitID] == nil then -- don't set zero error if recently seismic pinged
			spSetUnitPosErrorParams(unitID,0,0,0,0,0,0,1+advancedRadarUpdateRate/15) -- set the (lack of) wobble here. 1+ to make sure the (lack of) wobble lasts for at least 1 slowupdate longer than the updaterate
		end
		local framecycle = spGetGameFrame()%advancedRadarUpdateRate

		inAdvancedRadar[allyTeam][framecycle][unitID] = true -- check this unit on next framecycle if it is still seen by an advanced radar
		unitInAdvancedRadar[allyTeam][unitID] = framecycle -- set table to lookup when a unit is scheduled to check for advanced radars again. Checked later to prevent a unit from being double scheduled
		unitInBasicRadar[allyTeam][unitID] = nil -- effectively remove unit from the faster updating InBasicRadar list.
	else
		local framecycle = spGetGameFrame()%basicRadarUpdateRate
		inBasicRadar[allyTeam][framecycle][unitID] = true -- check this unit on next framecycle if it is still seen by an advanced radar
		unitInBasicRadar[allyTeam][unitID] = framecycle -- set table to lookup when a unit is scheduled to check for advanced radars again. Checked later to prevent a unit from being double scheduled
		unitInAdvancedRadar[allyTeam][unitID] = nil -- effectively remove unit from the slower updating InAdvancedRadar list.
	end
end

function gadget:UnitEnteredRadar(unitID, unitTeam, allyTeam, unitDefID)
	-- figure out if the unit entered a T1 or T2 radar range
	-- and get the unit on the proper InRadar list
	advancedRadarCheck(unitID,allyTeam)

end

function gadget:UnitLeftRadar(unitID, unitTeam, allyTeam, unitDefID)
	-- effectively remove unit from the InRadar lists
	unitInAdvancedRadar[allyTeam][unitID] = nil
	unitInBasicRadar[allyTeam][unitID] = nil

end

function gadget:GameFrame(nn)

	local advancedRadarUpdateFrame = (nn+1)%advancedRadarUpdateRate
	local basicRadarUpdateFrame = (nn+1)%basicRadarUpdateRate

	for key, allyTeam in pairs(allyteamlist) do -- check each allyTeam

		--check units in inAdvancedRadar scheduled to be re-checked on this frame
		for unitID, value in pairs(inAdvancedRadar[allyTeam][advancedRadarUpdateFrame]) do
			inAdvancedRadar[allyTeam][advancedRadarUpdateFrame][unitID] = nil -- remove the unit from the InRadar list
			if unitInAdvancedRadar[allyTeam][unitID] == advancedRadarUpdateFrame then -- if unit is actually scheduled to check for advanced radars again, do the check.
				advancedRadarCheck(unitID,allyTeam)
			end
		end

		--check units in inBasicRadar scheduled to be re-checked on this frame
		for unitID, value in pairs(inBasicRadar[allyTeam][basicRadarUpdateFrame]) do
			inBasicRadar[allyTeam][basicRadarUpdateFrame][unitID] = nil -- remove the unit from the InRadar list
			if unitInBasicRadar[allyTeam][unitID] == basicRadarUpdateFrame then -- if unit is actually scheduled to check for advanced radars again, do the check.
				advancedRadarCheck(unitID,allyTeam)
			end
		end
	end

	for unitID, data in pairs(restoreUnitLOS) do -- check units in seismic range, to determine if enough time has passed to hand off radar control back to engine
		if data.restoretime <= nn then
			spSetUnitLosMask(unitID,data.allyteam,0) -- returns unit los states to engine control

			if unitInAdvancedRadar[data.allyteam][unitID] ~= nil then -- if seen by an advanced radar set the error parameter
				spSetUnitPosErrorParams(unitID,0,0,0,0,0,0,1+advancedRadarUpdateRate/15)
			end

			restoreUnitLOS[unitID] = nil
		end
	end
end

