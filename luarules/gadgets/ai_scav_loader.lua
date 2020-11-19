local enabled = false
local scavengersEnabled = false
local teams = Spring.GetTeamList()
for i = 1,#teams do
	local luaAI = Spring.GetTeamLuaAI(teams[i])
	if luaAI and luaAI ~= "" and string.sub(luaAI, 1, 12) == 'ScavengersAI' then
		scavengersAIEnabled = true
		scavengerAITeamID = i - 1
		break
	end
end
if scavengersAIEnabled then -- or (Spring.GetModOptions and (tonumber(Spring.GetModOptions().scavengers) or 0) ~= 0) then
	enabled = true
end

function gadget:GetInfo()
  return {
    name      = "loader for Scavenger mod",
    desc      = "123",
    author    = "Damgam",
    date      = "2019",
    layer     = -100,
    enabled   = enabled,
  }
end


function gadget:GameOver()
	gadgetHandler:RemoveGadget(self)
end

if not gadgetHandler:IsSyncedCode() then

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
		if Spring.GetConfigInt("scavmessages",1) == 1 then
			if Script.LuaUI("GadgetAddMessage") then
				Script.LuaUI.GadgetAddMessage(msg)
			end
		end
	end
	function SendNotification(_,msg)
		if Spring.GetConfigInt("scavmessages",1) == 1 then
			if Script.LuaUI("EventBroadcast") then
				local forceplay = (Spring.GetConfigInt("scavaudiomessages",1) == 1) and ' y' or ''
				Script.LuaUI.EventBroadcast("SoundEvents "..msg.." "..myPlayerID..forceplay)
			end
		end
	end

	local addedNotifications = false
	function addNotifications()
		if Script.LuaUI("AddNotification") then
			addedNotifications = true
			local unlisted = true	-- prevent these notifications showing in the game settings notifications tab

			-- ID,   file.wav,   timeout time,   exact duration of the .wav,   written message,   is unlisted?
			Script.LuaUI.AddNotification('scav_scavcomdetected', 'scavengers/scavcomdetected.wav', 20, 1.87, "Scavenger commander detected.", unlisted)
			Script.LuaUI.AddNotification('scav_unidentifiedObjectsDetected', 'scavengers/unidentifiedObjectsDetected.wav', 999999, 3.7, "Unidentified objects have been detected in the vicinity...", unlisted)
			Script.LuaUI.AddNotification('scav_classifiedAsScavengers', 'scavengers/classifiedAsScavengers.wav', 999999, 3.87, "Unidentified objects are now classified as Scavengers.", unlisted)
			Script.LuaUI.AddNotification('scav_scavadditionalcomdetected', 'scavengers/scavadditionalcomdetected.wav', 20, 3.14, "An additional Scavenger Commander detected.", unlisted)
			Script.LuaUI.AddNotification('scav_scavanotherscavcomdetected', 'scavengers/scavanotherscavcomdetected.wav', 20, 3.3, "Another Scavenger Commander detected in the area.", unlisted)
			Script.LuaUI.AddNotification('scav_scavnewcomentered', 'scavengers/scavnewcomentered.wav', 20, 2.94, "New Scavenger Commander entered this location.", unlisted)
			Script.LuaUI.AddNotification('scav_scavcomspotted', 'scavengers/scavcomspotted.wav', 20, 2.82, "An extra Scavenger Commander has been spotted.", unlisted)
			Script.LuaUI.AddNotification('scav_scavcomnewdetect', 'scavengers/scavcomnewdetect.wav', 20, 1.89, "New Scav Commander detected.", unlisted)
			Script.LuaUI.AddNotification('scav_droppodsDetectedInArea', 'scavengers/droppodsDetectedInArea.wav', 20, 1.43, "Scavenger Droppods detected in the area.", unlisted)
			Script.LuaUI.AddNotification('scav_scavfinalattack', 'scavengers/scavfinalattack.wav', 20, 4.8, "Scavengers are unleashing all they have. Their final assault has started.", unlisted)
			Script.LuaUI.AddNotification('scav_droppingUnits', 'scavengers/droppingUnits.wav', 20, 3.31, "Scavengers are dropping units in our area.", unlisted)

			Script.LuaUI.AddNotification('scav_scavfinalvictory', 'scavengers/scavfinalvictory.wav', 20, 10.5, "Good work commander. You survived all scavenger attacks. You are victorius! Celebrate and then try and annihilate them on the next map.", unlisted)
			Script.LuaUI.AddNotification('scav_scavfinalboss', 'scavengers/scavfinalboss.wav', 20, 10.5, "Commander, we've detected an abnormally large signature of scavenger unit. It's approaching slowly in your direction. Be prepared for the worst!", unlisted)
			Script.LuaUI.AddNotification('scav_scavfinal12remain', 'scavengers/scavfinal12remain.wav', 20, 3.93, "12.5 minutes remaining. Still a long fight ahead.", unlisted)
			Script.LuaUI.AddNotification('scav_scavfinal10remain', 'scavengers/scavfinal10remain.wav', 20, 1.49, "10 minutes remaining.", unlisted)
			Script.LuaUI.AddNotification('scav_scavfinal09remain', 'scavengers/scavfinal09remain.wav', 20, 2.7, "9 minutes remaining. Hold your line.", unlisted)
			Script.LuaUI.AddNotification('scav_scavfinal08remain', 'scavengers/scavfinal08remain.wav', 20, 1.43, "8 minutes remaining.", unlisted)
			Script.LuaUI.AddNotification('scav_scavfinal07remain', 'scavengers/scavfinal07remain.wav', 20, 3.6, "Still 7 minutes remaining. Fight your way through them.", unlisted)
			Script.LuaUI.AddNotification('scav_scavfinal06remain', 'scavengers/scavfinal06remain.wav', 20, 1.67, "6 minutes remaining.", unlisted)
			Script.LuaUI.AddNotification('scav_scavfinal05remain', 'scavengers/scavfinal05remain.wav', 20, 1.47, "5 minutes remaining. You are almost there.", unlisted)
			Script.LuaUI.AddNotification('scav_scavfinal04remain', 'scavengers/scavfinal04remain.wav', 20, 1.44, "Only 4 minutes remaining.", unlisted)
			Script.LuaUI.AddNotification('scav_scavfinal03remain', 'scavengers/scavfinal03remain.wav', 20, 1.44, "3 minute mark.", unlisted)
			Script.LuaUI.AddNotification('scav_scavfinal02remain', 'scavengers/scavfinal02remain.wav', 20, 1.82, "Only 2 minutes remaining.", unlisted)
			Script.LuaUI.AddNotification('scav_scavfinal01remain', 'scavengers/scavfinal01remain.wav', 20, 1.43, "1 minute remaining.", unlisted)

			Script.LuaUI.AddNotification('scav_scavheavyairdetected', 'scavengers/scavheavyairdetected.wav', 20, 3, "", unlisted) -- "Danger... high tech aircraft detected."
			Script.LuaUI.AddNotification('scav_scavbossdetected', 'scavengers/scavbossdetected.wav', 20, 8.45, "Critical danger! Scavengers have dropped a highly lethal boss unit in the area, destroy it before it reaches your base.", unlisted)
			Script.LuaUI.AddNotification('scav_scavtech3', 'scavengers/scavtech3.wav', 20, 5.34, "", unlisted)
			Script.LuaUI.AddNotification('scav_scavtech3b', 'scavengers/scavtech3b.wav', 20, 5.2, "", unlisted)
			Script.LuaUI.AddNotification('scav_scavtech3c', 'scavengers/scavtech3c.wav', 20, 5.14, "", unlisted)
			Script.LuaUI.AddNotification('scav_scavtech3d', 'scavengers/scavtech3d.wav', 20, 4.67, "", unlisted)
			Script.LuaUI.AddNotification('scav_scavtech3e', 'scavengers/scavtech3e.wav', 20, 3.18, "", unlisted)
			Script.LuaUI.AddNotification('scav_scavheavyshipsdetected', 'scavengers/scavheavyshipsdetected.wav', 20, 3.28, "Alert. Heavy ships detected in the area.", unlisted)
			--Script.LuaUI.AddNotification('scav_', 'scavengers/.wav', 20, 3, "", unlisted)

			Script.LuaUI.AddNotification('scav_eventmalfunctions', 'scavengers/scav-event-malfunctions.wav', 20, 3.02, "Alert! Scavenger malfunction detected.", unlisted)
			Script.LuaUI.AddNotification('scav_eventminiboss', 'scavengers/scav-event-miniboss.wav', 20, 4.23, "Alert! Miniboss Detected.", unlisted)
			Script.LuaUI.AddNotification('scav_eventswarm', 'scavengers/scav-event-swarmdetected.wav', 20, 3.76, "Warning! Scavenger swarm detected.", unlisted)
			Script.LuaUI.AddNotification('scav_eventcloud', 'scavengers/scav-event-cloud.wav', 20, 3.04, "Alert! Scavenger cloud approaching.", unlisted)

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

	if enabled then
		VFS.Include('luarules/gadgets/scavengers/boot.lua')
	end

end
