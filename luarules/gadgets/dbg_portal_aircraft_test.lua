-- This file is part of Beyond All Reason (GPL v2 or later), see LICENSE.
function gadget:GetInfo()
	return { name = "Portal fixed-wing routing regression", layer = -100, enabled = true }
end
local mode = Spring.GetModOptions().portal_worlds_test
if not gadgetHandler:IsSyncedCode() or not ({aircraft=true, ["aircraft-diagonal"]=true, ["aircraft-multihop"]=true})[mode] then
	return false
end
local world = VFS.Include("luarules/utilities/portal_worlds.lua")
local aircraft, arrived = {}, {}
local destination = mode == "aircraft" and 2 or 4
function gadget:GameFrame(frame)
	for id in pairs(aircraft) do
		if GG.PortalWorlds.home[id] == destination then arrived[id] = true end
	end
	if frame == 30 then
		for _, entry in ipairs(world.teams) do
			if entry.team % 2 == 1 and not (mode == "aircraft-multihop" and entry.region == 4) then
				for _, id in ipairs(Spring.GetTeamUnits(entry.team)) do
					if UnitDefs[Spring.GetUnitDefID(id)].customParams.iscommander then
						Spring.DestroyUnit(id, false, false)
						break
					end
				end
			end
		end
	elseif frame == 120 then
		assert(GG.PortalWorlds.mouths[1])
		local a, b = world.regions[1], world.regions[destination]
		for i, name in ipairs({"armthund", "armliche", "armpeep", "armfig", "armbrawl"}) do
			local id = assert(Spring.CreateUnit(name, a.x1 - 100, 600, a.z1 - 100 - i * 80, 0, 0))
			aircraft[id] = name
			Spring.GiveOrderToUnit(id, CMD.FIRE_STATE, {0}, 0)
			Spring.GiveOrderToUnit(id, CMD.FIGHT, {(b.x0+b.x1)/2, 0, (b.z0+b.z1)/2}, 0)
		end
	elseif frame == 3600 then
		local failures = 0
		for id, name in pairs(aircraft) do
			local passed = arrived[id] or false
			if not passed then failures = failures + 1 end
			Spring.Echo("[PORTAL_AIRCRAFT] ASSERT " .. name .. " pass=" .. tostring(passed))
		end
		Spring.Echo("[PORTAL_AIRCRAFT] DONE checks=5 failures=" .. failures)
		Spring.SendCommands("quitforce")
	end
end
