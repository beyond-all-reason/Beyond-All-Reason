function setup()
	Test.clearMap()
	Test.expectCallin("UnitCreated")
end

function cleanup()
	Test.clearMap()
end

function test()
	Spring.Echo("[test_wait] waiting 5 frames")
	Test.waitFrames(5)

	local x, z = Game.mapSizeX / 2, Game.mapSizeZ / 2
	local y = Spring.GetGroundHeight(x, z)

	createdUnitID = SyncedRun(function(locals)
		return Spring.CreateUnit("armpw", locals.x, locals.y, locals.z, 0, 0)
	end)

	Spring.Echo("[test_wait] waiting for UnitCreated on unitID=" .. createdUnitID)
	Test.waitUntilCallin("UnitCreated", function(unitID, unitDefID, unitTeam, builderID)
		Spring.Echo("Saw UnitCreated for unitID=" .. unitID)
		return unitID == createdUnitID
	end, 10)

	startFrame = SyncedProxy.Spring.GetGameFrame()

	Spring.Echo("[test_wait] waiting 3 frames, but the hard way")
	Test.waitUntil(function()
		return (Spring.GetGameFrame() - startFrame > 3)
	end)

	Spring.Echo("[test_wait] waiting 1000 ms")
	Test.waitTime(1000)
end
