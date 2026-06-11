function test()
	mock_SpringGetModKeyState = Test.mock(Spring, "GetModKeyState", function()
		return true, false, true, false
	end)

	assertTablesEqual(pack(Engine.Unsynced.GetModKeyState()), { true, false, true, false })

	assert(#mock_SpringGetModKeyState.calls == 1)
end
