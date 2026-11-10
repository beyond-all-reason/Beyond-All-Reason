local function loadGadget(wreckage)
	local frame = 10
	local live, dead, destroyed = {}, {}, {}
	local onDestroy
	local env = {
		gadget = {},
		gadgetHandler = {
			UpdateCallIn = function() end,
			RemoveCallIn = function() end,
			IsSyncedCode = function()
				return true
			end,
		},
		Game = { mapSizeX = 6144, mapSizeZ = 10240 },
		GG = { wipeoutWithWreckage = wreckage },
		UnitDefs = { { customParams = {}, weapons = {} } },
		math = setmetatable({
			distance2dSquared = function()
				return 0
			end,
		}, { __index = math }),
	}
	env.Spring = {
		GetGaiaTeamID = function()
			return 99
		end,
		GetTeamInfo = function()
			return 0, 0, false, false, 0, 99
		end,
		GetGameFrame = function()
			return frame
		end,
		GetTeamUnits = function()
			return {}
		end,
		GetUnitPosition = function()
			return 0, 0, 0
		end,
		GetUnitDefID = function()
			return 1
		end,
		ValidUnitID = function(id)
			return live[id] == true
		end,
		GetUnitIsDead = function(id)
			return dead[id] == true
		end,
		DestroyUnit = function(id, selfD, reclaimed)
			destroyed[#destroyed + 1] = { id, selfD, reclaimed }
			live[id] = nil
			if env.gadget.UnitDestroyed then
				env.gadget:UnitDestroyed(id)
			end
			if onDestroy then
				onDestroy(id)
			end
		end,
	}
	setmetatable(env, { __index = _G })
	local chunk = assert(loadfile("luarules/gadgets/game_team_death_effect.lua"))
	setfenv(chunk, env)
	chunk()
	env.GG.wipeoutTeam(1)
	return {
		gadget = env.gadget,
		live = live,
		dead = dead,
		destroyed = destroyed,
		advance = function(f)
			frame = f
			env.gadget:GameFrame(f)
		end,
		onDestroy = function(fn)
			onDestroy = fn
		end,
	}
end

describe("Team death callback safety", function()
	it("defers creation/completion destruction until the next frame and deduplicates it", function()
		local t = loadGadget(false)
		t.live[1] = true
		t.gadget:UnitCreated(1, 1, 1)
		t.gadget:UnitFinished(1, 1, 1)
		assert.same({}, t.destroyed)
		t.advance(10)
		assert.same({}, t.destroyed)
		t.advance(11)
		assert.same({ { 1, true, false } }, t.destroyed)
		t.advance(12)
		assert.equals(1, #t.destroyed)
	end)

	it("leaves units of surviving teams alone", function()
		local t = loadGadget(false)
		t.live[2] = true
		t.gadget:UnitCreated(2, 1, 2)
		t.gadget:UnitFinished(2, 1, 2)
		t.advance(11)
		assert.same({}, t.destroyed)
	end)

	it("preserves the wipeout wreckage mode", function()
		local t = loadGadget(true)
		t.live[3] = true
		t.gadget:UnitFinished(3, 1, 1)
		t.advance(11)
		assert.same({ { 3, false, false } }, t.destroyed)
	end)

	it("does not destroy a surviving unit that reuses a queued ID", function()
		local t = loadGadget(false)
		t.live[4] = true
		t.gadget:UnitFinished(4, 1, 1)
		if t.gadget.UnitDestroyed then
			t.gadget:UnitDestroyed(4)
		end
		t.gadget:UnitCreated(4, 1, 2)
		t.advance(11)
		assert.same({}, t.destroyed)
	end)

	it("handles ID reuse for another doomed unit without duplicate destruction", function()
		local t = loadGadget(false)
		t.live[5] = true
		t.gadget:UnitFinished(5, 1, 1)
		if t.gadget.UnitDestroyed then
			t.gadget:UnitDestroyed(5)
		end
		t.gadget:UnitCreated(5, 1, 1)
		t.gadget:UnitFinished(5, 1, 1)
		t.advance(11)
		assert.same({ { 5, true, false } }, t.destroyed)
	end)

	it("skips invalid or already dying units", function()
		local t = loadGadget(false)
		t.live[6] = true
		t.dead[6] = true
		t.gadget:UnitFinished(6, 1, 1)
		t.gadget:UnitFinished(7, 1, 1)
		t.advance(11)
		assert.same({}, t.destroyed)
	end)

	it("defers units created by a destruction callback until another frame", function()
		local t = loadGadget(false)
		t.live[8], t.live[9] = true, true
		t.gadget:UnitFinished(8, 1, 1)
		t.onDestroy(function(id)
			if id == 8 then
				t.gadget:UnitCreated(9, 1, 1)
				t.gadget:UnitFinished(9, 1, 1)
			end
		end)
		t.advance(11)
		assert.same({ { 8, true, false } }, t.destroyed)
		t.advance(12)
		assert.same({ { 8, true, false }, { 9, true, false } }, t.destroyed)
	end)

	it("honors cancellation and ID reuse during the same destruction batch", function()
		local t = loadGadget(false)
		t.live[10], t.live[11] = true, true
		t.gadget:UnitFinished(10, 1, 1)
		t.gadget:UnitFinished(11, 1, 1)
		t.onDestroy(function(id)
			if id == 10 then
				if t.gadget.UnitDestroyed then
					t.gadget:UnitDestroyed(11)
				end
				t.gadget:UnitCreated(11, 1, 2)
			end
		end)
		t.advance(11)
		assert.same({ { 10, true, false } }, t.destroyed)
	end)
end)
