local function spy(parent, target)
	local original = parent[target]
	local calls = {}
	local wrapper = function(...)
		local args = { ... }
		calls[#calls + 1] = table.copy(args)
		return original(unpack(args))
	end
	parent[target] = wrapper
	return {
		original = original,
		calls = calls,
		remove = function()
			parent[target] = original
		end
	}
end

local function mock(parent, target, fn)
	local original = parent[target]
	local calls = {}
	local wrapper = function(...)
		local args = { ... }
		calls[#calls + 1] = table.copy(args)
		if fn ~= nil then
			return fn(unpack(args))
		end
	end
	parent[target] = wrapper
	return {
		original = original,
		calls = calls,
		remove = function()
			parent[target] = original
		end
	}
end

return {
	spy = spy,
	mock = mock,
}
