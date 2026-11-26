---
--- Defers calls to the end of the batch, which is deferred coupling.
--- Calls deferred while the batch ends run in later rounds, which is an iterative cycle policy.
---

local MAX_CASCADE_ROUNDS = 100

local inBatch = false
local deferredCount = 0
local deferredCalls = {} ---@type table<integer, function>
local deferredFirstArguments, deferredSecondArguments = {}, {}
local deferredThirdArguments, deferredFourthArguments = {}, {}
local deferredSubjects = {}

local function logFailure(message)
	Spring.Log("batch.lua", LOG.ERROR, "[Mission API] " .. tostring(message))
end

local function clearDeferredSubjects()
	for subject in pairs(deferredSubjects) do
		deferredSubjects[subject] = nil
	end
end

local function runDeferredCalls()
	local first, rounds = 1, 0
	while first <= deferredCount do
		rounds = rounds + 1
		if rounds > MAX_CASCADE_ROUNDS then
			Spring.Log(
				"batch.lua",
				LOG.ERROR,
				"[Mission API] Deferred calls cascaded past " .. MAX_CASCADE_ROUNDS .. " rounds; the rest were dropped"
			)
			clearDeferredSubjects()
			break
		end

		-- Anything deferred by the calls in this round will run in the next round.
		local last = deferredCount
		for i = first, last do
			local call = deferredCalls[i]
			deferredCalls[i] = nil
			-- PERF: This is faster and lighter than variadic args. We have no fifth argument to pass.
			local a, b = deferredFirstArguments[i], deferredSecondArguments[i]
			deferredFirstArguments[i], deferredSecondArguments[i] = nil, nil
			local c, d = deferredThirdArguments[i], deferredFourthArguments[i]
			deferredThirdArguments[i], deferredFourthArguments[i] = nil, nil
			local success, message = pcall(call, a, b, c, d))
			if not success then
				logFailure(message)
			end
		end
		first = last + 1
	end
	for i = first, deferredCount do
		deferredCalls[i], deferredFirstArguments[i], deferredSecondArguments[i] = nil, nil, nil
		deferredThirdArguments[i], deferredFourthArguments[i] = nil, nil
	end
	deferredCount = 0
end

---Calls `call(...)` as one batch, or as part of the batch it is called in.
local function runBatch(call, ...)
	local wasInBatch = inBatch
	inBatch = true
	local success, message = pcall(call, ...)
	if not success then
		logFailure(message)
	end
	if not wasInBatch then
		runDeferredCalls()
		inBatch = false
	end
end

---Calls `call(a, b, c, d)` when the batch ends, or immediately when not in a batch.
local function defer(call, a, b, c, d)
	if not inBatch then
		runBatch(call, a, b, c, d)
		return
	end
	deferredCount = deferredCount + 1
	deferredCalls[deferredCount] = call
	deferredFirstArguments[deferredCount], deferredSecondArguments[deferredCount] = a, b
	deferredThirdArguments[deferredCount], deferredFourthArguments[deferredCount] = c, d
end

local function callNetValue(call, subject)
	deferredSubjects[subject] = nil
	call(subject)
end

---As `Defer`, but makes one call per subject in a batch, so the call reads the subject's net value.
local function deferNetValue(call, subject)
	if not deferredSubjects[subject] then
		deferredSubjects[subject] = true
		defer(callNetValue, call, subject)
	end
end

return {
	Run = runBatch,
	Defer = defer,
	DeferNetValue = deferNetValue,
}
