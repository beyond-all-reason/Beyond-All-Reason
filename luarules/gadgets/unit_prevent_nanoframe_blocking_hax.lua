function gadget:GetInfo()
  return {
    name      = "Prevent Nanoframe Blocking Hax",
    desc      = "Prevents nanoframes from blocking projectiles until they have reached x% build progress",
    author    = "",
    date      = "",
    license   = "Hornswaggle",
    layer     = 0,
    enabled   = true  --  loaded by default?
  }
end

if not gadgetHandler:IsSyncedCode() then return end

local blockingBuildProgress = 0.001

------------

local nanoFrames = {} -- array table, i -> unitID
local nanoFramesID = {} -- hash table, unitID -> last recorded buildProgress
local blockingNanoFrames = {} -- hash table, unitID -> true

local nanoFrameNeutralState = {}

------------

local function BlockNanoFrame(unitID)
	--Spring.Echo("BlockNanoFrame", unitID, Spring.ValidUnitID(unitID))
	if not Spring.ValidUnitID(unitID) then
		return
	end
	
	local a,b,c,d,e,f,g = Spring.GetUnitBlocking(unitID)
	Spring.SetUnitBlocking(unitID, a,b, true, d,e,f,g) -- blocking for projectiles

	nanoFrameNeutralState[unitID] = Spring.GetUnitNeutral(unitID)
	Spring.SetUnitNeutral(unitID, true)	
end

local function UnblockNanoFrame(unitID)
	--Spring.Echo("UnblockNanoFrame", unitID, Spring.ValidUnitID(unitID))
	if not Spring.ValidUnitID(unitID) then
		return 
	end	
	
	local a,b,c,d,e,f,g = Spring.GetUnitBlocking(unitID)
	Spring.SetUnitBlocking(unitID, a,b, false, d,e,f,g) -- non-blocking for projectiles
	
	local neutral = nanoFrameNeutralState[unitID]
	Spring.SetUnitNeutral(unitID, neutral)	
end

local function AddNanoFrame(unitID, buildProgress)
	--Spring.Echo("AddNanoFrame", #nanoFrames, unitID)
	nanoFrames[#nanoFrames+1] = unitID
	nanoFramesID[unitID] = buildProgress
	nanoFrameNeutralState[unitID] = Spring.GetUnitNeutral(unitID)
	blockingNanoFrames[unitID] = false
	UnblockNanoFrame(unitID)
end

local function RemoveNanoFrame(i)
	--Spring.Echo("RemoveNanoFrame", i, unitID)
	local unitID = nanoFrames[i]
	nanoFramesID[unitID] = nil
	nanoFrameNeutralState[unitID] = nil
	blockingNanoFrames[unitID] = nil
	table.remove(nanoFrames, i)
end

------------

local function GetNanoFrameIdx(unitID)
	local i = 1
	while (nanoFrames[i] ~= unitID and i<=#nanoFrames) do
		i = i + 1
	end
	if i>#nanoFrames then return end
	return i
end

local function CheckUnit(unitID)
	-- check if we should remove this unit from our list of nanoframes
	if not Spring.ValidUnitID(unitID) then
		--Spring.Echo("to remove (invalid)", unitID)
		return true
	end
	
	if Spring.GetUnitIsDead(unitID) then
		--Spring.Echo("to remove (dead)", unitID)
		return true
	end

	local _,_,_,_,buildProgress = Spring.GetUnitHealth(unitID)
	if buildProgress >= 1 then  
		--Spring.Echo("to remove (bp)", unitID)
		return true
	end
	
	return false
end

------------

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	local health,maxHealth,_,_,buildProgress = Spring.GetUnitHealth(unitID)
	local buildProgress = health/maxHealth -- sadly buildProgress is always 0 without this, even when cheated in
	if buildProgress < 1 then	
		local _,_,projectileBlocking = Spring.GetUnitBlocking(unitID)
		if projectileBlocking then
			AddNanoFrame(unitID, buildProgress)
		end
	end
end

function gadget:GameFrame(n)
	-- maintain list of nanoframes
	local i = 1
	while (i<=#nanoFrames) do
		local unitID = nanoFrames[i]
		if CheckUnit(unitID) then 
			RemoveNanoFrame(i)
		else
			i = i + 1
		end
	end
	
	
	-- set blocking state
	for i=1,#nanoFrames do
		unitID = nanoFrames[i] 
		local _,_,_,_,buildProgress = Spring.GetUnitHealth(unitID)
		if blockingNanoFrames[unitID] == true then
			if buildProgress == nanoFramesID[unitID] or buildProgress < blockingBuildProgress then
			-- not building, unblock
				UnblockNanoFrame(unitID)
				blockingNanoFrames[unitID] = false
			end
		elseif blockingNanoFrames[unitID] == false then
			if buildProgress > nanoFramesID[unitID] and buildProgress >= blockingBuildProgress then
			-- building, block
				BlockNanoFrame(unitID)
				blockingNanoFrames[unitID] = true
			end
		end
		nanoFramesID[unitID] = buildProgress
	end
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam, builderID)
	i = GetNanoFrameIdx(unitID)
	if i then
		RemoveNanoFrame(i)
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, builderID)
	if nanoFramesID[unitID] ~= nil then
		i = GetNanoFrameIdx(unitID)
		if i then
			RemoveNanoFrame(i)
		end
	end	
end

------------

function gadget:Initialize()
	-- handle reload
	local units = Spring.GetAllUnits()
	for _,unitID in ipairs(units) do
		local unitDefID = Spring.GetUnitDefID(unitID)
		local unitTeam = Spring.GetUnitTeam(unitID)
		gadget:UnitCreated(unitID, unitDefID, unitTeam)
	end
end

