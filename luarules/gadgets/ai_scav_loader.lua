function gadget:GetInfo()
  return {
    name      = "loader for Scavenger mod",
    desc      = "123",
    author    = "Damgam",
    date      = "2019",
    layer     = -100,
    enabled   = true,
	}
end

if (not gadgetHandler:IsSyncedCode()) then

	local isSpec = Spring.GetSpectatingState()
	local myTeamID = Spring.GetMyTeamID()
	local myPlayerID = Spring.GetMyPlayerID()
	local myAllyTeamID = Spring.GetMyAllyTeamID()
	function gadget:PlayerChanged(playerID)
		isSpec = Spring.GetSpectatingState()
		myTeamID = Spring.GetMyTeamID()
		myPlayerID = Spring.GetMyPlayerID()
		myAllyTeamID = Spring.GetMyAllyTeamID()
	end

	function SendMessage(_,msg)
		if tonumber(Spring.GetConfigInt("scavmessages",1) or 1) == 1 then
			if Script.LuaUI("GadgetAddMessage") then
				Script.LuaUI.GadgetAddMessage(msg)
			end
		end
	end
	function SendNotification(_,msg)
		if tonumber(Spring.GetConfigInt("scavmessages",1) or 1) == 1 then
			if Script.LuaUI("EventBroadcast") then
				Script.LuaUI.EventBroadcast("SoundEvents "..msg.." "..myPlayerID)
			end
		end
	end

	local addedNotifications = false
	function addNotifications()
		if Script.LuaUI("AddNotification") then
			addedNotifications = true
			local defaultDuration = 3

			-- ID,   file.wav,   timeout time,   exact duration of the .wav,   written message,   unlisted?
			Script.LuaUI.AddNotification('scav_scavcomdetected', 'scavengers/scavcomdetected.wav', 30, 1.87, "Scavenger commander detected", true)
			Script.LuaUI.AddNotification('scav_unidentifiedObjectsDetected', 'scavengers/unidentifiedObjectsDetected.wav', 999999, 3.7, "Unidentified objects have been detected in the vicinity...", true)
			Script.LuaUI.AddNotification('scav_classifiedAsScavengers', 'scavengers/classifiedAsScavengers.wav', 999999, 3.87, "Unidentified objects are now classified as Scavengers", true)

		end
	end

	function gadget:Initialize()
		gadgetHandler:AddSyncAction("SendMessage", SendMessage)
		gadgetHandler:AddSyncAction("SendNotification", SendNotification)

		addNotifications()
	end

	function gadget:Update()
		if not addedNotifications then
			addNotifications()
		end
	end

	function gadget:Shutdown()
		gadgetHandler:RemoveSyncAction("SendMessage")
		gadgetHandler:RemoveSyncAction("SendNotification")
	end

else

	scavengersEnabled = false
	if Spring.GetModOptions and (tonumber(Spring.GetModOptions().scavengers) or 0) ~= 0 then
		local teams = Spring.GetTeamList()

		for i = 1,#teams do
			local luaAI = Spring.GetTeamLuaAI(teams[i])
			if luaAI and luaAI ~= "" and string.sub(luaAI, 1, 12) == 'ScavengersAI' then
				scavengersAIEnabled = true
				scavengerAITeamID = i - 1
				break
			end
		end
		VFS.Include('luarules/gadgets/scavengers/boot.lua')
	end

end