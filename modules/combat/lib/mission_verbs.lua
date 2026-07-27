
local CombatVerbs = {}

---Protect(...).Until registers the releasing trigger when the protection is applied, never at load,
---so a condition that already held cannot retire the release before it exists.
---@param file MissionDslFile
---@return CombatActions
function CombatVerbs.MakeCombat(file)
	---@param unitRef MissionUnitRef
	---@param verb string
	local function checkUnitRef(unitRef, verb)
		assert(type(unitRef) == "table" and type(unitRef.name) == "string", verb .. " expects a Unit(...) reference")
	end

	local combat = {}
	local releases = 0

	---The release trigger POLLS — the
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
			-- The condition itself, inputs included: a release that polls never gets
			-- its callin hooked, so the latch it reads is never written.
			condition = condition,
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
				assert(
					type(condition) == "table" and type(condition.evaluate) == "function",
					"Combat.Protect(...).Until expects a condition"
				)
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
