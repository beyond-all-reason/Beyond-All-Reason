--- Mission objectives DSL: objectives.lua's authoring surface — the
--- definition site for every Objective(...) name the mission speaks, the way
--- units.lua is for Unit(...). Pure Lua, no Spring, so it specs under busted.
---
--- One declaration per objective:
---
---     Objective("find_the_enclave")
---         .Title("Find the Enclave")
---         .CompletedWhen(Unit("enclave_beacon").IsSpotted(Team.Player))
---         .When(Objective("relieve_the_outpost").IsComplete())
---
--- A SECOND CompletedWhen is another way to complete, not another
--- requirement: disjuncts OR, and each .When ANDs onto the latest one —
--- the same shape as triggers, where OR is two statements.
---
--- Declaration order is the tracker's display order AND the default reveal
--- cadence: the first line is revealed at arm, each next when its
--- predecessor completes. The sequence gates REVEAL ONLY — presentation.
--- Completion gating is game logic and stays explicit (the .When above).
--- Per-line overrides: .RevealedWhen(condition) replaces the cadence,
--- .Foreshadow() draws the line greyed-out before its reveal.
---
--- The same Objective verb is also the reference side: .IsComplete() builds
--- the condition, and Finalize errors on a referenced id no declaration
--- backs — a typo is a load error here, exactly the roster's contract.

local Objectives = {}

local function prettify(id)
	return (id:gsub("_", " "))
end

---Build one objectives file's authoring surface: the Objective entry the
---loader injects, and the Finalize the loader calls after the include.
---@param filename string mission-relative path, e.g. "cm8_ashfall/objectives.lua"
---@return { Objective: fun(id: string): MissionObjectiveDeclaration, Finalize: fun(): MissionObjectiveDeclarationEntry[] }
function Objectives.ForFile(filename)
	local declarations = {} ---@type MissionObjectiveDeclarationEntry[]
	local declared = {} ---@type table<string, boolean>
	local referenced = {} ---@type table<string, boolean>
	local finalized = false

	local function checkOpen(step)
		assert(not finalized, filename .. ": " .. step .. " after Finalize — the file already loaded")
	end

	---@param id string
	---@return MissionObjectiveDeclaration
	local Objective = function(id)
		checkOpen("Objective")
		assert(type(id) == "string" and id ~= "", filename .. ": Objective expects an id string")

		local build = nil ---@type MissionObjectiveDeclarationEntry|nil

		-- Registration is lazy: Objective("x") inside a condition argument is
		-- a reference, not a declaration. The first DECLARING verb stamps the
		-- entry, and its call order is the display order.
		local function declare(step)
			checkOpen(step)
			if build ~= nil then
				return
			end
			assert(not declared[id], filename .. ': Objective("' .. id .. '") declared twice')
			declared[id] = true
			build = { id = id, title = prettify(id), completions = {}, foreshadow = false }
			declarations[#declarations + 1] = build
		end

		local function checkCondition(step, condition)
			assert(
				type(condition) == "table" and type(condition.evaluate) == "function",
				filename .. ": " .. step .. " expects a condition (a table with an evaluate function)"
			)
		end

		local chain = {}

		---@param title string
		---@return MissionObjectiveDeclaration
		chain.Title = function(title)
			declare("Title")
			assert(type(title) == "string", filename .. ": Title expects a string")
			build.title = title
			return chain
		end

		---One way to complete. Each CompletedWhen opens a new disjunct (OR);
		---.When ANDs onto the latest.
		---@param condition MissionCondition
		---@return MissionObjectiveDeclaration
		chain.CompletedWhen = function(condition)
			declare("CompletedWhen")
			checkCondition("CompletedWhen", condition)
			build.completions[#build.completions + 1] = { condition }
			return chain
		end

		---Another condition on the LATEST CompletedWhen; all in a disjunct
		---must hold (AND) — the same composition a trigger's .When performs.
		---@param condition MissionCondition
		---@return MissionObjectiveDeclaration
		chain.When = function(condition)
			checkOpen("When")
			assert(
				build ~= nil and #build.completions > 0,
				filename
					.. ': Objective("'
					.. id
					.. '").When before CompletedWhen — When ANDs onto a completion condition'
			)
			checkCondition("When", condition)
			local group = build.completions[#build.completions]
			group[#group + 1] = condition
			return chain
		end

		---Replace the default reveal cadence (predecessor completes) with the
		---mission's own moment.
		---@param condition MissionCondition
		---@return MissionObjectiveDeclaration
		chain.RevealedWhen = function(condition)
			declare("RevealedWhen")
			checkCondition("RevealedWhen", condition)
			build.revealedWhen = condition
			return chain
		end

		---Draw the line greyed-out before its reveal — the mission telling
		---the player what is coming.
		---@return MissionObjectiveDeclaration
		chain.Foreshadow = function()
			declare("Foreshadow")
			build.foreshadow = true
			return chain
		end

		---The reference side, usable in any condition slot here. The id is
		---validated against the declarations at Finalize.
		---@return MissionCondition
		chain.IsComplete = function()
			referenced[id] = true
			return {
				inputs = { "mission.objective_changed" },
				---@param ctx MissionContext
				evaluate = function(ctx)
					return ctx.IsObjectiveComplete(id)
				end,
			}
		end

		return chain
	end

	---The commit point: called by the loader when the file's include
	---returns. Validates references before anything arms — a typo'd id is a
	---load error naming this file, not a silent never-true condition.
	---@return MissionObjectiveDeclarationEntry[]
	local Finalize = function()
		assert(not finalized, filename .. ": Finalize called twice")
		finalized = true
		for id in pairs(referenced) do
			if not declared[id] then
				error(
					filename .. ': Objective("' .. id .. '").IsComplete() references an objective no declaration backs'
				)
			end
		end
		return declarations
	end

	return { Objective = Objective, Finalize = Finalize }
end

return Objectives
