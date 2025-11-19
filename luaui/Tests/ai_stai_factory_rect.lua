local factoryRect = VFS.Include("common/stai_factory_rect.lua")

local unitTable = {
	fac_unknown_exit = { xsize = 10, zsize = 12, buildOptions = true },
	builder = { xsize = 3, zsize = 4 },
}

local factoryExitSides = {} -- unknown exit side for fac_unknown_exit

local function assertRect(expectedX, expectedZ, got)
	assert(got, "expected rect outsets, got nil")
	assert(got.outX == expectedX, ("outX mismatch: expected %d, got %s"):format(expectedX, tostring(got.outX)))
	assert(got.outZ == expectedZ, ("outZ mismatch: expected %d, got %s"):format(expectedZ, tostring(got.outZ)))
end

function test_factory_apron_for_unknown_exit()
	-- For factories without an explicit exit side, we reserve a generous apron.
	local got = factoryRect.getOutsets("fac_unknown_exit", unitTable, factoryExitSides)
	assertRect(10 * 6, 12 * 9, got)
end

function test_default_rect_for_non_factory()
	local got = factoryRect.getOutsets("builder", unitTable, factoryExitSides)
	assertRect(3 * 4, 4 * 4, got)
end

function test_nil_when_exit_side_known()
	factoryExitSides.fac_unknown_exit = 2
	local got = factoryRect.getOutsets("fac_unknown_exit", unitTable, factoryExitSides)
	assert(got == nil, "expected nil when exit side is known (lane handled elsewhere)")
end

function test()
	test_factory_apron_for_unknown_exit()
	test_default_rect_for_non_factory()
	test_nil_when_exit_side_known()
end
