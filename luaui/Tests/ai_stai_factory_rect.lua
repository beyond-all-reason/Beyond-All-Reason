local factoryRect = VFS.Include("common/stai_factory_rect.lua")

local unitTable = {
	fac_unknown_exit = { xsize = 10, zsize = 12, buildOptions = true },
	fac_known_exit = { xsize = 8, zsize = 6, buildOptions = true },
	fac_air_exit = { xsize = 5, zsize = 7, buildOptions = true },
	builder = { xsize = 3, zsize = 4 },
}

local factoryExitSides = {
	fac_known_exit = 2, -- explicit exit side
	fac_air_exit = 0, -- air factory marker
}

local function assertRect(expectedX, expectedZ, got)
	assert(got, "expected rect outsets, got nil")
	assert(got.outX == expectedX, ("outX mismatch: expected %d, got %s"):format(expectedX, tostring(got.outX)))
	assert(got.outZ == expectedZ, ("outZ mismatch: expected %d, got %s"):format(expectedZ, tostring(got.outZ)))
end

function test_factory_apron_for_unknown_exit()
	-- Factories not listed in factoryExitSides get the generous apron.
	local got = factoryRect.getOutsets("fac_unknown_exit", unitTable, factoryExitSides)
	assertRect(10 * 6, 12 * 9, got)
end

function test_air_factory_uses_default_rect()
	-- Air factories (exit side 0) should fall back to default building spacing, not apron/lane.
	local got = factoryRect.getOutsets("fac_air_exit", unitTable, factoryExitSides)
	assertRect(5 * 4, 7 * 4, got)
end

function test_default_rect_for_non_factory()
	local got = factoryRect.getOutsets("builder", unitTable, factoryExitSides)
	assertRect(3 * 4, 4 * 4, got)
end

function test_nil_when_exit_side_known()
	local got = factoryRect.getOutsets("fac_known_exit", unitTable, factoryExitSides)
	assert(got == nil, "expected nil when exit side is known (lane handled elsewhere)")
end

function test()
	test_factory_apron_for_unknown_exit()
	test_air_factory_uses_default_rect()
	test_default_rect_for_non_factory()
	test_nil_when_exit_side_known()
end
