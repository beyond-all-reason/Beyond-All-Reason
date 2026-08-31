local CombatVerbs = VFS.Include("modules/combat/lib/mission_verbs.lua")
local ModuleHandler = VFS.Include("modules/module_handler.lua")

return {
	---@param file MissionDslFile
	ForFile = function(file)
		return { env = { Combat = CombatVerbs.MakeCombat(file) } }
	end,
	---@param runtime MissionRuntime
	Context = function(runtime)
		return {
			Protect = function(name)
				local unitID = runtime.UnitOf(name)
				if unitID == nil or not Spring.ValidUnitID(unitID) then
					runtime.Log(LOG.WARNING, "Combat.Protect: no living roster unit named " .. name)
					return
				end
				ModuleHandler.Get("combat").Protect(unitID)
				runtime.Protections.Set(unitID, runtime.Protections.Get(unitID) + 1)
			end,
			Unprotect = function(name)
				local unitID = runtime.UnitOf(name)
				if unitID ~= nil and Spring.ValidUnitID(unitID) then
					-- Only release what this mission holds: an unmatched Unprotect
					-- would eat someone else's guard.
					local held = runtime.Protections.Get(unitID)
					if held > 0 then
						ModuleHandler.Get("combat").Unprotect(unitID)
						runtime.Protections.Set(unitID, held - 1)
					end
				end
			end,
		}
	end,
}
