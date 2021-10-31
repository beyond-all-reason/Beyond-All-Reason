function widget:GetInfo()
	return {
		name      = "Auto Disable CUS",
		desc      = "Auto disabled CUS when fps gets below configint: cusThreshold",
		author    = "Floris",
		date      = "October 2021",
		license   = "GNU GPL, v2 or later",
		layer     = -99999,
		enabled   = true,
	}
end

local defaultThreshold = 30
local threshold = Spring.GetConfigInt("cusThreshold", defaultThreshold)
local cusWanted = (Spring.GetConfigInt("cus", 1) == 1)
local averageFps = math.min(120, threshold + 60)
local disabledCus = false
local chobbyInterface = false

function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1,18) == 'LobbyOverlayActive' then
		chobbyInterface = (msg:sub(1,19) == 'LobbyOverlayActive1')
	end
end

function widget:Initialize()
	WG.disabledCus = disabledCus
end

local sec = 0
function widget:Update(dt)
	sec = sec + dt
	if sec > 0.28 then
		local prevCusWanted = cusWanted
		cusWanted = (Spring.GetConfigInt("cus", 1) == 1)
		if not prevCusWanted and cusWanted then
			disabledCus = false
			WG.disabledCus = disabledCus
			averageFps = math.min(120, threshold + 30)
		end
	end
end

function widget:GameFrame(gameFrame)
	if gameFrame % 24 == 0 and not chobbyInterface then
		if cusWanted and not disabledCus then
			if WG['topbar'] and not WG['topbar'].showingRejoining() then
				if not select(6, Spring.GetMouseState()) then		-- mouse not offscreen
					averageFps = ((averageFps * 29) + Spring.GetFPS()) / 30
					threshold = Spring.GetConfigInt("cusThreshold", defaultThreshold)
					if not disabledCus then
						if averageFps <= threshold then
							Spring.SendCommands("luarules disablecus")
							Spring.SendCommands("option cus 0.5")
							disabledCus = true
							WG.disabledCus = disabledCus
							Spring.Echo(Spring.I18N('ui.disablingcus'))
						end
					end
				end
			end
		end
	end
end

function widget:GetConfigData(data)
	return {
		disabledCus = disabledCus
	}
end

function widget:SetConfigData(data)
	if Spring.GetGameFrame() > 0 and data.disabledCus ~= nil then
		disabledCus = data.disabledCus
	end
end
