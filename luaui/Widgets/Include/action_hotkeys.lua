local actionHotkeys = {}

for _, keybinding in pairs(Spring.GetKeyBindings()) do
	local cmd = keybinding.command
	if (not actionHotkeys[cmd]) or keybinding.boundWith:len() < actionHotkeys[cmd]:len() then
		actionHotkeys[cmd] = keybinding.boundWith
	end
end

return actionHotkeys
