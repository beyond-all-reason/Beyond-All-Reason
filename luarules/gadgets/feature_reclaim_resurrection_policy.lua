local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Allied reclaim and resurrection policy",
		desc = "Optional arbitration of conflicting work on allied wrecks",
		author = "Eunice3x",
		license = "GNU GPL, v2 or later",
		layer = -100, -- Before reclaim-fix and resource-sharing tax side effects.
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local mode = Spring.GetModOptions().experimental_reclaim_resurrection or "off"
if mode ~= "first" and mode ~= "reclaim" and mode ~= "resurrect" and mode ~= "last" then
	return false
end

-- A claim requires actual work attempts, not a queued order or leftover progress.
-- Units update every frame; retain the previous frame to avoid unit-update-order gaps.
local claims = {}
local waiting = {}
local builders = {}
local stepsThisFrame = {}
local stepsFrame = -1
local preferred = mode == "reclaim" and -1 or (mode == "resurrect" and 1 or nil)

local function activeWorker(unitID, featureID, direction)
	local command, target = Spring.GetUnitWorkerTask(unitID)
	return command == (direction == 1 and CMD.RESURRECT or CMD.RECLAIM)
		and target == featureID + Game.maxUnits
		and Spring.GetUnitIsDead(unitID) == false
		and not Spring.GetUnitIsStunned(unitID)
end

local function getClaim(featureID, allyTeam, frame)
	local byAlly = claims[featureID]
	local claim = byAlly and byAlly[allyTeam]
	if not claim then
		return
	end
	local active = false
	for unitID, lastFrame in pairs(claim.workers) do
		if
			frame - lastFrame <= 1
			and Spring.GetUnitAllyTeam(unitID) == allyTeam
			and activeWorker(unitID, featureID, claim.direction)
		then
			active = true
		else
			claim.workers[unitID] = nil
		end
	end
	if active then
		return claim
	end
	byAlly[allyTeam] = nil
end

local function pauseWorker(unitID, featureID, allyTeam, direction)
	if waiting[unitID] then
		return
	end
	-- Hide the conflicting target from the engine's automatic target caches too.
	-- Preserve the original command and its queue so work can resume when released.
	Spring.GiveOrderToUnit(unitID, CMD.INSERT, { 0, CMD.WAIT, CMD.OPT_INTERNAL }, CMD.OPT_ALT)
	local command, _, tag = Spring.GetUnitCurrentCommand(unitID)
	if command == CMD.WAIT then
		waiting[unitID] = { feature = featureID, allyTeam = allyTeam, direction = direction, tag = tag }
	end
end

function gadget:AllowFeatureBuildStep(builderID, builderTeam, featureID, featureDefID, part)
	if part == 0 then
		return true
	end
	local resurrectAs = Spring.GetFeatureResurrect(featureID)
	if not resurrectAs or resurrectAs == "" then
		return true
	end
	local allyTeam = Spring.GetUnitAllyTeam(builderID)
	local frame = Spring.GetGameFrame()
	if stepsFrame ~= frame then
		stepsThisFrame = {}
		stepsFrame = frame
	end
	local direction = part > 0 and 1 or -1
	local claim = getClaim(featureID, allyTeam, frame)
	if claim and claim.direction ~= direction then
		if mode ~= "last" and direction ~= preferred then
			pauseWorker(builderID, featureID, allyTeam, direction)
			return false
		end
		-- In last-arrival mode, only a new work attempt can take over. Paused
		-- workers retain WAIT until this claim ends, so they cannot take it back.
		-- A priority takeover must not allow both directions to spend on this frame.
		for unitID in pairs(claim.workers) do
			pauseWorker(unitID, featureID, allyTeam, claim.direction)
		end
		claims[featureID][allyTeam] = { direction = direction, workers = { [builderID] = frame } }
		-- Retry next frame, after the previous activity has stopped.
		return false
	end
	if not claim then
		claims[featureID] = claims[featureID] or {}
		claim = { direction = direction, workers = {} }
		claims[featureID][allyTeam] = claim
	end
	claim.workers[builderID] = frame
	-- A worker can finish or stop after an allowed step earlier in this frame.
	-- Its claim then expires, but the opposite activity must still wait one frame.
	local steps = stepsThisFrame[featureID]
	if not steps then
		steps = {}
		stepsThisFrame[featureID] = steps
	end
	if steps[allyTeam] and steps[allyTeam] ~= direction then
		return false
	end
	steps[allyTeam] = direction
	return true
