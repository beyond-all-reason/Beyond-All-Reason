--- Combat's mission-sandbox verbs, pure half. Effects act through the ctx
--- the engine is handed (ctx.Protect resolves the roster name where Spring
--- exists), so this specs under busted.

local CombatVerbs = {}

---Build one trigger file's Combat verbs. Protect is a plain effect; its
---.Until(condition) sugar bounds the protection's lifetime by recording a
---companion into `untils` — registered after Finalize as the literal
---desugared statement When(condition).Do(Combat.Unprotect(unit)).
---@param untils { unit: MissionUnitRef, condition: MissionCondition }[] file-scoped, drained after Finalize
---@return MissionCombat
function CombatVerbs.MakeCombat(untils)
	---@param unitRef MissionUnitRef
	---@param verb string
	local function checkUnitRef(unitRef, verb)
		assert(type(unitRef) == "table" and type(unitRef.name) == "string",
			verb .. " expects a Unit(...) reference")
	end

	local combat = {}

	---@param unitRef MissionUnitRef
	---@return MissionProtectEffect
	combat.Protect = function(unitRef)
		checkUnitRef(unitRef, "Combat.Protect")
		---@param ctx MissionContext
		local execute = function(ctx)
			ctx.Protect(unitRef.name)
		end
		return {
			execute = execute,
			---@param condition MissionCondition
			---@return MissionEffect
			Until = function(condition)
				assert(type(condition) == "table" and type(condition.evaluate) == "function",
					"Combat.Protect(...).Until expects a condition")
				untils[#untils + 1] = { unit = unitRef, condition = condition }
				return { execute = execute }
			end,
		}
	end

	---@param unitRef MissionUnitRef
	---@return MissionEffect
	combat.Unprotect = function(unitRef)
		checkUnitRef(unitRef, "Combat.Unprotect")
		return {
			---@param ctx MissionContext
			execute = function(ctx)
				ctx.Unprotect(unitRef.name)
			end,
		}
	end

	return combat
end

return CombatVerbs
