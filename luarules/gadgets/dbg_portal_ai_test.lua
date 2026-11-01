-- SPDX-License-Identifier: GPL-2.0-or-later
function gadget:GetInfo()
	return {
		name = "Portal AI playtest",
		desc = "Opt-in ordinary BAR AI economy and portal opening",
		author = "Codex",
		license = "GPL v2 or later",
		layer = 10000,
		enabled = true,
	}
end
if not gadgetHandler:IsSyncedCode() or Spring.GetModOptions().portal_worlds_test ~= "ai" then
	return false
end
local factories, created = {}, {}
function gadget:UnitCreated(id, def, team)
	created[team] = (created[team] or 0) + 1
	if UnitDefs[def].isFactory then
		factories[team] = true
	end
end
local function Check(key, pass, detail)
	Spring.Echo("[BAR_AI_TEST] ASSERT " .. key .. " pass=" .. tostring(not not pass) .. " " .. tostring(detail or ""))
end
function gadget:GameFrame(f)
	if f == 3000 then
		for _, entry in ipairs(GG.PortalWorlds.world.teams) do
			Check("factory_built_" .. entry.team, factories[entry.team])
			Check("economy_built_units_" .. entry.team, (created[entry.team] or 0) >= 8, created[entry.team])
		end
		for _, id in ipairs(Spring.GetTeamUnits(1) or {}) do
			if UnitDefs[Spring.GetUnitDefID(id)].customParams.iscommander then
				Spring.SetUnitHealth(id, 1)
				Spring.AddUnitDamage(id, 100000)
				break
			end
		end
	elseif f == 6000 then
		Check("ai_match_portal_open", Spring.GetGameRulesParam("portal_open") == 1)
		Check("ai_match_still_running", #Spring.GetAllUnits() > 20, #Spring.GetAllUnits())
		Spring.Echo("[BAR_AI_TEST] PASS_END passages=" .. tostring(Spring.GetGameRulesParam("portal_passages") or 0))
	end
end
