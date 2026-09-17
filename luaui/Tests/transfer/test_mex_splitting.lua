
function skip()
	return Spring.GetGameFrame() <= 1 or Spring.GetModOptions().mex_splitting ~= "map_assigned"
end

function setup()
	Test.clearMap()
end

function cleanup()
	Test.clearMap()
end

function test()
	local myTeamID = Spring.GetLocalTeamID()
	local mexDefID = UnitDefNames.armmex.id
	local builderName = "armck"

	local spots = SyncedRun(function(locals)
		local state = gadgetHandler.GG.__moduleState.transfer ---@type TransferState
		assert(state and state.mexRegions and state.mexDeal, "transfer has not dealt the regions")
		local Holders = VFS.Include("modules/transfer/mex_splitting/holders.lua") ---@type MexRegionsHolders
		local mine, theirs
		for _, spot in ipairs(gadgetHandler.GG.resource_spot_finder.metalSpotsList) do
			local holders = Holders.At(Spring, spot.x, spot.z)
			local held = false
			for _, teamID in ipairs(holders) do
				held = held or teamID == locals.myTeamID
			end
			if held and mine == nil then
				mine = { x = spot.x, z = spot.z }
			elseif #holders > 0 and not held and theirs == nil then
				theirs = { x = spot.x, z = spot.z }
			end
		end
		return { mine = mine, theirs = theirs }
	end)
	assert(spots.mine, "no metal spot inside a region my team holds")
	assert(spots.theirs, "no metal spot inside a region my ally holds")

	local function orderMexAt(spot)
		local x, z, builder, defID, teamID = spot.x, spot.z, builderName, mexDefID, myTeamID
		local queued = SyncedRun(function(locals)
			local y = Spring.GetGroundHeight(locals.x, locals.z)
			local builderID = Spring.CreateUnit(locals.builder, locals.x + 120, y, locals.z + 120, 0, locals.teamID)
			assert(builderID, "failed to create " .. locals.builder)
			Spring.GiveOrderToUnit(builderID, -locals.defID, { locals.x, y, locals.z, 0 }, 0)
			return Spring.GetUnitCommandCount(builderID)
		end)
		return queued
	end

	-- the same rule, asked from the UI side: what a widget colours a spot by
	-- the test sandbox lacks what every widget has; give the module the environment a widget would
	local widgetLike = {
		getmetatable = debug.getmetatable,
		setmetatable = function(t, mt)
			debug.setmetatable(t, mt)
			return t
		end,
	}
	debug.setmetatable(widgetLike, { __index = debug.getfenv(test) })
	local Construction = VFS.Include("modules/construction/api.lua", widgetLike) ---@type ConstructionApi
	assertEqual(
		Construction.MayPlaceMexAt(myTeamID, spots.mine.x, spots.mine.z),
		true,
		"my own spot should read as open to me"
	)
	assertEqual(
		Construction.MayPlaceMexAt(myTeamID, spots.theirs.x, spots.theirs.z),
		false,
		"my ally's spot should read as closed to me"
	)

	assertEqual(orderMexAt(spots.theirs), 0, "a mex order on a spot my ally holds should be refused")
	assertEqual(orderMexAt(spots.mine), 1, "a mex order on a spot my team holds should queue")
end

return { skip = skip, setup = setup, test = test, cleanup = cleanup }
