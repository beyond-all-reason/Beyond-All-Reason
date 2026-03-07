local function loadNormalized(path)
	local contents = assert(VFS.LoadFile(path), "missing file: " .. path)
	contents = contents:gsub("//[^\n]*", "")
	contents = contents:gsub("%s+", " ")
	return contents
end

local function getSection(contents, sectionName)
	local pattern = '"' .. sectionName .. '"%s*:%s*(%b{})'
	local section = contents:match(pattern)
	assert(section, "missing section: " .. sectionName)
	return section
end

local function assertFactoryYard(path, sectionName, expectedX, expectedZ)
	local contents = loadNormalized(path)
	local section = getSection(contents, sectionName)
	local yardPattern = '"yard"%s*:%s*%[%s*%d+%s*,%s*%d+%s*%]'
	local yard = section:match(yardPattern)
	assert(yard, string.format("missing yard entry for %s in %s", sectionName, path))

	local expectedPattern = '"yard"%s*:%s*%[%s*' .. expectedX .. '%s*,%s*' .. expectedZ .. '%s*%]'
	assert(
		yard:match(expectedPattern),
		string.format("unexpected yard for %s in %s: %s", sectionName, path, yard)
	)
end

local HARD_PATH = "LuaRules/Configs/BARb/stable/config/hard/block_map.json"
local HARD_AGGRESSIVE_PATH = "LuaRules/Configs/BARb/stable/config/hard_aggressive/block_map.json"

function test_hard_block_map_widens_t1_land_factory_lane()
	assertFactoryYard(HARD_PATH, "fac_land_t1", 8, 30)
end

function test_hard_block_map_widens_t2_land_factory_lane()
	assertFactoryYard(HARD_PATH, "fac_land_t2", 16, 20)
end

function test_hard_aggressive_block_map_keeps_same_factory_clearance()
	assertFactoryYard(HARD_AGGRESSIVE_PATH, "fac_land_t1", 8, 30)
	assertFactoryYard(HARD_AGGRESSIVE_PATH, "fac_land_t2", 16, 20)
end

function test()
	test_hard_block_map_widens_t1_land_factory_lane()
	test_hard_block_map_widens_t2_land_factory_lane()
	test_hard_aggressive_block_map_keeps_same_factory_clearance()
end
