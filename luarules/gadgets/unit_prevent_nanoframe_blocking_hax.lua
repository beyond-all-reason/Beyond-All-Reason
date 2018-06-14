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

local blockingBuildProgress = 0.1

------------

local newNanoFrames = {} --arrayTable

local function AddNanoFrame(unitID)
	newNanoFrames[#newNanoFrames+1] = unitID
	local arg1,arg2 = Spring.GetUnitBlocking(unitID)
	Spring.SetUnitBlocking(unitID, arg1,arg2, false) -- non-blocking for projectiles
	Spring.SetUnitNeutral(unitID, true)
	
	--Spring.Echo("added", unitID)
end

local function RemoveNanoFrameIdx(i)
	local unitID = newNanoFrames[i]

	newNanoFrames[i] = nil
	while (newNanoFrames[i+1] ~= nil) do
		newNanoFrames[i] = newNanoFrames[i+1]
		i = i + 1
	end
	
	if Spring.ValidUnitID(unitID) then
		local arg1,arg2 = Spring.GetUnitBlocking(unitID)
		Spring.SetUnitBlocking(unitID, arg1,arg2, true) -- assume all units are (normally) blocking for projectiles
		Spring.SetUnitNeutral(unitID, false)
	end
	
	--Spring.Echo("removed", unitID)
end

local function RemoveNanoFrame(unitID)
	local i = 1
	while (newNanoFrames[i] ~= unitID and i<=#newNanoFrames) do
		i = i + 1
	end
	if i>#newNanoFrames then return end

	RemoveNanoFrameIdx(i)
end

------------

local function ProcessNanoFrame(i)
	local unitID = newNanoFrames[i]
	if not Spring.ValidUnitID(unitID) then
		RemoveNanoFrameIdx(i)
		return
	end
	
	local _,_,_,_,buildProgress = Spring.GetUnitHealth(unitID)
	--Spring.Echo(unitID, buildProgress)
	if buildProgress >= blockingBuildProgress then 
		RemoveNanoFrameIdx(i)
	end
end

------------

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	if not Spring.GetUnitNeutral(unitID) then	-- dont change neutrality of already neutral units
		AddNanoFrame(unitID)
	end
end

function gadget:GameFrame()
	for i=1,#newNanoFrames do
		ProcessNanoFrame(i)
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, builderID)
	RemoveNanoFrame(unitID)
end

------------

function gadget:Initialize()
	-- handle laurules reload
	local units = Spring.GetAllUnits()
	for _,unitID in ipairs(units) do
		local unitDefID = Spring.GetUnitDefID(unitID)
		local unitTeam = Spring.GetUnitTeam(unitID)
		gadget:UnitCreated(unitID, unitDefID, unitTeam)
	end
end

