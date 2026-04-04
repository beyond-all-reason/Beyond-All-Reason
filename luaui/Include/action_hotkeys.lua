local actionHotkeys = {}

for _, keybinding in pairs(SpringUnsynced.GetKeyBindings()) do
	local cmd = keybinding.command
	local boundWith = keybinding.boundWith
	if (not actionHotkeys[cmd]) or #boundWith < #actionHotkeys[cmd] then
		actionHotkeys[cmd] = boundWith
	end
	if keybinding.extra ~= nil and cmd ~= "chain" then
		local extra = keybinding.extra
		local cmd_extra = cmd .. "_" .. extra
		if (not actionHotkeys[cmd_extra]) or #boundWith < #actionHotkeys[cmd_extra] then
			actionHotkeys[cmd_extra] = boundWith
		end
	end
end

return actionHotkeys
