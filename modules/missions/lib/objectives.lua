local Events = VFS.Include("modules/missions/lib/events.lua")

local Objectives = {}

local function prettify(id)
	return (id:gsub("_", " "))
end

---@param filename string mission-relative path, e.g. "cm8_ashfall/objectives.lua"
---@return { Objective: fun(id: string): MissionObjectiveDeclaration, Finalize: fun(exports: table?): MissionObjectiveDeclarationEntry[] }
---@param effects fun(id: string, verb: "Complete"|"Reveal"): MissionEffect|nil the loader's effect side, so an exported handle can be Done
function Objectives.ForFile(filename, effects)
	local declarations = {} ---@type MissionObjectiveDeclarationEntry[]
	local idByChain = {} ---@type table<table, string>
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

		-- Registration is lazy: Objective("x") inside a condition argument is a
		-- reference, not a declaration; the first DECLARING verb stamps the entry.
		local function declare(step)
			checkOpen(step)
			if build ~= nil then
				return
			end
			assert(not declared[id], filename .. ': Objective("' .. id .. '") declared twice')
			declared[id] = true
			build = { id = id, title = prettify(id), completions = {}, gates = {}, foreshadow = false }
			declarations[#declarations + 1] = build
		end

		local function checkCondition(step, condition)
			assert(
				type(condition) == "table" and type(condition.evaluate) == "function",
				filename .. ": " .. step .. " expects a condition (a table with an evaluate function)"
			)
		end

		local chain = { id = id }
		idByChain[chain] = id

		---@param title string
		---@return MissionObjectiveDeclaration
		chain.Title = function(title)
			declare("Title")
			assert(type(title) == "string", filename .. ": Title expects a string")
			build.title = title
			return chain
		end

		---@param condition MissionCondition
		---@return MissionObjectiveDeclaration
		chain.CompletedWhen = function(condition)
			declare("CompletedWhen")
			checkCondition("CompletedWhen", condition)
			build.completions[#build.completions + 1] = { condition }
			return chain
		end

		---@param condition MissionCondition
		---@return MissionObjectiveDeclaration
		chain.When = function(condition)
			declare("When")
			checkCondition("When", condition)
			build.gates[#build.gates + 1] = condition
			return chain
		end

		---@param condition MissionCondition
		---@return MissionObjectiveDeclaration
		chain.RevealedWhen = function(condition)
			declare("RevealedWhen")
			checkCondition("RevealedWhen", condition)
			build.revealedWhen = condition
			return chain
		end

		---@return MissionObjectiveDeclaration
		chain.Foreshadow = function()
			declare("Foreshadow")
			build.foreshadow = true
			return chain
		end

		---@return MissionCondition
		---@return MissionEffect
		chain.Complete = function()
			assert(effects, filename .. ": Complete is the loader's to build")
			return effects(id, "Complete")
		end

		---@return MissionEffect
		chain.Reveal = function()
			assert(effects, filename .. ": Reveal is the loader's to build")
			return effects(id, "Reveal")
		end

		chain.IsComplete = function()
			referenced[id] = true
			return {
				inputs = { Events.ObjectiveChanged },
				---@param ctx MissionContext
				evaluate = function(ctx)
					return ctx.IsObjectiveComplete(id)
				end,
			}
		end

		return chain
	end

	---@return MissionObjectiveDeclarationEntry[]
	---@param exports table<string, table>|nil what objectives.lua returned: key -> handle
	---@return MissionObjectiveDeclarationEntry[] declarations
	local Finalize = function(exports)
		assert(not finalized, filename .. ": Finalize called twice")
		finalized = true
		assert(
			exports == nil or type(exports) == "table",
			filename .. ": an objectives file returns a table of its values, or nothing"
		)
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
