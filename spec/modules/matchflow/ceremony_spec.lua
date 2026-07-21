local Ceremony = VFS.Include("modules/matchflow/lib/ceremony.lua")

local CMD_STOP = 99

local function newStage(opts)
	opts = opts or {}
	local stage = {
		losGrants = {},
		gameOverCalls = {},
		orders = {},
		cobCalls = {},
		units = opts.units or {},           -- unitID -> {defID, allyTeam, cobAnim}
		maxDeathFrame = opts.maxDeathFrame, -- nil -> legacy 250 default
	}

	local function unitList()
		local list = {}
		for unitID in pairs(stage.units) do
			list[#list + 1] = unitID
		end
		table.sort(list)
		return list
	end

	stage.ceremony = Ceremony.New({
		spring = {
			SetGlobalLos = function(allyTeamID, value)
				stage.losGrants[#stage.losGrants + 1] = allyTeamID
			end,
			GameOver = function(winners)
				stage.gameOverCalls[#stage.gameOverCalls + 1] = winners
			end,
			GetAllUnits = unitList,
			GetUnitDefID = function(unitID)
				return stage.units[unitID].defID
			end,
			GetUnitAllyTeam = function(unitID)
				return stage.units[unitID].allyTeam
			end,
			GiveOrderToUnit = function(unitID, cmd)
				stage.orders[#stage.orders + 1] = { unitID = unitID, cmd = cmd }
			end,
			ValidUnitID = function()
				return true
			end,
			GetCOBScriptID = function(unitID)
				return stage.units[unitID].cobAnim and 1 or nil
			end,
			CallCOBScript = function(unitID)
				stage.cobCalls[#stage.cobCalls + 1] = unitID
			end,
			UnitScriptGetScriptEnv = function()
				return nil
			end,
			UnitScriptCallAsUnit = function() end,
		},
		isCommander = opts.isCommander or {},
		cmdStop = CMD_STOP,
		maxDeathFrame = function()
			return stage.maxDeathFrame
		end,
	})

	return stage
end

describe("matchflow ceremony", function()
	it("is not started until Begin", function()
		local stage = newStage()
		assert.is_false(stage.ceremony.IsStarted())
		stage.ceremony.Begin({ 0 }, 100)
		assert.is_true(stage.ceremony.IsStarted())
	end)

	it("grants global LOS to every winner once", function()
		local stage = newStage()
		stage.ceremony.Begin({ 0, 2 }, 100)
		stage.ceremony.GameFrame(101)
		stage.ceremony.GameFrame(102)
		assert.are.same({ 0, 2 }, stage.losGrants)
	end)

	it("calls GameOver after the legacy 250+70 frame delay", function()
		local stage = newStage()
		stage.ceremony.Begin({ 1 }, 100)
		stage.ceremony.GameFrame(100 + 250 + 70 - 1)
		assert.are.same({}, stage.gameOverCalls)
		stage.ceremony.GameFrame(100 + 250 + 70)
		assert.are.same({ { 1 } }, stage.gameOverCalls)
	end)

	it("uses GG.maxDeathFrame for the delay when set", function()
		local stage = newStage({ maxDeathFrame = 10 })
		stage.ceremony.Begin({ 1 }, 100)
		stage.ceremony.GameFrame(100 + 10 + 70)
		assert.are.same({ { 1 } }, stage.gameOverCalls)
	end)

	it("stops winner commanders at Begin and animates them at +55", function()
		local stage = newStage({
			isCommander = { [7] = true },
			units = {
				[201] = { defID = 7, allyTeam = 0, cobAnim = true },  -- winning commander
				[202] = { defID = 7, allyTeam = 1, cobAnim = true },  -- losing commander
				[203] = { defID = 1, allyTeam = 0 },                  -- winning non-commander
			},
		})
		stage.ceremony.Begin({ 0 }, 100)
		assert.are.same({ { unitID = 201, cmd = CMD_STOP } }, stage.orders)

		stage.ceremony.GameFrame(154)
		assert.are.same({}, stage.cobCalls)
		stage.ceremony.GameFrame(155)
		assert.are.same({ 201 }, stage.cobCalls)
	end)
end)
