local enabled = false
local teams = Spring.GetTeamList()
for i = 1,#teams do
	local luaAI = Spring.GetTeamLuaAI(teams[i])
	if luaAI and luaAI ~= "" and string.sub(luaAI, 1, 12) == 'ScavengersAI' then
		scavengersAIEnabled = true
		scavengerAITeamID = i - 1
		break
	end
end
if scavengersAIEnabled then
	enabled = true
end

function gadget:GetInfo()
  return {
    name      = "loader for Scavenger mod",
    desc      = "123",
    author    = "Damgam",
    date      = "2019",
	license   = "GNU GPL, v2 or later",
    layer     = -100,
    enabled   = enabled,
  }
end

function gadget:GameOver()
	gadgetHandler:RemoveGadget(self)
end

if gadgetHandler:IsSyncedCode() then

	if enabled then
		VFS.Include('luarules/gadgets/scavengers/boot.lua')
	end

else

	local myPlayerID = Spring.GetMyPlayerID()

	function gadget:PlayerChanged(playerID)
		myPlayerID = Spring.GetMyPlayerID()
	end

	function SendMessage(_, msg)
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

	local function addNotifications()
		if Script.LuaUI("AddNotification") then
			addedNotifications = true
			local unlisted = true	-- prevent these notifications showing in the game settings notifications tab
			local soundsPath = 'Sounds/voice/allison'
			-- ID,   file.wav,   timeout time,   exact duration of the .wav,   written message,   is unlisted?
			Script.LuaUI.AddNotification('scav_scavcomdetected', {soundsPath .. '/scavengers/scavcomdetected.wav'}, 20, 1.87, 'scav.messages.commanderDetected1', unlisted)
			Script.LuaUI.AddNotification('scav_unidentifiedObjectsDetected', {soundsPath .. '/scavengers/unidentifiedObjectsDetected.wav'}, 999999, 3.7, 'scav.messages.commanderDetected2', unlisted)
			Script.LuaUI.AddNotification('scav_classifiedAsScavengers', {soundsPath .. '/scavengers/classifiedAsScavengers.wav'}, 999999, 3.87, 'scav.messages.commanderDetected3', unlisted)
			Script.LuaUI.AddNotification('scav_scavadditionalcomdetected', {soundsPath .. '/scavengers/scavadditionalcomdetected.wav'}, 20, 3.14, 'scav.messages.commanderDetected4', unlisted)
			Script.LuaUI.AddNotification('scav_scavanotherscavcomdetected', {soundsPath .. '/scavengers/scavanotherscavcomdetected.wav'}, 20, 3.3, 'scav.messages.commanderDetected5', unlisted)
			Script.LuaUI.AddNotification('scav_scavnewcomentered', {soundsPath .. '/scavengers/scavnewcomentered.wav'}, 20, 2.94, 'scav.messages.commanderDetected6', unlisted)
			Script.LuaUI.AddNotification('scav_scavcomspotted', {soundsPath .. '/scavengers/scavcomspotted.wav'}, 20, 2.82, 'scav.messages.unkownObjectsDetected', unlisted)
			Script.LuaUI.AddNotification('scav_scavcomnewdetect', {soundsPath .. '/scavengers/scavcomnewdetect.wav'}, 20, 1.89, 'scav.messages.classifiedAsScavengers', unlisted)
			Script.LuaUI.AddNotification('scav_droppodsDetectedInArea', {soundsPath .. '/scavengers/droppodsDetectedInArea.wav'}, 20, 1.43, 'scav.messages.dropPodsDetected', unlisted)
			Script.LuaUI.AddNotification('scav_scavfinalattack', {soundsPath .. '/scavengers/scavfinalattack.wav'}, 20, 4.8, 'scav.messages.finalAttack', unlisted)
			Script.LuaUI.AddNotification('scav_droppingUnits', {soundsPath .. '/scavengers/droppingUnits.wav'}, 20, 3.31, 'scav.messages.droppingUnits', unlisted)

			Script.LuaUI.AddNotification('scav_scavfinalvictory', {soundsPath .. '/scavengers/scavfinalvictory.wav'}, 20, 10.5, 'scav.messages.finalVictory', unlisted)
			Script.LuaUI.AddNotification('scav_scavfinalboss', {soundsPath .. '/scavengers/scavfinalboss.wav'}, 20, 10.5, 'scav.messages.finalBoss', unlisted)
			Script.LuaUI.AddNotification('scav_scavfinal12remain', {soundsPath .. '/scavengers/scavfinal12remain.wav'}, 20, 3.93, 'scav.messages.timeRemaining12', unlisted)
			Script.LuaUI.AddNotification('scav_scavfinal10remain', {soundsPath .. '/scavengers/scavfinal10remain.wav'}, 20, 1.49, 'scav.messages.timeRemaining10', unlisted)
			Script.LuaUI.AddNotification('scav_scavfinal09remain', {soundsPath .. '/scavengers/scavfinal09remain.wav'}, 20, 2.7, 'scav.messages.timeRemaining09', unlisted)
			Script.LuaUI.AddNotification('scav_scavfinal08remain', {soundsPath .. '/scavengers/scavfinal08remain.wav'}, 20, 1.43, 'scav.messages.timeRemaining08', unlisted)
			Script.LuaUI.AddNotification('scav_scavfinal07remain', {soundsPath .. '/scavengers/scavfinal07remain.wav'}, 20, 3.6, 'scav.messages.timeRemaining07', unlisted)
			Script.LuaUI.AddNotification('scav_scavfinal06remain', {soundsPath .. '/scavengers/scavfinal06remain.wav'}, 20, 1.67, 'scav.messages.timeRemaining06', unlisted)
			Script.LuaUI.AddNotification('scav_scavfinal05remain', {soundsPath .. '/scavengers/scavfinal05remain.wav'}, 20, 1.47, 'scav.messages.timeRemaining05', unlisted)
			Script.LuaUI.AddNotification('scav_scavfinal04remain', {soundsPath .. '/scavengers/scavfinal04remain.wav'}, 20, 1.44, 'scav.messages.timeRemaining04', unlisted)
			Script.LuaUI.AddNotification('scav_scavfinal03remain', {soundsPath .. '/scavengers/scavfinal03remain.wav'}, 20, 1.44, 'scav.messages.timeRemaining03', unlisted)
			Script.LuaUI.AddNotification('scav_scavfinal02remain', {soundsPath .. '/scavengers/scavfinal02remain.wav'}, 20, 1.82, 'scav.messages.timeRemaining02', unlisted)
			Script.LuaUI.AddNotification('scav_scavfinal01remain', {soundsPath .. '/scavengers/scavfinal01remain.wav'}, 20, 1.43, 'scav.messages.timeRemaining01', unlisted)
			Script.LuaUI.AddNotification('scav_scavheavyairdetected', {soundsPath .. '/scavengers/scavheavyairdetected.wav'}, 20, 3, "", unlisted) -- "Danger... high tech aircraft detected."
			Script.LuaUI.AddNotification('scav_scavbossdetected', {soundsPath .. '/scavengers/scavbossdetected.wav'}, 20, 8.45, 'scav.messages.bossDetected', unlisted)

			Script.LuaUI.AddNotification('scav_scavtech3', {soundsPath .. '/scavengers/scavtech3.wav'}, 20, 5.34, "", unlisted)
			Script.LuaUI.AddNotification('scav_scavtech3b', {soundsPath .. '/scavengers/scavtech3b.wav'}, 20, 5.2, "", unlisted)
			Script.LuaUI.AddNotification('scav_scavtech3c', {soundsPath .. '/scavengers/scavtech3c.wav'}, 20, 5.14, "", unlisted)
			Script.LuaUI.AddNotification('scav_scavtech3d', {soundsPath .. '/scavengers/scavtech3d.wav'}, 20, 4.67, "", unlisted)
			Script.LuaUI.AddNotification('scav_scavtech3e', {soundsPath .. '/scavengers/scavtech3e.wav'}, 20, 3.18, "", unlisted)
			Script.LuaUI.AddNotification('scav_scavheavyshipsdetected', {soundsPath .. '/scavengers/scavheavyshipsdetected.wav'}, 20, 3.28, 'scav.messages.heavyShipsDetected', unlisted)

			Script.LuaUI.AddNotification('scav_eventmalfunctions', {soundsPath .. '/scavengers/scav-event-malfunctions.wav'}, 20, 3.02, 'scav.messages.eventMalfunctions', unlisted)
			Script.LuaUI.AddNotification('scav_eventminiboss', {soundsPath .. '/scavengers/scav-event-miniboss.wav'}, 20, 4.23, 'scav.messages.eventMiniboss', unlisted)
			Script.LuaUI.AddNotification('scav_eventswarm', {soundsPath .. '/scavengers/scav-event-swarmdetected.wav'}, 20, 3.76, 'scav.messages.eventSwarm', unlisted)
			Script.LuaUI.AddNotification('scav_eventcloud', {soundsPath .. '/scavengers/scav-event-cloud.wav'}, 20, 3.04, 'scav.messages.eventCloud', unlisted)

		end
	end

	local function notifyFriendlyReinforcements(_, player, unit)
		if Script.LuaUI('GadgetMessageProxy') then
			SendMessage(_, Script.LuaUI.GadgetMessageProxy('scav.messages.reinforcements', { player = player, unitDefName = unit }))
		end
	end

	function gadget:Initialize()
		gadgetHandler:AddSyncAction("SendMessage", SendMessage)
		gadgetHandler:AddSyncAction("SendNotification", SendNotification)
		gadgetHandler:AddSyncAction("ScavFriendlyReinforcements", notifyFriendlyReinforcements)

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
end
