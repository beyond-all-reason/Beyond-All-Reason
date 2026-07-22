local ShareStats = VFS.Include("modules/economy/share_stats.lua")
local ResourceTypes = VFS.Include("gamedata/resource_types.lua")

local METAL = ResourceTypes.METAL
local ENERGY = ResourceTypes.ENERGY

-- minimal rules-param backed Spring: the only surface ShareStats touches
local function fakeSpring()
	local store = {}
	return {
		SetTeamRulesParam = function(teamID, key, value)
			store[teamID] = store[teamID] or {}
			store[teamID][key] = value
		end,
		GetTeamRulesParam = function(teamID, key)
			return store[teamID] and store[teamID][key] or nil
		end,
	}
end

describe("ShareStats", function()
	it("publishes net per-team sent/received and reads them back", function()
		local spring = fakeSpring()
		ShareStats.Publish(spring, {
			{ teamId = 0, resourceType = METAL, sent = 100, received = 0, excess = 0 },
			{ teamId = 1, resourceType = METAL, sent = 0, received = 90, excess = 0 },
		})
		assert.is_near(100, ShareStats.Read(spring, 0, METAL).sent, 1e-6)
		assert.is_near(90, ShareStats.Read(spring, 1, METAL).received, 1e-6)
		-- recent send/received mirror the last tick (top bar + GG.GetTeamResources overlay)
		assert.is_near(100, ShareStats.Read(spring, 0, METAL).sentRecent, 1e-6)
		assert.is_near(90, ShareStats.Read(spring, 1, METAL).receivedRecent, 1e-6)
	end)

	it("accumulates cumulative totals across ticks while recent tracks only the latest", function()
		local spring = fakeSpring()
		local tick = { { teamId = 0, resourceType = METAL, sent = 10, received = 0 } }
		ShareStats.Publish(spring, tick)
		ShareStats.Publish(spring, tick)
		ShareStats.Publish(spring, tick)
		assert.is_near(30, ShareStats.Read(spring, 0, METAL).sent, 1e-6)
		assert.is_near(10, ShareStats.Read(spring, 0, METAL).sentRecent, 1e-6)
	end)

	it("returns nil before anything is published, so callers can fall back to engine values", function()
		local spring = fakeSpring()
		local s = ShareStats.Read(spring, 0, METAL)
		assert.is_nil(s.sent)
		assert.is_nil(s.received)
		assert.is_nil(s.sentRecent)
	end)

	it("keeps metal and energy independent", function()
		local spring = fakeSpring()
		ShareStats.Publish(spring, {
			{ teamId = 0, resourceType = METAL, sent = 5, received = 0 },
			{ teamId = 0, resourceType = ENERGY, sent = 0, received = 7 },
		})
		assert.is_near(5, ShareStats.Read(spring, 0, METAL).sent, 1e-6)
		assert.is_near(7, ShareStats.Read(spring, 0, ENERGY).received, 1e-6)
		assert.is_near(0, ShareStats.Read(spring, 0, METAL).received, 1e-6)
	end)
end)
