-- Region ownership, command filtering and LuaRules reload on a two-region map.
local SpecEnv = VFS.Include("spec/support/spec_env.lua")
local GameCommands = VFS.Include("modules/customcommands.lua").GameCMD
local commandIDs = {}
for i, name in ipairs({
	"ANY",
	"ONOFF",
	"FIRE_STATE",
	"MOVE_STATE",
	"REPEAT",
	"CLOAK",
	"STOCKPILE",
	"TRAJECTORY",
	"IDLEMODE",
	"AUTOREPAIRLEVEL",
	"REMOVE",
	"TIMEWAIT",
	"SQUADWAIT",
	"GATHERWAIT",
	"MOVE",
	"FIGHT",
	"PATROL",
	"ATTACK",
	"GUARD",
	"REPAIR",
	"RECLAIM",
	"RESURRECT",
	"CAPTURE",
	"LOAD_UNITS",
	"LOAD_ONTO",
	"MANUALFIRE",
	"AREA_ATTACK",
	"RESTORE",
	"UNLOAD_UNIT",
	"UNLOAD_UNITS",
}) do
	commandIDs[name] = i
end
local GADGET = "luarules/gadgets/game_map_regions.lua"
local manifest = {
	schema = 1,
	size = { 1024, 256 },
	regions = {
		{ id = "a", x0 = 0, z0 = 0, x1 = 256, z1 = 256, width = 256, height = 256 },
		{ id = "b", x0 = 768, z0 = 0, x1 = 1024, z1 = 256, width = 256, height = 256 },
	},
}

