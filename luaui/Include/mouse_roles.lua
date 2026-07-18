-- Resolve which physical mouse button currently carries an engine mouse-role action
-- (mouseprimary = select/confirm, mousesecondary = default command), so widgets follow
-- a rebound/swapped mouse setup instead of hardcoding button 1/3.

local function isButtonBoundTo(button, action)
	local binds = Spring.GetKeyBindings("mouse" .. button)
	if binds then
		for i = 1, #binds do
			if binds[i].command == action then
				return true
			end
		end
	end
	return false
end

return {
	isPrimaryButton = function(button)
		return isButtonBoundTo(button, "mouseprimary")
	end,
	isSecondaryButton = function(button)
		return isButtonBoundTo(button, "mousesecondary")
	end,
}
