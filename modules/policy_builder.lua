--- Dot-only closure chain, no metatables: synced-sandbox-safe.

local PolicyBuilder = {}

---@class PolicyStages<C, T>: { [string]: string } stage names for one pipeline; C is the context its evaluates receive, T the result it produces

---@class PolicyFacts<C>: { [string]: string } the facts a decision reads, named; C is the context providers receive

---@class AssembledPipeline<C, T>: { [integer]: PolicyDescriptor } one pipeline as LoadPolicies hands it back, contributions applied
---@field result "single"|"product"
---@field refusal (fun(ctx: C, ...: any): T)|nil declared by the owner's Refusal; false is the refusal when absent

---@class PolicyIdentity
---@field owner string the module whose pipeline or context this is
---@field category string its name within the module
---@field result "single"|"product"|nil how a pipeline's results combine
---@field facts boolean|nil true for facts: provided, not evaluated

---@generic T: table
---@param stages T enum of stage names
---@return T
function PolicyBuilder.Single(stages)
	assert(type(stages) == "table" and getmetatable(stages) == nil, "PolicyBuilder.Single(stages)")
	return setmetatable(stages, { __result = "single" })
end

---@generic T: table
---@param stages T enum of stage names
---@return T
function PolicyBuilder.Product(stages)
	assert(type(stages) == "table" and getmetatable(stages) == nil, "PolicyBuilder.Product(stages)")
	return setmetatable(stages, { __result = "product" })
end

---A fold pipeline hands one context through every Answer in turn; each may
---change it, none may end it. Evaluate returns the context it was given.
---@generic C
---@param stages PolicyStages<C, C>
---@return PolicyStages<C, C>
function PolicyBuilder.Fold(stages)
	assert(type(stages) == "table" and getmetatable(stages) == nil, "PolicyBuilder.Fold(stages)")
	return setmetatable(stages, { __result = "fold" })
end

---@generic T: table
---@param provisions T enum of the field names enrichers may provide
---@return T
---The stages a module adds to another module's pipeline, named here so a
---third party can place a rule against them by reference. The runtime
---refuses to assemble the target if a declared name never lands.
---@generic C, T
---@param target PolicyStages<C, T> the target pipeline's stages, from its owner's contract.lua
---@param names table<string, string>
---@return table<string, string>
function PolicyBuilder.Contributes(target, names)
	local identity = PolicyBuilder.IdentityOf(target)
	assert(
		identity ~= nil and not identity.facts,
		"PolicyBuilder.Contributes(target, names): target must be a pipeline's stages"
	)
	assert(type(names) == "table" and getmetatable(names) == nil, "PolicyBuilder.Contributes(target, names)")
	return setmetatable(names, { __contributes = identity })
end

---The facts a decision reads, declared by the module that reads them. Each is
---a promise: the owner Defaults it, any module may Provide it, the mode says
---whose answer is live. A fact informs a decision; it is not the decision.
---@generic T: table
---@param facts T enum of fact names
---@return T
function PolicyBuilder.Facts(facts)
	assert(type(facts) == "table" and getmetatable(facts) == nil, "PolicyBuilder.Facts(facts)")
	return setmetatable(facts, { __facts = true })
end

---The key a declaration's name serializes to: `UnitTermsNotes` is
---`unit_terms_notes` to the loader, the runtime tables and every error.
---@param member string
---@return string
function PolicyBuilder.KeyOf(member)
	return (member
		:gsub("(%u)", function(c)
			return "_" .. c:lower()
		end)
		:sub(2))
end

---@generic T: table
---@param owner string the module's name
---@param categories T PascalCase name -> a pipeline's stage enum (Single, Product or Fold) or Facts
---@return T
function PolicyBuilder.Contract(owner, categories, policies)
	assert(
		type(owner) == "string" and type(categories) == "table",
		"PolicyBuilder.Contract(owner, { <category> = <enum> })"
	)
	assert(
		policies == nil or type(policies) == "function",
		"PolicyBuilder.Contract(owner, categories, policies?): the inline policy is a function(Policies)"
	)
	for member, stages in pairs(categories) do
		local meta = type(stages) == "table" and getmetatable(stages) or nil
		assert(
			meta ~= nil and (meta.__result ~= nil or meta.__facts or meta.__contributes),
			"PolicyBuilder.Contract: "
				.. tostring(member)
				.. " must declare itself: Single(...), Product(...), Fold(...), Contributes(...) or Facts(...)"
		)
		local category = PolicyBuilder.KeyOf(member)
		if meta.__contributes then
			meta.__policy = { owner = owner, category = category, contributes = meta.__contributes }
		elseif meta.__facts then
			meta.__policy = { owner = owner, category = category, facts = true }
		else
			meta.__policy = { owner = owner, category = category, result = meta.__result }
		end
	end
	return setmetatable(categories, { __owner = owner, __policies = policies })
