---@diagnostic disable: undefined-field, redundant-parameter
local SpecEnv = VFS.Include("spec/support/spec_env.lua")

describe("ground attack order rings", function()
	it("accepts mouse clicks with zero radius and excludes area and unit attacks", function()
		-- Load the production collector without requiring an OpenGL context.
		local source = assert(VFS.LoadFile("luaui/Widgets/gui_attack_aoe.lua"))
		---@cast source string
		local first = assert(source:find("local function GetOrderWeaponInfo", 1, true))
		---@cast first integer
		local last = assert(source:find("local function UnitSetTargetListChanged", first, true))
		---@cast last integer
		local chunk = assert(loadstring(source:sub(first, last - 1) .. "\nreturn CollectOrderTargets"))
		local queue = {
			{ 20, 0, 1, 1200, 678, 3107, 0 },
			{ 20, 0, 2, 1400, 678, 3107 },
			{ 20, 0, 3, 1600, 678, 3107, 100 },
			{ 20, 0, 4, 999 },
		}
		local env = SpecEnv.new({
			floor = math.floor,
			min = math.min,
			CMD_ATTACK = 20,
			Config = { Order = { queueDepth = 12, maxIndicators = 24, minAoe = 8 }, Colors = { aoe = { 1, 0, 0 } } },
			State = { setTargetPositions = {}, setTargetActiveIndices = {} },
			spGetGroundHeight = function()
				return 678
			end,
			spGetUnitCommandCount = function()
				return #queue
			end,
			spGetUnitCurrentCommand = function(_, index)
				return unpack(queue[index])
			end,
		})
		setfenv(chunk, env)
		local collect = chunk()
		---@cast collect function
		local targets = {}
		local weapon = { primary = { type = "ballistic", aoe = 32, ee = 0.15 } }
		collect(targets, {}, { { unitID = 1, weaponInfos = weapon }, { unitID = 2, weaponInfos = weapon } }, 20)
		assert.equals(2, #targets)
		assert.same({ 1200, 678, 3107, true }, { targets[1].x, targets[1].y, targets[1].z, targets[1].active })
		assert.same({ 1400, false }, { targets[2].x, targets[2].active })
	end)
end)