end

function gadget:GameFrame(frame)
	-- The engine checks targeted resurrection orders before they produce a build
	-- step. Pause losing orders first, otherwise they can cancel a winning automatic
	-- reclaim even though AllowFeatureBuildStep would reject their work.
	if mode ~= "last" and next(claims) then
		for unitID in pairs(builders) do
			local command, _, _, target, p2, _, _, p5 = Spring.GetUnitCurrentCommand(unitID)
			local direction = command == CMD.RESURRECT and 1 or (command == CMD.RECLAIM and -1 or nil)
			if
				direction
				and direction ~= preferred
				and target
				and target >= Game.maxUnits
				and (p2 == nil or p5 ~= nil)
			then
				local featureID = target - Game.maxUnits
				local allyTeam = Spring.GetUnitAllyTeam(unitID)
				local claim = getClaim(featureID, allyTeam, frame)
				if claim and claim.direction ~= direction then
					pauseWorker(unitID, featureID, allyTeam, direction)
				end
			end
		end
	end
	for unitID, entry in pairs(waiting) do
		local command, _, tag = Spring.GetUnitCurrentCommand(unitID)
		if command ~= CMD.WAIT or tag ~= entry.tag then
			waiting[unitID] = nil -- The player replaced or removed our wait.
		else
			local claim = getClaim(entry.feature, entry.allyTeam, frame)
			if not claim or claim.direction == entry.direction then
				waiting[unitID] = nil
				Spring.GiveOrderToUnit(unitID, CMD.REMOVE, { entry.tag }, 0)
			end
		end
	end
	if frame % Game.gameSpeed == 0 then
		for featureID, byAlly in pairs(claims) do
			for allyTeam in pairs(byAlly) do
				getClaim(featureID, allyTeam, frame)
			end
			if not next(byAlly) then
				claims[featureID] = nil
			end
		end
	end
end

function gadget:FeatureDestroyed(featureID)
	claims[featureID] = nil
	stepsThisFrame[featureID] = nil
end

function gadget:UnitDestroyed(unitID)
	waiting[unitID] = nil
	builders[unitID] = nil
end

local function trackBuilder(unitID, unitDefID)
	local def = UnitDefs[unitDefID]
	if def and def.isBuilder then
		builders[unitID] = true
	end
end

function gadget:UnitCreated(unitID, unitDefID)
	trackBuilder(unitID, unitDefID)
end

function gadget:UnitGiven(unitID)
	local entry = waiting[unitID]
	if entry then
		waiting[unitID] = nil
		Spring.GiveOrderToUnit(unitID, CMD.REMOVE, { entry.tag }, 0)
	end
end

local function protectedResurrecter(unitID)
	local command, target = Spring.GetUnitWorkerTask(unitID)
	if command ~= CMD.RESURRECT or not target then
		return false
	end
	local claim = getClaim(target - Game.maxUnits, Spring.GetUnitAllyTeam(unitID), Spring.GetGameFrame())
	return claim ~= nil and claim.direction == 1 and claim.workers[unitID] ~= nil
end

function gadget:Initialize()
	GG.IsProtectedResurrecter = protectedResurrecter
	for _, unitID in ipairs(Spring.GetAllUnits()) do
		trackBuilder(unitID, Spring.GetUnitDefID(unitID))
	end
end

function gadget:Shutdown()
	GG.IsProtectedResurrecter = nil
	for unitID, entry in pairs(waiting) do
		Spring.GiveOrderToUnit(unitID, CMD.REMOVE, { entry.tag }, 0)
	end
end