end

---A contract's inline policy, if it carries one: a function(Policies) the
---loader runs with the registrar when it loads policies, exactly as it runs a
---file under policies/. Including the contract never runs it, so the contract
---stays inert for everyone who only wants its names.
---@param contract table
---@return (fun(Policies: table))|nil
function PolicyBuilder.InlinePolicies(contract)
	local meta = type(contract) == "table" and getmetatable(contract) or nil
	return meta and meta.__policies or nil
end

---The module a contract belongs to, or nil for a table that is not one.
---A module is named by its contract wherever another file refers to it.
---@param contract table
---@return string|nil
function PolicyBuilder.OwnerOf(contract)
	local meta = type(contract) == "table" and getmetatable(contract) or nil
	return meta and meta.__owner or nil
end

---@param stages table
---@return PolicyIdentity|nil
function PolicyBuilder.IdentityOf(stages)
	local meta = type(stages) == "table" and getmetatable(stages) or nil
	return meta and meta.__policy or nil
end

---@class PolicyOp
---@field op "add"|"replace"|"remove"|"refusal"
---@field kind "if"|"unless"|"answer"|nil add only
---@field name string
---@field evaluate function|nil
---@field after string|nil
---@field before string|nil

---@class PolicyPipeline<C, T>
---@field stages table|nil the identity this chain builds against
---@field Unless fun(name: string, predicate: fun(ctx: C, ...: any): boolean|nil): PolicyPipeline<C, T> truthy means the named condition holds and the pipeline refuses
---@field If fun(name: string, predicate: fun(ctx: C, ...: any): boolean|nil): PolicyPipeline<C, T> falsy means the named condition fails to hold and the pipeline refuses
---@field Refusal fun(evaluate: fun(ctx: C, ...: any): T): PolicyPipeline<C, T> how this pipeline shapes a refusal; false when never declared
---@field Answer fun(name: string, evaluate: fun(ctx: C, ...: any): T|nil): PolicyPipeline<C, T> a stage that may produce the answer; the last stage must be one
---@field After fun(name: string): PolicyPipeline<C, T> place the stage just added after the named stage
---@field Before fun(name: string): PolicyPipeline<C, T> place the stage just added before the named stage
---@field Replace fun(name: string, evaluate: fun(ctx: C, ...: any): T|nil): PolicyPipeline<C, T> the named stage, with this evaluate
---@field Remove fun(name: string): PolicyPipeline<C, T>
---@field Build fun(): PolicyOp[]

