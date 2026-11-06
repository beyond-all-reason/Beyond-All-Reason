-- Actions bound to one key that sets a different state per number of quick taps (`bind l,l,l firestate 1`,
-- `bind l,l firestate 0`, `bind l firestate 2`): action -> { key = "l", [taps] = state, ... }
local tapHotkeys = {}

for _, keybinding in ipairs(Spring.GetKeyBindings()) do
	local state = tonumber(keybinding.extra)
	local keyset = keybinding.boundWith:lower()
	if state and not keyset:find("+", 1, true) then
		local key = keyset:match("^[^,]+")
		local _, commas = keyset:gsub(",", ",")
		local taps = commas + 1
		local chain = tapHotkeys[keybinding.command]
		if not chain then
			chain = { key = key }
			tapHotkeys[keybinding.command] = chain
		end
		-- the first bind of a keyset wins, as it does in the engine
		if chain.key == key and chain[taps] == nil and (key .. ","):rep(taps):sub(1, -2) == keyset then
			chain[taps] = state
		end
	end
end

-- a single tap alone is an ordinary hotkey
for action, chain in pairs(tapHotkeys) do
	if not (chain[1] and chain[2]) then
		tapHotkeys[action] = nil
	end
end

return tapHotkeys
