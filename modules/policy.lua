local Policy = {}

---@class PolicyContext a context that carries the match's modoptions, for a policy whose steps read them
---@field springRepo Spring the engine, or a spec's stand-in: a step reads the match through its context
---@field modOptions table<string, string|number|boolean>

---@class PolicySteps<C, T>: { [string]: string } step names for one policy; C is the context its evaluates receive, T the result it produces

---@class AssembledPolicy<C, T>: { [integer]: PolicyStep } one policy as LoadPolicies hands it back, contributions applied
---@field result "single"|"fold"
---@field refusal (fun(ctx: C): T)|nil declared by the owner's Refusal; false is the refusal when absent

---@class PolicyIdentity
---@field owner string the module whose policy or context this is
---@field category string its name within the module
---@field result "single"|"fold"|nil how a policy's results combine

---@generic T: table
---@param steps T enum of step names
---@return T
function Policy.Single(steps)
	assert(type(steps) == "table" and getmetatable(steps) == nil, "Policy.Single(steps)")
	return setmetatable(steps, { __result = "single" })
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
	assert(identity ~= nil, "Policy.Contributes(target, names): target must be a policy's steps")
	assert(type(names) == "table" and getmetatable(names) == nil, "Policy.Contributes(target, names)")
	return setmetatable(names, { __contributes = identity })
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

---@param owner string the module's name
---@param members table PascalCase name -> a policy's step enum (Single or Fold) or Contributes
---@param source string|nil where they were declared, for messages
function Policy.Declare(owner, members, source)
	local where = source and (source .. ": ") or "Policy.Declare: "
	for member, steps in pairs(members) do
		local meta = type(steps) == "table" and getmetatable(steps) or nil
		assert(
			meta ~= nil and (meta.__result ~= nil or meta.__contributes),
			where .. tostring(member) .. " must declare itself: Single(...), Fold(...) or Contributes(...)"
		)
		assert(
			meta.__policy == nil,
			where .. tostring(member) .. " is already " .. tostring(meta.__policy and meta.__policy.owner) .. "'s"
		)
		local category = Policy.KeyOf(member)
		if meta.__contributes then
			meta.__policy = { owner = owner, category = category, contributes = meta.__contributes }
		else
			meta.__policy = { owner = owner, category = category, result = meta.__result }
		end
	end
end

---@param steps table
---@return PolicyIdentity|nil
function Policy.IdentityOf(steps)
	local meta = type(steps) == "table" and getmetatable(steps) or nil
	return meta and meta.__policy or nil
end

---@class PolicyOp
---@field op "add"|"replace"|"remove"|"refusal"
---@field kind "if"|"unless"|"answer"|"apply"|nil add only
---@field name string
---@field evaluate function|nil
---@field after string|nil
---@field before string|nil

---@class PolicyChain<C, T>
---@field steps table|nil the identity this chain builds against
---@field Unless fun(name: string, predicate: fun(ctx: C): boolean|nil): PolicyChain<C, T> truthy means the named condition holds and the policy refuses
---@field If fun(name: string, predicate: fun(ctx: C): boolean|nil): PolicyChain<C, T> falsy means the named condition fails to hold and the policy refuses
---@field Refusal fun(evaluate: fun(ctx: C): T): PolicyChain<C, T> how this policy shapes a refusal; false when never declared
---@field Answer fun(name: string, evaluate: fun(ctx: C): T|nil): PolicyChain<C, T> Single only: a step that may produce the answer; the last step must be one
---@field Apply fun(name: string, evaluate: fun(ctx: C)): PolicyChain<C, T> Fold only: runs on the context and passes it on
---@field After fun(name: string): PolicyChain<C, T> place the step just added after the named step
---@field Before fun(name: string): PolicyChain<C, T> place the step just added before the named step
---@field When fun(holds: fun(ctx: C): boolean): PolicyChain<C, T> the step just added runs only when this holds; otherwise an Apply does nothing, an Answer passes, a guard holds
---@field Replace fun(name: string, evaluate: fun(ctx: C): T|nil): PolicyChain<C, T> the named step, with this evaluate
---@field Remove fun(name: string): PolicyChain<C, T>
---@field Build fun(): PolicyOp[]

---@generic C, T
---@param steps PolicySteps<C, T>|nil the policy's steps, as the owner declared them
---@return PolicyChain<C, T>
function Policy.Chain(steps)
	local ops = {} ---@type PolicyOp[]
	local chain = { steps = steps }

	---@param verb string
	---@param kind "if"|"unless"|"answer"|"apply"
	---@param name string
	---@param evaluate function
	local function add(verb, kind, name, evaluate)
		assert(type(name) == "string" and type(evaluate) == "function", "PolicyChain: " .. verb .. "(name, evaluate)")
		ops[#ops + 1] = { op = "add", kind = kind, name = name, evaluate = evaluate }
	end

	---@param modifier string
	---@return PolicyOp
	local function lastAdded(modifier)
		local last = ops[#ops]
		assert(
			last ~= nil and last.op == "add",
			"PolicyChain: ." .. modifier .. " must follow an If, Unless, Answer or Apply"
		)
		assert(last.after == nil and last.before == nil, "PolicyChain: a step is placed once")
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
	chain.Apply = function(name, evaluate)
		add("Apply", "apply", name, evaluate)
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
	chain.When = function(holds)
		assert(type(holds) == "function", "PolicyChain: When(holds)")
		local last = ops[#ops]
		assert(last ~= nil and last.op == "add", "PolicyChain: .When must follow an If, Unless, Answer or Apply")
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
	chain.Replace = function(name, evaluate)
		assert(type(name) == "string" and type(evaluate) == "function", "PolicyChain: Replace(name, evaluate)")
		ops[#ops + 1] = { op = "replace", name = name, evaluate = evaluate }
		return chain
	end
	chain.Remove = function(name)
		assert(type(name) == "string", "PolicyChain: Remove(name)")
		ops[#ops + 1] = { op = "remove", name = name }
		return chain
	end
	chain.Refusal = function(evaluate)
		assert(type(evaluate) == "function", "PolicyChain: Refusal(evaluate)")
		ops[#ops + 1] = { op = "refusal", evaluate = evaluate }
		return chain
	end
	chain.Build = function()
		return ops
	end
	return chain
end

---@param steps PolicyStep[] the policy under assembly, mutated in place
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
			if op.after ~= nil then
				at = assert(indexOf(op.after), origin .. ": no step named " .. op.after .. " to go after") + 1
			elseif op.before ~= nil then
				at = assert(indexOf(op.before), origin .. ": no step named " .. op.before .. " to go before")
			end
			table.insert(steps, at, { name = op.name, kind = op.kind, evaluate = op.evaluate })
		elseif op.op == "replace" then
			local at = assert(indexOf(op.name), origin .. ": no step named " .. op.name .. " to replace")
			steps[at] = { name = op.name, kind = steps[at].kind, evaluate = op.evaluate }
		elseif op.op == "remove" then
			table.remove(steps, assert(indexOf(op.name), origin .. ": no step named " .. op.name .. " to remove"))
		elseif op.op == "refusal" then
			assert(steps.refusal == nil, origin .. ": the policy already has a Refusal")
			steps.refusal = op.evaluate
		end
	end
end

local KIND_LABEL = { ["if"] = "a guard", unless = "a guard", answer = "an Answer", apply = "an Apply" }

---@param steps PolicyStep[]
---@param result "single"|"fold"
---@param label string owner.category, for error messages
function Policy.Validate(steps, result, label)
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

return Policy
