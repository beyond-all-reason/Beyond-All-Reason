local Policy = {}

---@class PolicyContext a context that carries the match's modoptions: every Facts context, since the live set is read off them, and a policy's when its steps read them
---@field springRepo SpringBoth the engine, or a spec's stand-in: every provider reads the match through its context
---@field modOptions table<string, string|number|boolean>

---@class PolicySteps<C, T>: { [string]: string } step names for one policy; C is the context its evaluates receive, T the result it produces

---@class PolicyFacts<C>: { [string]: string } the facts a decision reads, named; C is the context providers receive

---@class AssembledPolicy<C, T>: { [integer]: PolicyStep } one policy as LoadPolicies hands it back, contributions applied
---@field result "single"|"product"|"fold"
---@field refusal (fun(ctx: C): T)|nil declared by the owner's Refusal; false is the refusal when absent
---@field shape string[]|nil the fields every Answer must carry, when the owner declared T a record
---@field form (fun(ctx: C, spring: SpringBoth, ...: any): C|nil)|nil forms this moment's context into the entry's own table, for the key its parameters name; declared by the owner's FormContext
---@field arity integer|nil how many key arguments the form takes after ctx and spring, when the runtime could read it

---@class PolicyIdentity
---@field owner string the module whose policy or context this is
---@field category string its name within the module
---@field result "single"|"product"|"fold"|nil how a policy's results combine
---@field shape string[]|nil Single only: the fields every Answer must carry
---@field facts boolean|nil true for facts: provided, not evaluated

