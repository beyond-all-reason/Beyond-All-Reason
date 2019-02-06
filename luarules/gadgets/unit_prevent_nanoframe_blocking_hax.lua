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

local blockingBuildProgress = 0.05

------------

local newNanoFrames = {} -- array table, i -> unitID
local newNanoFrameNeutralState = {} -- hash table, unitID -> original neutral state

local nanoFrameIdxToRemove = {}

------------

local function AddNanoFrame(unitID)
	newNanoFrames[#newNanoFrames+1] = unitID

	local a,b,c,d,e,f,g = Spring.GetUnitBlocking(unitID)
	Spring.SetUnitBlocking(unitID, a,b, false, d,e,f,g) -- non-blocking for projectiles

	local neutral = Spring.GetUnitNeutral(unitID)
	newNanoFrameNeutralState[unitID] = neutral
	Spring.SetUnitNeutral(unitID, true)
	
	--Spring.Echo("AddNanoFrame", #newNanoFrames, unitID)
end

local function RemoveNanoFrame(i)
	local unitID = newNanoFrames[i]
	--Spring.Echo("RemoveNanoFrame", i, unitID, newNanoFrameNeutralState[unitID])

	if Spring.ValidUnitID(unitID) then
		local a,b,c,d,e,f,g = Spring.GetUnitBlocking(unitID)
		Spring.SetUnitBlocking(unitID, a,b, true, d,e,f,g) -- blocking for projectiles
		
		local neutral = newNanoFrameNeutralState[unitID]
		Spring.SetUnitNeutral(unitID, neutral)
		
		--Spring.Echo("unset", unitID)
	end	

	table.remove(newNanoFrames, i)
	newNanoFrameNeutralState[unitID] = nil
end

------------

local function GetNanoFrameIdx(unitID)
	local i = 1
	while (newNanoFrames[i] ~= unitID and i<=#newNanoFrames) do
		i = i + 1
	end
	if i>#newNanoFrames then return end
	return i
end

local function CheckUnit(unitID)
	-- check if we should remove this unit from our list
	if not Spring.ValidUnitID(unitID) then
		--Spring.Echo("to remove (invalid)", unitID)
		return true
	end
	
	if Spring.GetUnitIsDead(unitID) then
		--Spring.Echo("to remove (dead)", unitID)
		return true
	end

	local _,_,_,_,buildProgress = Spring.GetUnitHealth(unitID)
	if buildProgress >= blockingBuildProgress then  
		--Spring.Echo("to remove (bp)", unitID)
		return true
	end
	
	return false
end

------------

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	local health,maxHealth,_,_,buildProgress = Spring.GetUnitHealth(unitID)
	if health/maxHealth < blockingBuildProgress then	-- sadly buildProgress is always 0 even when cheated in
		local _,_,projectileBlocking = Spring.GetUnitBlocking(unitID)
		if projectileBlocking then
			AddNanoFrame(unitID)
		end
	end
end

function gadget:GameFrame(n)
	local i = 1
	while (i<=#newNanoFrames) do
		local unitID = newNanoFrames[i]
		if CheckUnit(unitID) then 
			RemoveNanoFrame(i)
		else
			i = i + 1
		end
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, builderID)
	if newNanoFrameNeutralState[unitID]~=nil then
		--Spring.Echo("to remove (destroyed)", unitID)
		nanoFrameIdxToRemove[#nanoFrameIdxToRemove+1] = GetNanoFrameIdx(unitID)
	end	
end

------------

function gadget:Initialize()
	-- handle luarules reload
	local units = Spring.GetAllUnits()
	for _,unitID in ipairs(units) do
		local unitDefID = Spring.GetUnitDefID(unitID)
		local unitTeam = Spring.GetUnitTeam(unitID)
		gadget:UnitCreated(unitID, unitDefID, unitTeam)
	end
end