---One chain for owners and contributors alike: a list of ops against a
---pipeline's identity. Whose ops apply first is the assembler's business.
---@generic C, T
---@param stages PolicyStages<C, T>|nil the pipeline's stages, from the owner's contract.lua
---@return PolicyPipeline<C, T>
function PolicyBuilder.Pipeline(stages)
	local ops = {} ---@type PolicyOp[]
	local chain = { stages = stages }

	---@param verb string
	---@param kind "if"|"unless"|"answer"
	---@param name string
	---@param evaluate function
	local function add(verb, kind, name, evaluate)
		assert(
			type(name) == "string" and type(evaluate) == "function",
			"PolicyPipeline: " .. verb .. "(name, evaluate)"
		)
		ops[#ops + 1] = { op = "add", kind = kind, name = name, evaluate = evaluate }
	end

	---@param modifier string
	---@return PolicyOp
	local function lastAdded(modifier)
		local last = ops[#ops]
		assert(
			last ~= nil and last.op == "add",
			"PolicyPipeline: ." .. modifier .. " must follow an If, Unless or Answer"
		)
		assert(last.after == nil and last.before == nil, "PolicyPipeline: a stage is placed once")
		return last
	end

	chain.Unless = function(name, evaluate)
		add("Unless", "unless", name, evaluate)
		return chain
	end
	chain.If = function(name, evaluate)
		add("If", "if", name, evaluate)
		return chain
	end
	chain.Answer = function(name, evaluate)
		add("Answer", "answer", name, evaluate)
		return chain
	end
	chain.After = function(name)
		lastAdded("After").after = name
		return chain
	end
	chain.Before = function(name)
		lastAdded("Before").before = name
		return chain
	end
	chain.Replace = function(name, evaluate)
		assert(type(name) == "string" and type(evaluate) == "function", "PolicyPipeline: Replace(name, evaluate)")
		ops[#ops + 1] = { op = "replace", name = name, evaluate = evaluate }
		return chain
	end
	chain.Remove = function(name)
		assert(type(name) == "string", "PolicyPipeline: Remove(name)")
		ops[#ops + 1] = { op = "remove", name = name }
		return chain
	end
	chain.Refusal = function(evaluate)
		assert(type(evaluate) == "function", "PolicyPipeline: Refusal(evaluate)")
		ops[#ops + 1] = { op = "refusal", evaluate = evaluate }
		return chain
	end
	chain.Build = function()
		return ops
	end
	return chain
end

---@param stages PolicyDescriptor[] the pipeline under assembly, mutated in place
---@param ops PolicyOp[]
---@param origin string for error messages: the file the ops came from
function PolicyBuilder.Apply(stages, ops, origin)
	local function indexOf(name)
		for i, stage in ipairs(stages) do
			if stage.name == name then
				return i
			end
		end
		return nil
	end
	for _, op in ipairs(ops) do
		if op.op == "add" then
			assert(indexOf(op.name) == nil, origin .. ": the pipeline already has a stage named " .. op.name)
			-- Unplaced stages go to the end, but a guard never lands past a
			-- terminal Answer: it slots in just before it.
			local at = #stages + 1
			if op.kind ~= "answer" and #stages > 0 and stages[#stages].kind == "answer" then
				at = #stages
			end
			if op.after ~= nil then
				at = assert(indexOf(op.after), origin .. ": no stage named " .. op.after .. " to go after") + 1
			elseif op.before ~= nil then
				at = assert(indexOf(op.before), origin .. ": no stage named " .. op.before .. " to go before")
			end
			table.insert(stages, at, { name = op.name, kind = op.kind, evaluate = op.evaluate })
		elseif op.op == "replace" then
			local at = assert(indexOf(op.name), origin .. ": no stage named " .. op.name .. " to replace")
			stages[at] = { name = op.name, kind = stages[at].kind, evaluate = op.evaluate }
		elseif op.op == "remove" then
			table.remove(stages, assert(indexOf(op.name), origin .. ": no stage named " .. op.name .. " to remove"))
		elseif op.op == "refusal" then
			assert(stages.refusal == nil, origin .. ": the pipeline already has a Refusal")
			stages.refusal = op.evaluate
		end
	end
end

---What an assembled pipeline must look like, by its declared result.
---@param stages PolicyDescriptor[]
---@param result "single"|"product"
---@param label string owner.category, for error messages
function PolicyBuilder.Validate(stages, result, label)
	if result == "product" then
		for _, stage in ipairs(stages) do
			assert(
				stage.kind == "answer",
				label .. ": a product pipeline multiplies Answer results; " .. stage.name .. " is a guard"
			)
		end
		return
	end
	if result == "fold" then
		for _, stage in ipairs(stages) do
			assert(
				stage.kind == "answer",
				label .. ": a fold pipeline runs every Answer over the context; " .. stage.name .. " is a guard"
			)
		end
		return
	end
	assert(#stages > 0, label .. ": an empty pipeline")
	local last = stages[#stages]
	assert(
		last.kind == "answer",
		label .. ": a single-result pipeline ends with a Answer; " .. last.name .. " is a guard"
	)
end

---@class PolicyProvision
---@field names string[]
---@field evaluate function one producer; each returned value assigns its name, in order
---@field default boolean|nil the owner's answer for a slot nobody provides

---@class PolicyEnrichment<C>
---@field facts table|nil the facts this enrichment provides for
---@field Provide fun(...: string|fun(ctx: C, ...: any): any): PolicyEnrichment<C> one or more provision names, then the producer
---@field Default fun(name: string, evaluate: fun(ctx: C, ...: any): any): PolicyEnrichment<C> the owner's value for a fact when no module provides it
---@field Build fun(): PolicyProvision[]

---@param facts table|nil the facts, from the owner's contract.lua
---@return PolicyEnrichment
function PolicyBuilder.Enrichment(facts)
	local ops = {} ---@type PolicyProvision[]
	local chain = { facts = facts }
	chain.Provide = function(...)
		local n = select("#", ...)
		local evaluate = n >= 2 and select(n, ...) or nil
		assert(type(evaluate) == "function", "PolicyEnrichment: Provide(name, ..., evaluate)")
		local names = {}
		for i = 1, n - 1 do
			local name = select(i, ...)
			assert(type(name) == "string", "PolicyEnrichment: Provide(name, ..., evaluate)")
			names[i] = name
		end
		ops[#ops + 1] = { names = names, evaluate = evaluate }
		return chain
	end
	---@param name string a fact the contract declares
	---@param evaluate function
	chain.Default = function(name, evaluate)
		assert(type(name) == "string" and type(evaluate) == "function", "PolicyEnrichment: Default(name, evaluate)")
		ops[#ops + 1] = { names = { name }, evaluate = evaluate, default = true }
		return chain
	end
	chain.Build = function()
		return ops
	end
	return chain
end

return PolicyBuilder
