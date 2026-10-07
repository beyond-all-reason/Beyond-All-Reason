local function loadSender()
	local env = setmetatable({
		CMD = { ATTACK = 20, INSERT = 1, OPT_SHIFT = 32, OPT_CTRL = 64, OPT_ALT = 128, OPT_RIGHT = 16 },
	}, { __index = _G })
	local chunk = assert(loadfile("common/luaUtilities/native_attack_orders.lua"))
	setfenv(chunk, env)
	return chunk(), env
end

local function sequence(n, offset)
	local values = {}
	for i = 1, n do
		values[i] = i + (offset or 0)
	end
	return values
end

-- Independently mirror the engine wire format, including shared-header sentinels.
local function packetBytes(units, commands)
	local id, opts, size = commands[1][1], commands[1][3], #commands[1][2]
	local params = 0
	for _, cmd in ipairs(commands) do
		if id ~= cmd[1] then
			id = 0
		end
		if opts ~= cmd[3] then
			opts = 255
		end
		if size ~= #cmd[2] then
			size = 65535
		end
		params = params + #cmd[2]
	end
	return 17
		+ 2 * #units
		+ 4 * params
		+ #commands * ((id == 0 and 4 or 0) + (opts == 255 and 1 or 0) + (size == 65535 and 2 or 0))
end

local function verify(send, env, sources, targets, options)
	local deliveries, packets = {}, 0
	local prepend = options.meta and not options.shift
	local baseOptions = (options.ctrl and 64 or 0) + (options.alt and 128 or 0) + (options.right and 16 or 0)
	local function emit(units, commands, pairwise)
		packets = packets + 1
		assert.is_false(pairwise)
		assert.is_true(packetBytes(units, commands) <= 8192)
		for unitIndex, unit in ipairs(units) do
			local count = deliveries[unit] or 0
			for _, cmd in ipairs(commands) do
				count = count + 1
				if unitIndex > 1 then
					-- All sources receive this same array; validate its contents once.
				elseif prepend then
					assert.same({
						env.CMD.INSERT,
						{ 0, env.CMD.ATTACK, baseOptions, targets[#targets - count + 1] },
						128,
					}, cmd)
				else
					assert.same({
						env.CMD.ATTACK,
						{ targets[count] },
						baseOptions + ((options.shift or count > 1) and 32 or 0),
					}, cmd)
				end
			end
			deliveries[unit] = count
		end
	end
	assert.is_true(send(sources, targets, options, emit))
	for _, unit in ipairs(sources) do
		assert.are.equal(#targets, deliveries[unit])
	end
	assert.are.equal(#sources, #deliveries)
	return packets
end

describe("native Attack packet batching", function()
	for mask = 0, 31 do
		local function has(flag)
			return math.floor(mask / flag) % 2 == 1
		end
		local options = { shift = has(1), meta = has(2), ctrl = has(4), alt = has(8), right = has(16) }
		it("preserves target order and modifiers across both source and command splits", function()
			local send, env = loadSender()
			assert.is_true(verify(send, env, sequence(300), sequence(4000, 10000), options) > 2)
		end)
	end
	it("uses one packet for N sources plus M commands when they fit", function()
		local send, env = loadSender()
		assert.are.equal(1, verify(send, env, sequence(1200), sequence(1000, 10000), {}))
	end)
	it("handles exact packet limits and a one-target overflow", function()
		local send, env = loadSender()
		assert.are.equal(1, verify(send, env, sequence(1), sequence(510, 10000), { meta = true }))
		assert.is_true(verify(send, env, sequence(1), sequence(511, 10000), { meta = true }) > 1)
		assert.are.equal(1, verify(send, env, sequence(1), sequence(2043, 10000), { shift = true }))
		assert.is_true(verify(send, env, sequence(1), sequence(2044, 10000), { shift = true }) > 1)
		assert.are.equal(1, verify(send, env, sequence(5), sequence(1633, 10000), {}))
		assert.is_true(verify(send, env, sequence(5), sequence(1634, 10000), {}) > 1)
	end)
	it("leaves empty selections and targets to the caller", function()
		local send = loadSender()
		local function emit()
			error("unexpected packet")
		end
		assert.is_false(send({}, { 1 }, {}, emit))
		assert.is_false(send({ 1 }, {}, {}, emit))
	end)
end)
