function setup()
	Test.clearMap()
	Test.expectCallin("UnitCreated")
end

function cleanup()
	Test.clearMap()
end

function test()
	Engine.Shared.Echo("[test_wait] waiting 5 frames")
	Test.waitFrames(5)

	local x, z = Game.mapSizeX / 2, Game.mapSizeZ / 2
	local y = Engine.Shared.GetGroundHeight(x, z)

	createdUnitID = SyncedRun(function(locals)
		return Engine.Synced.CreateUnit("armpw", locals.x, locals.y, locals.z, 0, 0)
	end)

	Engine.Shared.Echo("[test_wait] waiting for UnitCreated on unitID=" .. createdUnitID)
	Test.waitUntilCallin("UnitCreated", function(unitID, unitDefID, unitTeam, builderID)
		Engine.Shared.Echo("Saw UnitCreated for unitID=" .. unitID)
		return unitID == createdUnitID
	end, 10)

	startFrame = SyncedProxy.Spring.GetGameFrame()

	Engine.Shared.Echo("[test_wait] waiting 3 frames, but the hard way")
	Test.waitUntil(function()
		return (Engine.Shared.GetGameFrame() - startFrame > 3)
	end)

	Engine.Shared.Echo("[test_wait] waiting 1000 ms")
	Test.waitTime(1000)
end
