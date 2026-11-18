---
--- Defers calls to the end of the batch, which is deferred coupling.
--- Calls deferred while the batch ends run in later rounds, which is an iterative cycle policy.
---

local MAX_CASCADE_ROUNDS = 100

local depth = 0
local isRunningDeferredCalls = false
local deferredCount = 0
local deferredCalls, deferredFirstArguments, deferredSecondArguments = {}, {}, {}
local deferredThirdArguments, deferredFourthArguments = {}, {}
local deferredSubjects = {}

local function clearDeferredSubjects()
	for subject in pairs(deferredSubjects) do
		deferredSubjects[subject] = nil
	end
end

local function runDeferredCalls()
	isRunningDeferredCalls = true
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

		-- What this round's calls defer runs in the next round.
		local last = deferredCount
		for i = first, last do
			local call, a, b = deferredCalls[i], deferredFirstArguments[i], deferredSecondArguments[i]
			local c, d = deferredThirdArguments[i], deferredFourthArguments[i]
			deferredCalls[i], deferredFirstArguments[i], deferredSecondArguments[i] = nil, nil, nil
			deferredThirdArguments[i], deferredFourthArguments[i] = nil, nil
			call(a, b, c, d)
		end
		first = last + 1
	end
	for i = first, deferredCount do
		deferredCalls[i], deferredFirstArguments[i], deferredSecondArguments[i] = nil, nil, nil
		deferredThirdArguments[i], deferredFourthArguments[i] = nil, nil
	end
	deferredCount = 0
	isRunningDeferredCalls = false
end

local function startBatch()
	depth = depth + 1
end

local function endBatch()
	depth = depth - 1
	if depth == 0 and not isRunningDeferredCalls then
		runDeferredCalls()
	end
end

---Calls call(a, b, c, d) when the batch ends, or at once outside of a batch.
local function defer(call, a, b, c, d)
	deferredCount = deferredCount + 1
	deferredCalls[deferredCount], deferredFirstArguments[deferredCount], deferredSecondArguments[deferredCount] =
		call, a, b
	deferredThirdArguments[deferredCount], deferredFourthArguments[deferredCount] = c, d
	if depth == 0 and not isRunningDeferredCalls then
		runDeferredCalls()
	end
end

local function callNetValue(call, subject)
	deferredSubjects[subject] = nil
	call(subject)
end

---Like Defer, but makes one call per subject in a batch, so the call reads the subject's net value.
local function deferNetValue(call, subject)
	if not deferredSubjects[subject] then
		deferredSubjects[subject] = true
		defer(callNetValue, call, subject)
	end
end

---Drops every deferred call and closes the open batch.
local function reset()
	depth = 0
	isRunningDeferredCalls = false
	for i = 1, deferredCount do
		deferredCalls[i], deferredFirstArguments[i], deferredSecondArguments[i] = nil, nil, nil
		deferredThirdArguments[i], deferredFourthArguments[i] = nil, nil
	end
	deferredCount = 0
	clearDeferredSubjects()
end

return {
	Start = startBatch,
	End = endBatch,
	Defer = defer,
	DeferNetValue = deferNetValue,
	Reset = reset,
}
