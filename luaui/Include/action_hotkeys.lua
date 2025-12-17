local actionHotkeys = {}

for _, keybinding in pairs(Spring.GetKeyBindings()) do
	local cmd = keybinding.command
	if (not actionHotkeys[cmd]) or keybinding.boundWith:len() < actionHotkeys[cmd]:len() then
		actionHotkeys[cmd] = keybinding.boundWith
	end
	if keybinding.command == "select" then
		local select_Cmd = keybinding.select
		if (not actionHotkeys[select_Cmd]) or keybinding.boundWith:len() < actionHotkeys[select_Cmd]:len() then
			actionHotkeys[select_Cmd] = keybinding.boundWith
		end
	end
end

return actionHotkeys
