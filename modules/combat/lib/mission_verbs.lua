--- Combat's mission-sandbox verbs, pure half. Effects act through the ctx
--- the engine is handed (ctx.Protect resolves the roster name where Spring
--- exists), so this specs under busted.

local CombatVerbs = {}

---Build one trigger file's Combat verbs. Protect is a plain effect; its
---.Until(condition) sugar bounds the protection's LIFETIME — the releasing
---trigger is registered when the protection is applied, never at load, so a
---condition that already held cannot retire the release before it exists.
---@param file MissionDslFile
---@return CombatActions
function CombatVerbs.MakeCombat(file)
	---@param unitRef MissionUnitRef
	---@param verb string
	local function checkUnitRef(unitRef, verb)
		assert(type(unitRef) == "table" and type(unitRef.name) == "string",
			verb .. " expects a Unit(...) reference")
	end

	local combat = {}
	local releases = 0

	---One lifetime, armed by the protection it bounds: the desugared
	---statement When(condition).Do(Combat.Unprotect(unit)). It POLLS — the
	---loader fixes its callin hook set at load, so a trigger arming mid-game
	---cannot be reached by event inputs.
	---@param unitRef MissionUnitRef
	---@param condition MissionCondition
	local function armRelease(unitRef, condition)
		releases = releases + 1
		file.Register({
			id = file.filename .. ":until:" .. releases,
			filename = file.filename,
			order = releases,
			condition = { evaluate = condition.evaluate },
			effects = { combat.Unprotect(unitRef) },
			once = true,
		})
	end

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
				return {
					---@param ctx MissionContext
					execute = function(ctx)
						execute(ctx)
						armRelease(unitRef, condition)
					end,
				}
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
