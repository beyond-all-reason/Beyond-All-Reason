
if not Spring.Utilities.Gametype.IsScavengers() then
	return
else
	return	-- new scavengers is active already!
end

function gadget:GetInfo()
	return {
		name      = "loader for Scavenger mod",
		desc      = "123",
		author    = "Damgam",
		date      = "2019",
		license   = "GNU GPL, v2 or later",
		layer     = -100,
		enabled   = true,
	}
end

local teams = Spring.GetTeamList()
for i = 1, #teams do
	local luaAI = Spring.GetTeamLuaAI(teams[i])
	if luaAI and luaAI ~= "" and string.sub(luaAI, 1, 12) == 'ScavengersAI' then
		scavengerAITeamID = i - 1
		break
	end
end

function gadget:GameOver()
	gadgetHandler:RemoveGadget(self)
end

if gadgetHandler:IsSyncedCode() then

	VFS.Include('luarules/gadgets/scavengers/boot.lua')

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
			if Script.LuaUI("NotificationEvent") then
				local forceplay = (Spring.GetConfigInt("scavaudiomessages",1) == 1) and ' y' or ''
				Script.LuaUI.NotificationEvent("SoundEvents "..msg.." "..myPlayerID..forceplay)
			end
		end
	end

	local addedNotifications = false

	local function addNotifications()
		if Script.LuaUI("AddNotification") then
			addedNotifications = true
			local unlisted = true	-- prevent these notifications showing in the game settings notifications tab

			-- ID,   file.wav,   timeout time,   exact duration of the .wav,   written message,   is unlisted?
			Script.LuaUI.AddNotification('scav_scavcomdetected', {'scavengers/scavcomdetected.wav'}, 20, 1.87, 'scav.messages.commanderDetected1', unlisted)
			Script.LuaUI.AddNotification('scav_unidentifiedObjectsDetected', {'scavengers/unidentifiedObjectsDetected.wav'}, 999999, 3.7, 'scav.messages.commanderDetected2', unlisted)
			Script.LuaUI.AddNotification('scav_classifiedAsScavengers', {'scavengers/classifiedAsScavengers.wav'}, 999999, 3.87, 'scav.messages.commanderDetected3', unlisted)
			Script.LuaUI.AddNotification('scav_scavadditionalcomdetected', {'scavengers/scavadditionalcomdetected.wav'}, 20, 3.14, 'scav.messages.commanderDetected4', unlisted)
			Script.LuaUI.AddNotification('scav_scavanotherscavcomdetected', {'scavengers/scavanotherscavcomdetected.wav'}, 20, 3.3, 'scav.messages.commanderDetected5', unlisted)
			Script.LuaUI.AddNotification('scav_scavnewcomentered', {'scavengers/scavnewcomentered.wav'}, 20, 2.94, 'scav.messages.commanderDetected6', unlisted)
			Script.LuaUI.AddNotification('scav_scavcomspotted', {'scavengers/scavcomspotted.wav'}, 20, 2.82, 'scav.messages.unkownObjectsDetected', unlisted)
			Script.LuaUI.AddNotification('scav_scavcomnewdetect', {'scavengers/scavcomnewdetect.wav'}, 20, 1.89, 'scav.messages.classifiedAsScavengers', unlisted)
			Script.LuaUI.AddNotification('scav_droppodsDetectedInArea', {'scavengers/droppodsDetectedInArea.wav'}, 20, 1.43, 'scav.messages.dropPodsDetected', unlisted)
			Script.LuaUI.AddNotification('scav_scavfinalattack', {'scavengers/scavfinalattack.wav'}, 20, 4.8, 'scav.messages.finalAttack', unlisted)
			Script.LuaUI.AddNotification('scav_droppingUnits', {'scavengers/droppingUnits.wav'}, 20, 3.31, 'scav.messages.droppingUnits', unlisted)

			Script.LuaUI.AddNotification('scav_scavfinalvictory', {'scavengers/scavfinalvictory.wav'}, 20, 10.5, 'scav.messages.finalVictory', unlisted)
			Script.LuaUI.AddNotification('scav_scavfinalboss', {'scavengers/scavfinalboss.wav'}, 20, 10.5, 'scav.messages.finalBoss', unlisted)
			Script.LuaUI.AddNotification('scav_scavfinal12remain', {'scavengers/scavfinal12remain.wav'}, 20, 3.93, 'scav.messages.timeRemaining12', unlisted)
			Script.LuaUI.AddNotification('scav_scavfinal10remain', {'scavengers/scavfinal10remain.wav'}, 20, 1.49, 'scav.messages.timeRemaining10', unlisted)
			Script.LuaUI.AddNotification('scav_scavfinal09remain', {'scavengers/scavfinal09remain.wav'}, 20, 2.7, 'scav.messages.timeRemaining09', unlisted)
			Script.LuaUI.AddNotification('scav_scavfinal08remain', {'scavengers/scavfinal08remain.wav'}, 20, 1.43, 'scav.messages.timeRemaining08', unlisted)
			Script.LuaUI.AddNotification('scav_scavfinal07remain', {'scavengers/scavfinal07remain.wav'}, 20, 3.6, 'scav.messages.timeRemaining07', unlisted)
			Script.LuaUI.AddNotification('scav_scavfinal06remain', {'scavengers/scavfinal06remain.wav'}, 20, 1.67, 'scav.messages.timeRemaining06', unlisted)
			Script.LuaUI.AddNotification('scav_scavfinal05remain', {'scavengers/scavfinal05remain.wav'}, 20, 1.47, 'scav.messages.timeRemaining05', unlisted)
			Script.LuaUI.AddNotification('scav_scavfinal04remain', {'scavengers/scavfinal04remain.wav'}, 20, 1.44, 'scav.messages.timeRemaining04', unlisted)
			Script.LuaUI.AddNotification('scav_scavfinal03remain', {'scavengers/scavfinal03remain.wav'}, 20, 1.44, 'scav.messages.timeRemaining03', unlisted)
			Script.LuaUI.AddNotification('scav_scavfinal02remain', {'scavengers/scavfinal02remain.wav'}, 20, 1.82, 'scav.messages.timeRemaining02', unlisted)
			Script.LuaUI.AddNotification('scav_scavfinal01remain', {'scavengers/scavfinal01remain.wav'}, 20, 1.43, 'scav.messages.timeRemaining01', unlisted)
			Script.LuaUI.AddNotification('scav_scavheavyairdetected', {'scavengers/scavheavyairdetected.wav'}, 20, 3, "", unlisted) -- "Danger... high tech aircraft detected."
			Script.LuaUI.AddNotification('scav_scavbossdetected', {'scavengers/scavbossdetected.wav'}, 20, 8.45, 'scav.messages.bossDetected', unlisted)

			Script.LuaUI.AddNotification('scav_scavtech3', {'scavengers/scavtech3.wav'}, 20, 5.34, "", unlisted)
			Script.LuaUI.AddNotification('scav_scavtech3b', {'scavengers/scavtech3b.wav'}, 20, 5.2, "", unlisted)
			Script.LuaUI.AddNotification('scav_scavtech3c', {'scavengers/scavtech3c.wav'}, 20, 5.14, "", unlisted)
			Script.LuaUI.AddNotification('scav_scavtech3d', {'scavengers/scavtech3d.wav'}, 20, 4.67, "", unlisted)
			Script.LuaUI.AddNotification('scav_scavtech3e', {'scavengers/scavtech3e.wav'}, 20, 3.18, "", unlisted)
			Script.LuaUI.AddNotification('scav_scavheavyshipsdetected', {'scavengers/scavheavyshipsdetected.wav'}, 20, 3.28, 'scav.messages.heavyShipsDetected', unlisted)

			Script.LuaUI.AddNotification('scav_eventmalfunctions', {'scavengers/scav-event-malfunctions.wav'}, 20, 3.02, 'scav.messages.eventMalfunctions', unlisted)
			Script.LuaUI.AddNotification('scav_eventminiboss', {'scavengers/scav-event-miniboss.wav'}, 20, 4.23, 'scav.messages.eventMiniboss', unlisted)
			Script.LuaUI.AddNotification('scav_eventswarm', {'scavengers/scav-event-swarmdetected.wav'}, 20, 3.76, 'scav.messages.eventSwarm', unlisted)
			Script.LuaUI.AddNotification('scav_eventcloud', {'scavengers/scav-event-cloud.wav'}, 20, 3.04, 'scav.messages.eventCloud', unlisted)

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
