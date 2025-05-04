
function sanityChecks()
	-- Just to make sure some standard methods used here work as expected.
	Spring.GiveOrderToUnit(2, CMD.FIRE_STATE, {0}, {})
	SyncedProxy.Spring.ValidUnitID(20)
	local res, err = pcall(function()
		Spring.GiveOrderToUnit(2, CMD.FIRE_STATE, {0}, {})
	end)
	assert(err ~= "attempt to yield across metamethod/C-call boundary")
end

function failingTests()
	-- All of these fail due to error "attempt to yield across metamethod/C-call boundary"
	-- This is something to do with how the test system is structured.
	local res, err = pcall(function()
		SyncedRun(function()
			Spring.ValidUnitID(20)
		end)
	end)
	assert(err ~= "attempt to yield across metamethod/C-call boundary")

	local res, err = pcall(function()
		SyncedProxy.Spring.ValidUnitID(20)
	end)
	assert(err ~= "attempt to yield across metamethod/C-call boundary")

	local res, bla = pcall(function()
		Test.waitUntil(function()
			return true
		end)
	end)
	assert(err ~= "attempt to yield across metamethod/C-call boundary")

	assertThrowsMessage(function()
		SyncedProxy.Spring.ValidUnitID(20)
		error("error")
	end, "error")

	assertThrowsMessage(function()
		SyncedProxy.Spring.GiveOrderToUnit(20, CMD.FIRE_STATE, {0}, {})
	end, "[GiveOrderToUnit] invalid unitID")

	assertThrowsMessage(function()
		assertSuccessBefore(1, 10, function() return false end, "error")
	end, "error")

	assertThrowsMessage(function()
		Test.waitUntil(function()
			error("error")
		end, 1)
	end, "error")

	-- this ones can get stuck forever:
	--Test.waitUntil(function()
	--	SyncedRun(function()
	--		Spring.ValidUnitID(20)
	--	end)
	--end, 1)
	--Test.waitUntil(function()
	--	SyncedProxy.Spring.ValidUnitID(20)
	--end, 1)
	--
end

function failingWhileSucceedingTests()
	-- these ones are actually failing even when they don't throw exceptions,
	-- it's because assertThrows is catching the exception, it's just not
	-- the one we want.

	assertThrows(function()
		-- this test should fail since ValidUnitID doesn't throw exceptions.
		SyncedProxy.Spring.ValidUnitID(20)
	end)
	assertThrows(function()
		-- this actually throws an exception, but due to something else.
		SyncedProxy.Spring.GiveOrderToUnit(2, CMD.FIRE_STATE, {0}, {})
	end)
end

function testWaitUntil()
	Test.waitUntil(function()
		return true
	end)
end

function testAssertSuccessBefore()
	-- test the method succeeding
	assertSuccessBefore(1, 10, function() return true end)
	assertSuccessBefore(1, 10, function()
		-- SyncedProxy works here
		SyncedProxy.Spring.ValidUnitID(20)
		return true
	end)
	-- test the method never succeeding in the alloted time
	assertThrowsMessage(function()
		assertSuccessBefore(1, 10, function() error("error") end)
	end, "error")
end

function testAssertThrows()
	-- test detecting an exception
	assertThrows(function()
		error("error")
	end)
	-- test detecting an assertion
	assertThrows(function()
		assert(false)
	end)
	-- test assert throws an error when the function doesn't
	assertThrows(function()
		assertThrows(function() return true end)
	end)
	assertThrows(function()
		Spring.ValidUnitID(20)
		error("error")
	end)
end

function testAssertThrowsMessage()
	-- test throwing a specific message
	assertThrowsMessage(function()
		error("error")
	end, "error")
	-- test assertion throwing a specific message
	assertThrowsMessage(function()
		assert(false, "error")
	end, "error")
	-- test if works when the error has brackets
	assertThrowsMessage(function()
		error("[error]")
	end, "[error]")
	-- test it works when error ends the same as the error
	assertThrows(function()
		assertThrowsMessage(function() error("another error") end, "error")
	end)
	-- test our splitting method works when the error has the same pattern
	assertThrowsMessage(function()
		error('[string "LuaUI/Widgets/tests/selftests/test_assertions.lua"]:17: error2')
	end, '[string "LuaUI/Widgets/tests/selftests/test_assertions.lua"]:17: error2')

	-- test other methods setting the error message
	assertThrowsMessage(function()
		assert(false, "error")
	end, "error")
	assertThrowsMessage(function()
		Spring.ValidUnitID(20)
		error("error")
	end, "error")
end

function test()
	sanityChecks()
	testWaitUntil()
	testAssertThrows()
	testAssertSuccessBefore()
	testAssertThrowsMessage()
	--failingTests()
	failingWhileSucceedingTests()
end
