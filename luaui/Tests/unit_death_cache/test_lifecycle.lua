local function setup()
	Test.clearMap()
end

local function cleanup()
	Test.clearMap()
end

local function test()
	SyncedRun(function()
		local dead = assert(gadgetHandler.GG.IsUnitDead, "Unit Death Cache is unavailable")
		local x, z = Game.mapSizeX / 2, Game.mapSizeZ / 2
		local y = Spring.GetGroundHeight(x, z) + 200
		local transport = assert(Spring.CreateUnit("armatlas", x, y, z, 0, 0))
		local cargo = assert(Spring.CreateUnit("armpw", x, y, z, 0, 0))
		Spring.UnitAttach(transport, cargo, 0, true)
		assert(Spring.GetUnitTransporter(cargo) == transport)
		assert(dead[transport] == false)
		assert((function()
			for id, value in pairs(dead) do
				if id == transport then
					return value
				end
			end
		end)() == nil, "live transports must not be cached")
		local observed
		local observer = {
			UnitUnloaded = function(_, _, _, _, transportID)
				if transportID == transport then
					observed = { Spring.GetUnitIsDead(transport), dead[transport] }
				end
			end,
		}
		local list = gadgetHandler.UnitUnloadedList
		list[#list + 1] = observer
		local ok, err = pcall(Spring.DestroyUnit, transport, false, true)
		for i = #list, 1, -1 do
			if list[i] == observer then
				table.remove(list, i)
			end
		end
		assert(ok, err)
		assert(
			observed and observed[1] == true and observed[2] == true,
			"cargo callback must see dead transport before its UnitDestroyed"
		)
	end)
	local unitID = SyncedRun(function()
		local dead = assert(gadgetHandler.GG.IsUnitDead, "Unit Death Cache is unavailable")
		local x, z = Game.mapSizeX / 2, Game.mapSizeZ / 2
		local unitID = assert(Spring.CreateUnit("armpw", x, Spring.GetGroundHeight(x, z), z, 0, 0))
		assert(dead[unitID] == false)
		assert((function()
			for id, value in pairs(dead) do
				if id == unitID then
					return value
				end
			end
		end)() == false, "live non-transport should be cached")
		Spring.DestroyUnit(unitID, false, true)
		assert(dead[unitID] == true, "death must be published synchronously")
		return unitID
	end)
	Test.waitFrames(2 * 10 * Game.gameSpeed + 1)
	SyncedRun(function(locals)
		local dead = gadgetHandler.GG.IsUnitDead
		assert((function()
			for id, value in pairs(dead) do
				if id == locals.unitID then
					return value
				end
			end
		end)() == nil, "death entry must expire")
		assert(dead[locals.unitID] == true, "expired missing unit must remain invalid")
	end)
end

return { setup = setup, test = test, cleanup = cleanup }
