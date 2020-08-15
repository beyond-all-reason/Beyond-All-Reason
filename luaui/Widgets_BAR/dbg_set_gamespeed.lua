function widget:GetInfo()
  return {
    name      = "Set gamespeed X",
    desc      = "Sets w /luaui gamespeed X to desired value",
    author    = "Beherith",
    date      = "2020",
    layer     = -10000000000000000000,
    enabled   = false,  --  loaded by default
  }
end

-- use bind KEY luaui gamespeed X in uikeys.txt

function widget:TextCommand(command)
	if string.find(command, "gamespeed", nil, true) == 1 then
		local targetspeed = nil
		targetspeed = tonumber(string.sub(command,10))
		--Spring.Echo("Got gamespeed command"..command .. "|"..targetspeed)
		if targetspeed then
			--Spring.Echo("Setting gamespeed to "..targetspeed)
			Spring.SendCommands ("setminspeed " .. targetspeed)
			Spring.SendCommands ("setmaxspeed " .. targetspeed)
		end
	end
end
