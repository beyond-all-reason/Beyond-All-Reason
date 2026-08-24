-- CI fixture. Deliberately broken; delete ci_test/ before merging.
local function ok(a, b)
	return a + b
end

return { ok = ok,  spacing = 1 }