local function fixture(mapManifest)
	local units = { [1] = { x = 64, z = 64 }, [2] = { x = 800, z = 64 } }
	local unitRules = {}
	local features = { [1] = 64, [2] = 800, [3] = 512 }
	local state = { frame = 0, accepted = true, regionCalls = 0, gameRules = {}, cmdTypes = {}, cmdDescCalls = 0 }
	state.projectileOwners = {}
	state.damage = {}
	local env = SpecEnv.new({
		gadget = {},
		CMD = commandIDs,
		GameCMD = GameCommands,
		CMDTYPE = {
			ICON = 0,
			ICON_MODE = 5,
			ICON_MAP = 10,
			ICON_AREA = 11,
			NUMBER = 23,
			ICON_UNIT = 12,
			ICON_UNIT_OR_MAP = 13,
			ICON_UNIT_OR_AREA = 16,
			ICON_UNIT_FEATURE_OR_AREA = 19,
			ICON_UNIT_OR_RECTANGLE = 22,
		},
		UnitDefs = { { isImmobile = false }, { isImmobile = true } },
		gadgetHandler = {
			IsSyncedCode = function()
				return true
			end,
			RegisterAllowCommand = function() end,
		},
		Engine = { FeatureSupport = { mapRegionViews = true, sensorRegions = true, mapDamageRegions = true } },
		Game = { mapSizeX = 1024, mapSizeZ = 256, maxUnits = 32000 },
		includes = { ["mapconfig/map_regions.lua"] = mapManifest or manifest },
		Spring = {
			AddUnitDamage = function(id, amount)
				state.damage[id] = (state.damage[id] or 0) + amount
			end,
			ValidFeatureID = function(id)
				return features[id] ~= nil
			end,
			GetFeaturePosition = function(id)
				return features[id], 0, 64
			end,
			GetProjectileOwnerID = function(id)
				return state.projectileOwners[id]
			end,
			GetGameFrame = function()
				return state.frame
			end,
			GetAllUnits = function()
				local ids = {}
				for id in pairs(units) do
					ids[#ids + 1] = id
				end
				table.sort(ids)
				return ids
			end,
			GetUnitDefID = function(id)
				return units[id] and (units[id].def or 1)
			end,
			GetUnitPosition = function(id)
				local u = units[id]
				if u then
					return u.x, 0, u.z
				end
			end,
			GetUnitRulesParam = function(id, key)
				return unitRules[id] and unitRules[id][key]
			end,
			SetUnitRulesParam = function(id, key, value)
				unitRules[id] = unitRules[id] or {}
				unitRules[id][key] = value
			end,
			FindUnitCmdDesc = function(_, cmdID)
				return state.cmdTypes[cmdID] and cmdID
			end,
			GetUnitCmdDescs = function(_, cmdID)
				state.cmdDescCalls = state.cmdDescCalls + 1
				return { { type = state.cmdTypes[cmdID] } }
			end,
			ValidUnitID = function(id)
				return units[id] ~= nil
			end,
			GetUnitIsDead = function()
				return false
			end,
			GetUnitTransporter = function() end,
			GetUnitIsTransporting = function()
				return {}
			end,
			SetSensorRegions = function()
				state.regionCalls = state.regionCalls + 1
				return state.accepted
			end,
			SetMapDamageRegions = function()
				state.regionCalls = state.regionCalls + 1
				return state.accepted
			end,
			SetGameRulesParam = function(key, value)
				state.gameRules[key] = value
			end,
			GameOver = function()
				state.gameOver = true
			end,
			Echo = function() end,
			Log = function() end,
			SetTerrainTypeData = function() end,
			SetMapSquareTerrainType = function() end,
			SetSquareBuildingMask = function() end,
		},
	})
	local function reload()
		env.gadget = {}
		SpecEnv.include(env, GADGET)
		env.gadget:Initialize()
		return env.gadget
	end
	return env, units, unitRules, reload, state
end

describe("minimal map region ownership", function()
	it("rejects an area only when it can reach another region", function()
		local env, _, _, reload, state = fixture()
		local g = reload()
		state.cmdTypes[env.CMD.RECLAIM] = env.CMDTYPE.ICON_UNIT_FEATURE_OR_AREA
		assert.is_true(g:AllowCommand(1, 1, 0, env.CMD.RECLAIM, { 240, 0, 64, 500 }, {}))
		assert.is_false(g:AllowCommand(1, 1, 0, env.CMD.RECLAIM, { 240, 0, 64, 600 }, {}))
		assert.is_true(g:AllowCommand(1, 1, 0, -4, { 240, 0, 64, 3 }, {}))
		assert.is_false(g:AllowCommand(1, 1, 0, env.CMD.MOVE, { 800, 0, 64, 0, 0 }, {}))
		assert.is_false(g:AllowCommand(1, 1, 0, -4, { 800, 0, 64, 0, 0 }, {}))
		assert.is_false(g:AllowCommand(1, 1, 0, env.CMD.CAPTURE, { 2, 100, 0, 64, 30 }, {}))
		assert.is_true(g:AllowCommand(1, 1, 0, env.CMD.CAPTURE, { 1, 100, 0, 64, 30 }, {}))
		assert.is_false(g:AllowCommand(1, 1, 0, env.CMD.ATTACK, { 240, 0, 64, 600 }, {}))
		assert.is_true(g:AllowCommand(1, 1, 0, env.CMD.ATTACK, { 240, 0, 64, 0 }, {}))
		assert.is_false(g:AllowCommand(1, 1, 0, env.CMD.AREA_ATTACK, { 240, 0, 64, 600, 0 }, {}))
		assert.is_false(g:AllowCommand(1, 1, 0, env.CMD.RESURRECT, { 32002, 100, 0, 64, 30 }, {}))
		assert.is_true(g:AllowCommand(1, 1, 0, env.CMD.UNLOAD_UNIT, { 240, 0, 64, 600 }, {}))
		assert.is_false(g:AllowCommand(1, 1, 0, env.CMD.UNLOAD_UNITS, { 240, 0, 64, 600 }, {}))
		assert.is_false(g:AllowCommand(1, 1, 0, env.CMD.LOAD_UNITS, { 240, 0, 64, 600, 0 }, {}))
		assert.is_true(g:AllowCommand(1, 1, 0, 34000, { 240, 0, 64, -1 }, {}))
		assert.is_false(g:AllowCommand(1, 1, 0, env.CMD.PATROL, { 240, 0, 64, 800, 0, 64, 0 }, {}))
		state.cmdTypes[34000] = env.CMDTYPE.ICON_MAP
		assert.is_true(g:AllowCommand(1, 1, 0, 34000, { 240, 0, 64, 600 }, {}))
	end)

	it("checks ownership when an internally selected build or capture target is used", function()
		local _, units, _, reload = fixture()
		units[3] = { x = 128, z = 64 }
		local g = reload()
		assert.is_true(g:AllowUnitBuildStep(1, 0, 3, 1, 0.1))
		assert.is_false(g:AllowUnitBuildStep(1, 0, 2, 1, -0.1))
		assert.is_true(g:AllowFeatureBuildStep(1, 0, 1, 1, -0.1))
		assert.is_false(g:AllowFeatureBuildStep(1, 0, 2, 1, -0.1))
		assert.is_false(g:AllowFeatureBuildStep(1, 0, 3, 1, 0.1))
	end)

	it("checks structures in regions with surface damage", function()
		local surfaceManifest = {
			schema = manifest.schema,
			size = manifest.size,
			regions = {
				manifest.regions[1],
				{
					id = "b",
					x0 = 768,
					z0 = 0,
					x1 = 1024,
					z1 = 256,
					width = 256,
					height = 256,
					surface = { height = 0, damage = 5 },
				},
			},
		}
		local env, units, _, reload, state = fixture(surfaceManifest)
		units[3] = { x = 64, z = 64, def = 2 }
		units[4] = { x = 800, z = 64, def = 2 }
		local g = reload()
		for frame = 1, 30 do
			g:GameFrame(frame)
		end
		assert.is_nil(state.damage[3])
		assert.equal(5, state.damage[4])
		assert.is_nil(env.GG.MapRegions.SetUnitRegion)
	end)

	it("recovers dead attackers for immediate feature damage", function()
		local _, units, _, reload, state = fixture()
		local g = reload()
		g:UnitDestroyed(2)
		units[2] = nil
		state.projectileOwners[10] = 2
		assert.equal(100, (g:UnitPreDamaged(1, 1, 0, 100, false, 1, 10)))
		assert.equal(0, (g:FeaturePreDamaged(1, 1, 0, 100, 1, 10)))
		assert.equal(100, (g:UnitPreDamaged(1, 1, 0, 100, false, 1, 10, 1)))
		assert.equal(100, (g:UnitPreDamaged(1, 1, 0, 100, false, -1, -1)))
	end)

	it("registers units already present when LuaRules initializes", function()
		local _, _, rules, reload = fixture()
		reload()
		assert.is_table(rules[1])
		assert.equal(1, rules[1].map_region)
		assert.equal(2, rules[2].map_region)
	end)

	it("keeps assigned ownership when a displaced unit is reloaded", function()
		local env, units, _, reload = fixture()
		reload()
		units[1].x = 800
		reload()
		assert.equal(1, env.GG.MapRegions.UnitRegion(1))
	end)

	it("leaves engine regions alone when LuaRules reloads in a running game", function()
		local env, _, _, reload, state = fixture()
		reload()
		assert.equal(2, state.regionCalls)
		state.frame, state.accepted = 300, false
		reload()
		assert.equal(2, state.regionCalls)
		assert.equal(2, env.GG.MapRegions.UnitRegion(2))
		assert.is_false(env.gadget:AllowCommand(1, 1, 0, 100, { 800, 0, 64 }, {}))
	end)

	it("does not advertise regions and ends the game when the engine rejects them", function()
		local env, _, _, reload, state = fixture()
		state.accepted = false
		local g = reload()
		assert.is_nil(state.gameRules.map_regions)
		assert.is_nil(env.GG.MapRegions)
		g:GameFrame(1)
		assert.is_true(state.gameOver)
	end)

	it("assigns strip-spawned units to the nearest region", function()
		local env, units, _, reload = fixture()
		local g = reload()
		units[3] = { x = 500, z = 64 }
		g:UnitCreated(3, 1, 0)
		assert.equal(1, (env.GG.MapRegions.UnitRegion(3)))
	end)

	it("uses z coordinates for both corners of area set-target commands", function()
		local env, _, _, reload = fixture()
		local g = reload()
		assert.is_true(g:AllowCommand(1, 1, 0, env.GameCMD.UNIT_SET_TARGET_RECTANGLE, { 32, 900, 32, 96, 900, 96 }, {}))
		assert.is_false(g:AllowCommand(1, 1, 0, env.GameCMD.UNIT_SET_TARGET_RECTANGLE, { 32, 0, 32, 800, 0, 96 }, {}))
	end)

	it("reads a single parameter as a unit only for commands that target units", function()
		local env, _, _, reload, state = fixture()
		local g = reload()
		-- Unit 2 is in the other region.
		assert.is_false(g:AllowCommand(1, 1, 0, env.CMD.ATTACK, { 2 }, {}))
		assert.is_true(g:AllowCommand(1, 1, 0, env.CMD.ATTACK, { 1 }, {}))
		-- A command without a description on this unit: its parameter is not a target.
		assert.is_true(g:AllowCommand(1, 1, 0, 34000, { 2 }, {}))
		assert.is_false(g:AllowCommand(1, 1, 0, 34000, { 800, 0, 64 }, {}))
		-- Nothing was cached: once a unit has the description, its type decides.
		state.cmdTypes[34000] = env.CMDTYPE.ICON_UNIT
		assert.is_false(g:AllowCommand(1, 1, 0, 34000, { 2 }, {}))
		state.cmdTypes[34001] = env.CMDTYPE.NUMBER
		assert.is_true(g:AllowCommand(1, 1, 0, 34001, { 2 }, {}))
		local calls = state.cmdDescCalls
		state.cmdTypes[34000], state.cmdTypes[34001] = nil, nil
		assert.is_false(g:AllowCommand(1, 1, 0, 34000, { 2 }, {}))
		assert.is_true(g:AllowCommand(1, 1, 0, 34001, { 2 }, {}))
		assert.equal(calls, state.cmdDescCalls)
	end)
end)
