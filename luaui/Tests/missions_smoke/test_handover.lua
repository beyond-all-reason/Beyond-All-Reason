---@diagnostic disable: undefined-field

local BASE_DEFS = { corlab = true, corllt = true }
local ARM_TIMEOUT = 900
-- Long enough that a hand-over ignoring the spotted gate has had every
-- chance to happen: the give sits on MatchFlow.Started plus the latch.
local FOG_HOLD_FRAMES = 8 * 30

local function countBase(teamID)
	local found = 0
	for _, unitID in ipairs(Spring.GetTeamUnits(teamID) or {}) do
		local unitDef = UnitDefs[Spring.GetUnitDefID(unitID)]
		if unitDef and BASE_DEFS[unitDef.name] then
			found = found + 1
		end
	end
	return found
end

local function skip()
	if Spring.GetGameFrame() <= 0 then
		return true
	end
	local gaia = Spring.GetGaiaTeamID()
	local playerTeamID = Spring.GetLocalTeamID()
	local _, _, _, _, _, myAllyTeamID = Spring.GetTeamInfo(playerTeamID, false)
	for _, teamID in ipairs(Spring.GetTeamList()) do
		if teamID ~= gaia and teamID ~= playerTeamID then
			local _, _, _, _, _, allyTeamID = Spring.GetTeamInfo(teamID, false)
			if allyTeamID ~= myAllyTeamID then
				return false
			end
		end
	end
	return true
end

---The player's allyteam, which is what /globallos actually takes: the
---argument is an ALLYTEAM ID and the call TOGGLES it.
local function playerAllyTeam()
	return select(6, Spring.GetTeamInfo(Spring.GetLocalTeamID(), false))
end

-- Because the command toggles, cleanup has to know whether the test already
-- flipped it back.
local revealed = false

local function setup()
	revealed = false
	Test.clearMap()
	-- The scenario's startscript turns global LOS on. That is the one thing
	-- this test cannot have: it would spot the hub at spawn and the gate
	-- would be open before the mission armed.
	Spring.SendCommands("globallos " .. playerAllyTeam())
end

local function cleanup()
	Test.clearMap()
	if not revealed then
		Spring.SendCommands("globallos " .. playerAllyTeam())
	end
end

local function test()
	local playerTeamID = Spring.GetLocalTeamID()
	local gaiaTeamID = Spring.GetGaiaTeamID()
	assert(countBase(playerTeamID) == 0, "the base must not be the player's before the mission arms")

	Spring.SendCommands("luarules mission smoke_handover")
	Test.waitUntil(function()
		return Spring.GetGameRulesParam("mission_active") == 1
	end, ARM_TIMEOUT)

	Test.waitFrames(FOG_HOLD_FRAMES)
	local gaiaBase = 0
	local gaiaInert = 0
	local gaiaArmed = 0
	for _, unitID in ipairs(Spring.GetTeamUnits(gaiaTeamID) or {}) do
		local unitDef = UnitDefs[Spring.GetUnitDefID(unitID)]
		if unitDef and BASE_DEFS[unitDef.name] then
			gaiaBase = gaiaBase + 1
			if Spring.GetUnitNeutral(unitID) then
				gaiaInert = gaiaInert + 1
			end
			-- Only units that can shoot: fire state is meaningless on a lab.
			if #(unitDef.weapons or {}) > 0 then
				local states = Spring.GetUnitStates(unitID) or {}
				if (states.firestate or 2) > 0 then
					gaiaArmed = gaiaArmed + 1
				end
			end
		end
	end
	assert(gaiaBase > 0, "the base should still be gaia's at this point")
	assert(gaiaInert == gaiaBase, ("every unheld base unit must be inert, %d of %d were"):format(gaiaInert, gaiaBase))
	-- Neutral only stops it being SHOT AT; holding fire is what stops it
	-- shooting the player who came to find it.
	assert(gaiaArmed == 0, ("%d unheld base weapons were still willing to open fire"):format(gaiaArmed))
	assert(countBase(playerTeamID) == 0, "the base must not change hands while the hub is unseen")

	Spring.SendCommands("globallos " .. playerAllyTeam())
	revealed = true

	-- Split deliberately: the latch answers "did the engine report the unit
	-- being seen", the transfer answers "did the trigger act on it".
	local allyTeamID = playerAllyTeam()
	Test.waitUntil(function()
		return Spring.GetGameRulesParam("mission_unit_spotted_hub_" .. tostring(allyTeamID)) == 1
	end, ARM_TIMEOUT)
	Test.waitUntil(function()
		return countBase(playerTeamID) >= 2
	end, ARM_TIMEOUT)
	assert(countBase(gaiaTeamID) == 0, "every unit in the group moves, or the player inherits half a base")

	-- And it gets its teeth back: hold fire is cleared on the handover, so an
	-- inherited base defends its new owner.
	for _, unitID in ipairs(Spring.GetTeamUnits(playerTeamID) or {}) do
		local unitDef = UnitDefs[Spring.GetUnitDefID(unitID)]
		if unitDef and BASE_DEFS[unitDef.name] and #(unitDef.weapons or {}) > 0 then
			local states = Spring.GetUnitStates(unitID) or {}
			assert((states.firestate or 0) > 0, "an inherited weapon must be willing to fire for its new owner")
		end
	end
end

return { skip = skip, setup = setup, cleanup = cleanup, test = test }
