
local Events = VFS.Include("modules/missions/lib/events.lua")
local Variables = {}

---@param filename string mission-relative path, e.g. "cm8_ashfall/variables.lua"
---@return { Variable: fun(name: string): MissionVariableChain, Finalize: fun(exports: table?): MissionVariableEntry[] }
function Variables.ForFile(filename)
	local declarations = {} ---@type MissionVariableEntry[]
	local byChain = {} ---@type table<table, MissionVariableEntry>
	local declared = {} ---@type table<string, boolean>
	local finalized = false

	local function checkOpen(step)
		assert(not finalized, filename .. ": " .. step .. " after Finalize — the file already loaded")
	end

	---@param name string
	---@return MissionVariableChain
	local Variable = function(name)
		checkOpen("Variable")
		assert(type(name) == "string" and name ~= "", filename .. ": Variable expects a name string")
		assert(not declared[name], filename .. ': Variable("' .. name .. '") declared twice')
		declared[name] = true
		local build = { name = name, kind = nil, default = nil } ---@type MissionVariableEntry
		declarations[#declarations + 1] = build

		local chain = {}
		byChain[chain] = build

		local function typed(kind, default)
			checkOpen(kind)
			assert(build.kind == nil, filename .. ': Variable("' .. name .. '") is already ' .. tostring(build.kind))
			build.kind = kind
			build.default = default
			return chain
		end
		---@param default number
		---@return MissionVariableChain
		chain.Number = function(default)
			assert(type(default) == "number", filename .. ": Number expects a number default")
			return typed("number", default)
		end
		---@param default boolean
		---@return MissionVariableChain
		chain.Boolean = function(default)
			assert(type(default) == "boolean", filename .. ": Boolean expects a boolean default")
			return typed("boolean", default)
		end
		---@param default string
		---@return MissionVariableChain
		chain.String = function(default)
			assert(type(default) == "string", filename .. ": String expects a string default")
			return typed("string", default)
		end

		local function condition(test)
			return {
				inputs = { Events.VariableChanged },
				---@param ctx MissionContext
				evaluate = function(ctx)
					return test(ctx.GetVariable(name))
				end,
			}
		end
		local function effect(apply)
			return {
				---@param ctx MissionContext
				execute = function(ctx)
					ctx.SetVariable(name, apply(ctx.GetVariable(name)))
				end,
			}
		end
		local function number(verb)
			assert(
				build.kind == "number",
				filename .. ': Variable("' .. name .. '").' .. verb .. " needs a Number variable"
			)
		end

		---@param value number|boolean|string
		---@return MissionCondition
		chain.Is = function(value)
			return condition(function(current)
				return current == value
			end)
		end
		---@param n number
		---@return MissionCondition
		chain.AtLeast = function(n)
			number("AtLeast")
			return condition(function(current)
				return (current or 0) >= n
			end)
		end
		---@param n number
		---@return MissionCondition
		chain.AtMost = function(n)
			number("AtMost")
			return condition(function(current)
				return (current or 0) <= n
			end)
		end
		---@param value number|boolean|string
		---@return MissionEffect
		chain.Set = function(value)
			assert(
				build.kind == nil or type(value) == build.kind,
				filename .. ': Variable("' .. name .. '").Set expects a ' .. tostring(build.kind)
			)
			return effect(function()
				return value
			end)
		end
		---@param n number
		---@return MissionEffect
		chain.Add = function(n)
			number("Add")
			assert(type(n) == "number", filename .. ": Add expects a number")
			return effect(function(current)
				return (current or 0) + n
			end)
		end

		return chain
	end

	---@param exports table<string, table>|nil what variables.lua returned
	---@return MissionVariableEntry[]
	local Finalize = function(exports)
		assert(not finalized, filename .. ": Finalize called twice")
		finalized = true
		for _, build in ipairs(declarations) do
			assert(
				build.kind ~= nil,
				filename .. ': Variable("' .. build.name .. '") has no type — Number, Boolean or String'
			)
		end
		assert(
			exports == nil or type(exports) == "table",
			filename .. ": a variables file returns a table of its values, or nothing"
		)
		return declarations
	end

	return { Variable = Variable, Finalize = Finalize }
end

return Variables
