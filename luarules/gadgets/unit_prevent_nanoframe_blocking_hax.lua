local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Prevent Nanoframe Blocking Hax",
		desc = "Prevents nanoframes from blocking projectiles until they have reached x% build progress",
		author = "",
		date = "",
		license = "Hornswaggle",
		layer = 0,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local spGetUnitBlocking = Spring.GetUnitBlocking
local spSetUnitBlocking = Spring.SetUnitBlocking
local spGetUnitNeutral = Spring.GetUnitNeutral
local spSetUnitNeutral = Spring.SetUnitNeutral
local spGetUnitIsBeingBuilt = Spring.GetUnitIsBeingBuilt
local spValidUnitID = Spring.ValidUnitID

local blockingBuildProgress = 0.05

-- Build progress is polled from GameFrame instead of reacting to every build
-- step: each tracked nanoframe is checked once every CHECK_INTERVAL frames
-- (spread over frames by unitID), and GameFrame is switched off entirely while
-- nothing is tracked. A nanoframe may therefore keep its non-blocking state for
-- up to CHECK_INTERVAL frames after crossing the threshold.
local CHECK_INTERVAL = 15

local newNanoFrameNeutralState = {} -- hash table, unitID -> original neutral state
local CMD_ATTACK = CMD.ATTACK

local slots = {} -- frame slot -> array of tracked unitIDs polled on that slot
for i = 0, CHECK_INTERVAL - 1 do
	slots[i] = {}
end
local slotPos = {} -- unitID -> index inside its slot
local trackedCount = 0

local function track(unitID, neutral)
	newNanoFrameNeutralState[unitID] = neutral
	local slot = slots[unitID % CHECK_INTERVAL]
	local n = #slot + 1
	slot[n] = unitID
	slotPos[unitID] = n
	trackedCount = trackedCount + 1
	if trackedCount == 1 then
		gadgetHandler:UpdateCallIn("GameFrame")
	end
end

local function untrack(unitID)
	if newNanoFrameNeutralState[unitID] == nil then
		return
	end
	newNanoFrameNeutralState[unitID] = nil
	local slot = slots[unitID % CHECK_INTERVAL]
	local pos = slotPos[unitID]
	local n = #slot
	local last = slot[n]
	slot[pos] = last
	slotPos[last] = pos
	slot[n] = nil
	slotPos[unitID] = nil
	trackedCount = trackedCount - 1
	if trackedCount == 0 then
		gadgetHandler:RemoveCallIn("GameFrame")
	end
end

local function AddNanoFrame(unitID)
	local a, b, c, d, e, f, g = spGetUnitBlocking(unitID)
	spSetUnitBlocking(unitID, a, b, false, d, e, f, g) -- non-blocking for projectiles

	local neutral = spGetUnitNeutral(unitID)
	spSetUnitNeutral(unitID, true)
	track(unitID, neutral)
end

local function removeNanoFrame(unitID)
	if spValidUnitID(unitID) then
		local a, b, c, d, e, f, g = spGetUnitBlocking(unitID)
		spSetUnitBlocking(unitID, a, b, true, d, e, f, g) -- blocking for projectiles

		local neutral = newNanoFrameNeutralState[unitID]
		-- If a unit has already been set to neutral=false, don't overwrite that here
		if spGetUnitNeutral(unitID) then
			spSetUnitNeutral(unitID, neutral)
		end
	end
	untrack(unitID)
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	if builderID then
		local _, _, projectileBlocking = spGetUnitBlocking(unitID)
		if projectileBlocking then
			AddNanoFrame(unitID)
		end
	end
end

function gadget:UnitFinished(unitID)
	if newNanoFrameNeutralState[unitID] ~= nil then
		removeNanoFrame(unitID)
	end
end

function gadget:GameFrame(n)
	local slot = slots[n % CHECK_INTERVAL]
	-- iterate backwards so swap-removal never skips an entry
	for i = #slot, 1, -1 do
		local unitID = slot[i]
		local _, buildProgress = spGetUnitIsBeingBuilt(unitID)
		if buildProgress and buildProgress >= blockingBuildProgress then
			removeNanoFrame(unitID)
		end
	end
end

-- make it not manually or accidentally targetable
function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions)
	-- accepts: CMD.ATTACK
	if not cmdParams[2] and newNanoFrameNeutralState[cmdParams[1]] ~= nil then
		return false
	else
		return true
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, builderID)
	untrack(unitID)
end

function gadget:Initialize()
	gadgetHandler:RegisterAllowCommand(CMD_ATTACK)
	-- handle luarules reload: pick up nanoframes still below the threshold
	local units = Spring.GetAllUnits()
	for _, unitID in ipairs(units) do
		local beingBuilt, buildProgress = spGetUnitIsBeingBuilt(unitID)
		if beingBuilt and buildProgress < blockingBuildProgress then
			local _, _, projectileBlocking = spGetUnitBlocking(unitID)
			if projectileBlocking then
				AddNanoFrame(unitID)
			else
				-- already marked before the reload; its original neutral state is lost
				track(unitID, false)
			end
		end
	end
	if trackedCount == 0 then
		gadgetHandler:RemoveCallIn("GameFrame")
	end
end
