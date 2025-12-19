local actionHotkeys = {}

for _, keybinding in pairs(Spring.GetKeyBindings()) do
	local cmd = keybinding.command
	if (not actionHotkeys[cmd]) or keybinding.boundWith:len() < actionHotkeys[cmd]:len() then
		actionHotkeys[cmd] = keybinding.boundWith
	end
	if keybinding.extra ~= nil and cmd ~= "chain" then
		local extra = keybinding.extra
		local cmd_extra = cmd .. "_" .. extra
		if (not actionHotkeys[cmd_extra]) or keybinding.boundWith:len() < actionHotkeys[cmd_extra]:len() then
			actionHotkeys[cmd_extra] = keybinding.boundWith
		end
	end
end

return actionHotkeys