-- The fields a shape names: the function is called once, at declaration, with a table that records every field read
-- off it, in order, each once. `function(t) return t.canShare, t.amount end` names canShare and amount.
---@param shape fun(t: table): ...
---@return string[]
function Policy.FieldsOf(shape)
	local fields, seen = {}, {}
	local recorder = setmetatable({}, {
		__index = function(_, name)
			if not seen[name] then
				seen[name] = true
				fields[#fields + 1] = name
			end
			return nil
		end,
	})
	shape(recorder)
	assert(#fields > 0, "Policy.Single(steps, shape): the shape read no field off its record")
	return fields
end

---@generic T: table
---@param steps T enum of step names
---@param shape (fun(t: table): ...)|nil the record every Answer must be, named by reading its fields: `function(t) return t.canShare, t.amount end`; declare it when T is a record, and Evaluate holds every Answer to those fields, a contributor's included
---@return T
function Policy.Single(steps, shape)
	assert(type(steps) == "table" and getmetatable(steps) == nil, "Policy.Single(steps)")
	assert(
		shape == nil or type(shape) == "function",
		"Policy.Single(steps, shape): shape names the record's fields by reading them: function(t) return t.a, t.b end"
	)
	return setmetatable(steps, { __result = "single", __shape = shape and Policy.FieldsOf(shape) or nil })
end

---@generic T: table
---@param steps T enum of step names
---@return T
function Policy.Product(steps)
	assert(type(steps) == "table" and getmetatable(steps) == nil, "Policy.Product(steps)")
	return setmetatable(steps, { __result = "product" })
end

---@generic C
---@param steps PolicySteps<C, C>
---@return PolicySteps<C, C>
function Policy.Fold(steps)
	assert(type(steps) == "table" and getmetatable(steps) == nil, "Policy.Fold(steps)")
	return setmetatable(steps, { __result = "fold" })
end

---@generic C, T
---@param target PolicySteps<C, T> the target policy's steps, as its owner declared them
---@param names table<string, string> the steps this module adds, by name
---@return PolicySteps<C, T> the contribution, typed as the target: its steps take the owner's context and produce the owner's result
function Policy.Contributes(target, names)
	local identity = Policy.IdentityOf(target)
	assert(identity ~= nil and not identity.facts, "Policy.Contributes(target, names): target must be a policy's steps")
	assert(type(names) == "table" and getmetatable(names) == nil, "Policy.Contributes(target, names)")
	return setmetatable(names, { __contributes = identity })
end

---@generic T: table
---@param facts T enum of fact names
---@return T
function Policy.Facts(facts)
	assert(type(facts) == "table" and getmetatable(facts) == nil, "Policy.Facts(facts)")
	return setmetatable(facts, { __facts = true })
end

---@param member string
---@return string
function Policy.KeyOf(member)
	return (member
		:gsub("(%u)", function(c)
			return "_" .. c:lower()
		end)
		:sub(2))
end

-- How many key arguments a form takes after ctx and spring: read off the function where the runtime offers debug,
-- so an Ask with the wrong number of arguments is refused by name; nil where it does not, and the ask is trusted.
---@param form function
---@return integer|nil
function Policy.KeyArity(form)
	local ok, info = pcall(function()
		return debug.getinfo(form, "u")
	end)
	if not ok or type(info) ~= "table" or type(info.nparams) ~= "number" or info.isvararg then
		return nil
	end
	assert(info.nparams >= 2, "PolicyChain: FormContext(form): a form takes ctx and spring, then its key")
	return info.nparams - 2
end

---@param owner string the module's name
---@param members table PascalCase name -> a policy's step enum (Single, Product or Fold), Contributes or Facts
---@param source string|nil where they were declared, for messages
function Policy.Declare(owner, members, source)
	local where = source and (source .. ": ") or "Policy.Declare: "
	for member, steps in pairs(members) do
		local meta = type(steps) == "table" and getmetatable(steps) or nil
		assert(
			meta ~= nil and (meta.__result ~= nil or meta.__facts or meta.__contributes),
			where
				.. tostring(member)
				.. " must declare itself: Single(...), Product(...), Fold(...), Contributes(...) or Facts(...)"
		)
		assert(
			meta.__policy == nil,
			where .. tostring(member) .. " is already " .. tostring(meta.__policy and meta.__policy.owner) .. "'s"
		)
		local category = Policy.KeyOf(member)
		if meta.__contributes then
			meta.__policy = { owner = owner, category = category, contributes = meta.__contributes }
		elseif meta.__facts then
			meta.__policy = { owner = owner, category = category, facts = true }
		else
			meta.__policy = { owner = owner, category = category, result = meta.__result, shape = meta.__shape }
		end
	end
end

---@param target table
---@return boolean
function Policy.IsFacts(target)
	local meta = type(target) == "table" and getmetatable(target) or nil
	return meta ~= nil and meta.__facts == true
end

---@param steps table
---@return PolicyIdentity|nil
function Policy.IdentityOf(steps)
	local meta = type(steps) == "table" and getmetatable(steps) or nil
	return meta and meta.__policy or nil
end

---@class PolicyOp
---@field op "add"|"refusal"|"form"
---@field kind "if"|"unless"|"answer"|"factor"|"apply"|nil add only
---@field name string|nil add only
---@field evaluate function|nil
---@field form function|nil form only
---@field arity integer|nil form only: the key's length, when the runtime could read it

---@class PolicyChain<C, T>
---@field steps table|nil the identity this chain builds against
---@field Unless fun(name: string, predicate: fun(ctx: C): boolean|nil): PolicyChain<C, T> truthy means the named condition holds and the policy refuses
---@field If fun(name: string, predicate: fun(ctx: C): boolean|nil): PolicyChain<C, T> falsy means the named condition fails to hold and the policy refuses
---@field Refusal fun(evaluate: fun(ctx: C): T): PolicyChain<C, T> how this policy shapes a refusal; false when never declared
---@field FormContext fun(form: fun(ctx: C, spring: SpringBoth, ...: any): C|nil): PolicyChain<C, T> how this policy's context is formed: into the entry's own table, from the key the form's own parameters name after ctx and spring, so the policy can be Asked by that key and the answer kept for the frame; a form with no key is one context per engine; the owner's alone
---@field Answer fun(name: string, evaluate: fun(ctx: C): T|nil): PolicyChain<C, T> Single only: a step that may produce the answer; the last step must be one
---@field Factor fun(name: string, evaluate: fun(ctx: C): number|nil): PolicyChain<C, T> Product only: a multiplier, or nil to contribute nothing
---@field Apply fun(name: string, evaluate: fun(ctx: C)): PolicyChain<C, T> Fold only: runs on the context and passes it on
---@field When fun(holds: fun(ctx: C): boolean): PolicyChain<C, T> the step just added runs only when this holds; otherwise an Apply does nothing, an Answer or Factor passes, a guard holds
---@field Build fun(): PolicyOp[]

---@generic C, T
---@param steps PolicySteps<C, T>|nil the policy's steps, as the owner declared them
---@return PolicyChain<C, T>
function Policy.Chain(steps)
	local ops = {} ---@type PolicyOp[]
	local chain = { steps = steps }

	---@param verb string
	---@param kind "if"|"unless"|"answer"|"factor"|"apply"
	---@param name string
	---@param evaluate function
	local function add(verb, kind, name, evaluate)
		assert(type(name) == "string" and type(evaluate) == "function", "PolicyChain: " .. verb .. "(name, evaluate)")
		ops[#ops + 1] = { op = "add", kind = kind, name = name, evaluate = evaluate }
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
	chain.Factor = function(name, evaluate)
		add("Factor", "factor", name, evaluate)
		return chain
	end
	chain.Apply = function(name, evaluate)
		add("Apply", "apply", name, evaluate)
		return chain
	end
	chain.When = function(holds)
		assert(type(holds) == "function", "PolicyChain: When(holds)")
		local last = ops[#ops]
		assert(
			last ~= nil and last.op == "add",
			"PolicyChain: .When must follow an If, Unless, Answer, Factor or Apply"
		)
		local evaluate, kind = last.evaluate, last.kind
		local skipped = kind == "if" and true or (kind == "unless" and false) or nil
		last.evaluate = function(ctx)
			if holds(ctx) then
				return evaluate(ctx)
			end
			return skipped
		end
		return chain
	end
	chain.Refusal = function(evaluate)
		assert(type(evaluate) == "function", "PolicyChain: Refusal(evaluate)")
		ops[#ops + 1] = { op = "refusal", evaluate = evaluate }
		return chain
	end
	chain.FormContext = function(form)
		assert(type(form) == "function", "PolicyChain: FormContext(form): form(ctx, spring, ...key)")
		ops[#ops + 1] = { op = "form", form = form, arity = Policy.KeyArity(form) }
		return chain
	end
	chain.Build = function()
		return ops
	end
	return chain
end

---@param steps table the policy under assembly (an AssembledPolicy being built), mutated in place
---@param ops PolicyOp[]
---@param origin string for error messages: the file the ops came from
---@param contributed boolean|nil true when the ops come from a module other than the owner: its steps, Answers included, land before the owner's terminal; only the owner's Answer may be last
function Policy.Assemble(steps, ops, origin, contributed)
	local function indexOf(name)
		for i, step in ipairs(steps) do
			if step.name == name then
				return i
			end
		end
		return nil
	end
	for _, op in ipairs(ops) do
		if op.op == "add" then
			assert(indexOf(op.name) == nil, origin .. ": the policy already has a step named " .. op.name)
			local at = #steps + 1
			if (contributed or op.kind ~= "answer") and #steps > 0 and steps[#steps].kind == "answer" then
				at = #steps
			end
			table.insert(steps, at, { name = op.name, kind = op.kind, evaluate = op.evaluate, file = origin })
		elseif op.op == "refusal" then
			assert(steps.refusal == nil, origin .. ": the policy already has a Refusal")
			steps.refusal = op.evaluate
		elseif op.op == "form" then
			assert(steps.form == nil, origin .. ": the policy already has a FormContext")
			steps.form, steps.arity = op.form, op.arity
		end
	end
end

---@param shape string[] the owner's declared fields
---@param answer any what a step answered
---@param step PolicyStep the step that answered
function Policy.CheckShape(shape, answer, step)
	local who = (step.file or "?") .. ": " .. (step.category and (step.category .. ".") or "") .. step.name
	if type(answer) ~= "table" then
		error(who .. " answered a " .. type(answer) .. "; the owner's shape is a record", 0)
	end
	for _, field in ipairs(shape) do
		if answer[field] == nil then
			error(who .. " answered without " .. field .. "; the owner's shape requires it", 0)
		end
	end
end

local KIND_LABEL =
	{ ["if"] = "a guard", unless = "a guard", answer = "an Answer", factor = "a Factor", apply = "an Apply" }

---@param steps PolicyStep[]
---@param result "single"|"product"|"fold"
---@param label string owner.category, for error messages
function Policy.Validate(steps, result, label)
	if result == "product" then
		for _, step in ipairs(steps) do
			assert(
				step.kind == "factor",
				label
					.. ": a product policy multiplies Factor results; "
					.. step.name
					.. " is "
					.. KIND_LABEL[step.kind]
			)
		end
		return
	end
	if result == "fold" then
		for _, step in ipairs(steps) do
			assert(
				step.kind == "apply",
				label
					.. ": a fold policy runs every Apply over the context; "
					.. step.name
					.. " is "
					.. KIND_LABEL[step.kind]
			)
		end
		return
	end
	assert(#steps > 0, label .. ": an empty policy")
	for _, step in ipairs(steps) do
		assert(
			step.kind == "if" or step.kind == "unless" or step.kind == "answer",
			label
				.. ": a single-result policy takes guards and Answers; "
				.. step.name
				.. " is "
				.. KIND_LABEL[step.kind]
		)
	end
	local last = steps[#steps]
	assert(
		last.kind == "answer",
		label .. ": a single-result policy ends with an Answer; " .. last.name .. " is " .. KIND_LABEL[last.kind]
	)
end

---@class PolicyProvision
---@field names string[]
---@field evaluate function one producer; each returned value assigns its name, in order
---@field default boolean|nil the owner's answer for a slot nobody provides

---@class PolicyEnrichment<C>
---@field facts table|nil the facts this enrichment provides for
---@field Provide (fun(name: string, evaluate: fun(ctx: C): any): PolicyEnrichment<C>)|(fun(name: string, name2: string, evaluate: fun(ctx: C): any, any): PolicyEnrichment<C>)|(fun(name: string, name2: string, name3: string, evaluate: fun(ctx: C): any, any, any): PolicyEnrichment<C>) the facts a producer answers, one name per return value, then the producer
---@field Default fun(name: string, evaluate: fun(ctx: C): any): PolicyEnrichment<C> the owner's value for a fact when no module provides it
---@field Build fun(): PolicyProvision[]

---@param facts table|nil the facts, as the owner declared them
---@return PolicyEnrichment<any>
function Policy.Enrichment(facts)
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

return Policy
