--- Game-over ceremony, extracted behavior-for-behavior from game_end.lua's
--- GameFrame: the global-LOS reveal for winners, the delayed Spring.GameOver
--- (letting everything blow up gradually first), and the commander dance
--- animation. Effects only — the decision that produced `winners` is the
--- policy pipeline's job.
---
--- Quirks preserved on purpose: in shared-dynamic-alliance mode the legacy
--- code hands a winner COUNT (a number) around instead of a table; every
--- type(winners) == 'table' guard below is that inheritance.

local Ceremony = {}

---@class CeremonySpringDeps
---@field SetGlobalLos fun(allyTeamID: integer, value: boolean)
---@field GameOver fun(winners: table|number)
---@field GetAllUnits fun(): integer[]
---@field GetUnitDefID fun(unitID: integer): integer?
---@field GetUnitAllyTeam fun(unitID: integer): integer?
---@field GiveOrderToUnit fun(unitID: integer, cmd: integer, params: number|table, opts: number|table)
---@field ValidUnitID fun(unitID: integer): boolean
---@field GetCOBScriptID fun(unitID: integer, name: string): integer?
---@field CallCOBScript fun(unitID: integer, script: integer|string, retvals: integer, ...)
---@field UnitScriptGetScriptEnv fun(unitID: integer): table?
---@field UnitScriptCallAsUnit fun(unitID: integer, fn: function, ...)

---@class CeremonyDeps
---@field spring CeremonySpringDeps
---@field isCommander table<integer, boolean> unitDefID -> is commander
---@field cmdStop integer CMD.STOP
---@field maxDeathFrame fun(): integer|nil GG.maxDeathFrame at Begin time

---@class MatchCeremony
---@field Begin fun(winners: table|number, gf: integer) schedule the gameover sequence
---@field GameFrame fun(gf: integer)
---@field IsStarted fun(): boolean

---@param deps CeremonyDeps
---@return MatchCeremony
function Ceremony.New(deps)
	local spring = deps.spring

	local gameoverFrame
	local gameoverWinners
	local gameoverAnimFrame
	local gameoverAnimUnits
	local globalLosGranted = false

	local ceremony = {}

	ceremony.Begin = function(winners, gf)
		-- delay gameover to let everything blow up gradually first
		local delay = deps.maxDeathFrame() or 250
		gameoverFrame = gf + delay + 70
		gameoverWinners = winners

		-- make all winner commanders dance!
		gameoverAnimFrame = gf + 55		-- delay a bit because walking commanders need to stop walking + a delay look nice
		gameoverAnimUnits = {}
		if type(winners) == 'table' then
			local winnerSet = {}
			for u = 1, #winners do
				winnerSet[winners[u]] = true
			end
			local units = spring.GetAllUnits()
			for i = 1, #units do
				local unitID = units[i]
				if deps.isCommander[spring.GetUnitDefID(unitID)] and winnerSet[spring.GetUnitAllyTeam(unitID)] then
					spring.GiveOrderToUnit(unitID, deps.cmdStop, 0, 0)	-- give stop cmd so commanders can animate in place
					gameoverAnimUnits[unitID] = true
				end
			end
		end
	end

	ceremony.GameFrame = function(gf)
		if not globalLosGranted then
			for _, allyTeamId in ipairs(gameoverWinners) do
				spring.SetGlobalLos(allyTeamId, true)
			end

			globalLosGranted = true
		end

		if gf == gameoverFrame then
			spring.GameOver(gameoverWinners)
		end

		if gf == gameoverAnimFrame then
			for unitID, _ in pairs(gameoverAnimUnits) do
				if spring.ValidUnitID(unitID) then
					if spring.GetCOBScriptID(unitID, 'GameOverAnim') then
						spring.CallCOBScript(unitID, 'GameOverAnim', 0, true)
					else
						local scriptEnv = spring.UnitScriptGetScriptEnv(unitID)
						if scriptEnv and scriptEnv['GameOverAnim'] then
							spring.UnitScriptCallAsUnit(unitID, scriptEnv['GameOverAnim'], true)
						end
					end
				end
			end
		end
	end

	ceremony.IsStarted = function()
		return gameoverFrame ~= nil
	end

	return ceremony
end

return Ceremony
