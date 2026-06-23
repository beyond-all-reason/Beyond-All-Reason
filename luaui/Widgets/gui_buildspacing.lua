local widget = widget ---@type Widget

function widget:GetInfo()
   return {
      name      = "Mouse Buildspacing",
      desc      = "Use mousebuttons 4 and 5 for buildspacing",
      author    = "Auswaschbar, Baldric",
      version   = "v1.0",
      date      = "Mar, 2010",
      license   = "GNU GPL, v3 or later",
      layer     = 200,
      enabled   = true,
   }
end

function widget:MousePress(mx, my, button)
	-- We consume the presses so they can't trigger other bindings, which makes us the handler's mouseOwner.
	-- But barwidgets.lua sends no MouseRelease for buttons 4/5 to clear it.
	-- So we release any stale mouse capture left over from a previous button 4/5 press.

	local wh = self.widgetHandler
	if wh.DisownMouse then
		wh:DisownMouse()
	elseif wh.mouseOwner == self then
		wh.mouseOwner = nil
	end

	-- Only act on mousebuttons 4 and 5
	if button ~= 4 and button ~= 5 then
		return false
	end

	-- Only while a build command is active (build commands have a negative cmdID)
	local _, cmdID = Spring.GetActiveCommand()
	if not (cmdID and cmdID < 0) then
		return false
	end

	-- Only when shift or shift+alt is held
	local alt, ctrl, meta, shift = Spring.GetModKeyState()
	if not shift or ctrl or meta then
		return false
	end

	if button == 4 then
		Spring.SendCommands("buildspacing inc")
	else
		Spring.SendCommands("buildspacing dec")
	end
	return true
end
