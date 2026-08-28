local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Wave Capture",
		desc = "Units standing in a director's creep are slowly captured and converted to its team",
		author = "Damgam, Beyond All Reason",
		date = "August 2026",
		license = "GNU GPL, v2 or later",
		layer = 5,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local Capture = VFS.Include("modules/waves/lib/capture.lua")

local HOST_REFRESH = 30

local capturing = {} ---@type table[] hosts with a capture policy
local policies = {} ---@type table<string, WaveCaptureRules>
local capturable = {} ---@type table<integer, boolean>

local function refreshHosts()
	capturing = {}
	for _, host in ipairs(GG.Waves.Hosts()) do
		if host.capture ~= nil then
			policies[host.name] = policies[host.name] or Capture.Policy(host.capture)
			capturing[#capturing + 1] = host
		end
	end
end

---@param host table
---@param unitID integer
---@param x number
---@param y number
---@param z number
---@param maxHealth number
local function convert(host, unitID, x, y, z, maxHealth)
	local policy = policies[host.name]
	if host.hooks.onCapturing then
		host.hooks.onCapturing(unitID, x, y, z)
	end
	-- The flavor's UnitGiven handler may destroy this unit and replace it
	-- with its own variant, so everything after this re-checks it.
	Spring.TransferUnit(unitID, host.teamID, false)
	if not Spring.ValidUnitID(unitID) then
		return
	end
	Spring.SetUnitHealth(unitID, { capture = policy.convertedLevel })
	Spring.SetUnitHealth(unitID, { health = maxHealth })
	SendToUnsynced("unitCaptureFrame", unitID, policy.convertedLevel)
	if host.hooks.onCaptured then
		host.hooks.onCaptured(unitID, x, y, z)
	end
	if GG.addUnitToCaptureDecay then
		GG.addUnitToCaptureDecay(unitID)
	end
end

---@param host table
---@param unitID integer
local function tickUnit(host, unitID)
	local x, y, z = Spring.GetUnitPosition(unitID)
	if x == nil then
		return
	end
	local health, maxHealth, _, captureLevel = Spring.GetUnitHealth(unitID)
	if not health then
		return
	end
	-- A neutral unit is nobody's and the creep does not take it: mission
	-- scenery, and anything protected by being set neutral, would otherwise
	-- convert with no callin ever firing, since this is a direct transfer.
	if Spring.GetUnitNeutral(unitID) then
		return
	end
	if Spring.GetUnitTeam(unitID) == host.teamID then
		return
	end
	local inCreep = GG.IsPosInRaptorScum ~= nil and GG.IsPosInRaptorScum(x, y, z)

	if inCreep then
		local policy = policies[host.name]
		local defHealth = UnitDefs[Spring.GetUnitDefID(unitID)].health
		local progress = Capture.Rate(policy, health, maxHealth, defHealth, host.state.anger.techAnger)
		local converts, level = Capture.Step(policy, captureLevel, progress)
		if converts then
			convert(host, unitID, x, y, z, maxHealth)
			return
		end
		Spring.SetUnitHealth(unitID, { capture = level })
		SendToUnsynced("unitCaptureFrame", unitID, level)
		if host.hooks.onCaptureProgress then
			host.hooks.onCaptureProgress(unitID, x, y, z)
		end
		if GG.addUnitToCaptureDecay then
			GG.addUnitToCaptureDecay(unitID)
		end
	end
end

function gadget:Initialize()
	for _, unitID in ipairs(Spring.GetAllUnits()) do
		capturable[unitID] = true
	end
	if GG.Waves ~= nil then
		refreshHosts()
	end
end

function gadget:GameFrame(frame)
	if frame % HOST_REFRESH == 0 and GG.Waves ~= nil then
		refreshHosts()
	end
	for _, host in ipairs(capturing) do
		local pass = Capture.PassOf(policies[host.name], frame)
		if pass ~= nil then
			-- convert() fires UnitGiven (and spawn effects UnitCreated)
			-- mid-walk, and inserting a key during next/pairs corrupts the
			-- iterator, so walk a snapshot and skip anything that left.
			local ids = {}
			for unitID in pairs(capturable) do
				ids[#ids + 1] = unitID
			end
			for i = 1, #ids do
				local unitID = ids[i]
				if capturable[unitID] and unitID % policies[host.name].passes == pass then
					tickUnit(host, unitID)
				end
			end
		end
	end
end

function gadget:UnitCreated(unitID)
	capturable[unitID] = true
end

function gadget:UnitDestroyed(unitID)
	capturable[unitID] = nil
end
