--- Combat's contribution to the mission sandbox. The loader composes the
--- authoring environment from the missions manifest's requires list; each
--- contributing module ships a mission_dsl.lua returning a per-file factory.

local CombatVerbs = VFS.Include("modules/combat/lib/mission_verbs.lua")

return {
	---@param file MissionDslFile
	ForFile = function(file)
		local untils = {} ---@type { unit: MissionUnitRef, condition: MissionCondition }[]
		local combat = CombatVerbs.MakeCombat(untils)
		return {
			env = { Combat = combat },
			-- The Until sugar, desugared: each recorded companion is the
			-- literal statement When(condition).Do(Combat.Unprotect(unit)).
			Finalize = function()
				for order, entry in ipairs(untils) do
					file.Register({
						id = file.filename .. ":until:" .. order,
						filename = file.filename,
						order = order,
						condition = entry.condition,
						effects = { combat.Unprotect(entry.unit) },
						once = true,
					})
				end
			end,
		}
	end,
}
