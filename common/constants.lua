-- constants.lua ---------------------------------------------------------------
-- General game and engine constants, for use in general Lua environments.

if not Engine or not Spring then return end

--------------------------------------------------------------------------------
-- Extended LuaConst -----------------------------------------------------------

if CMD then
	CMD.NIL   = "n" -- Handling for unintended nil's.
	CMD.ANY   = "a" -- Matches on all command values.
	CMD.BUILD = "b" -- Filters for negative commands.

	CMD.n     = "NIL"
	CMD.a     = "ANY"
	CMD.b     = "BUILD"
end
