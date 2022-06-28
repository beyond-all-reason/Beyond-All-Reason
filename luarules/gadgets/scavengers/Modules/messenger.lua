
--ScavSendMessage("addmessage Global score: "..globalScore)

local function pregameMessages(n)
	-- if n > scavconfig.gracePeriod+100 then
	-- 	return
	-- end
	-- if n == scavconfig.gracePeriod-7200 then
	-- 	--ScavSendMessage("WARNING")
	-- 	--ScavSendVoiceMessage(scavengerSoundPath.."warning.wav")
	-- end

	-- if n == scavconfig.gracePeriod-7170 then
	-- 	ScavSendNotification("scav_unidentifiedObjectsDetected")
	-- end

	-- if n == 2100 then
	-- 	ScavSendMessage("... waiting for further data ... ")
	-- 	ScavSendVoiceMessage(scavengerSoundPath.."waitingForIntel.wav")
	-- end

	-- if n == scavconfig.gracePeriod-5100 then
	-- 	ScavSendNotification("scav_classifiedAsScavengers")
	-- end

	-- if n == 6300 then
	-- 	ScavSendMessage("WARNING")
	-- 	--ScavSendVoiceMessage(scavengerSoundPath.."warning.wav")
	-- end

	-- if n == 6330 then
	-- 	ScavSendMessage("Scavenger Droppods detected nearby")
	-- 	ScavSendVoiceMessage(scavengerSoundPath.."droppodsDetectedNearby.wav")
	-- end

	-- if n == scavconfig.gracePeriod-1800 then
	-- 	--ScavSendMessage("WARNING")
	-- 	--ScavSendVoiceMessage(scavengerSoundPath.."warning.wav")
	-- end

	-- if n == 3600 then
	-- 	ScavSendNotification("scav_droppodsDetectedInArea")
	-- end

	if n == scavconfig.gracePeriod then
		--ScavSendMessage("WARNING")
		--ScavSendVoiceMessage(scavengerSoundPath.."warning.wav")
	end

	if scavengerGamePhase ~= "initial" and (not initialMessageSent) then
		initialMessageSent = true
		ScavSendNotification("scav_droppingUnits")
	end

end

local function bossFightMessages(BossWaveTimeLeft)
	if not BossWaveFirstMessage then
		ScavSendNotification("scav_scavfinalattack")
		BossWaveFirstMessage = true
	end

	if BossWaveTimeLeft == 750 then
		ScavSendNotification("scav_scavfinal12remain")
	end

	if BossWaveTimeLeft == 600 then
		ScavSendNotification("scav_scavfinal10remain")
	end

	if BossWaveTimeLeft == 540 then
		ScavSendNotification("scav_scavfinal09remain")
	end

	if BossWaveTimeLeft == 480 then
		ScavSendNotification("scav_scavfinal08remain")
	end

	if BossWaveTimeLeft == 420 then
		ScavSendNotification("scav_scavfinal07remain")
	end

	if BossWaveTimeLeft == 360 then
		ScavSendNotification("scav_scavfinal06remain")
	end

	if BossWaveTimeLeft == 300 then
		ScavSendNotification("scav_scavfinal05remain")
	end

	if BossWaveTimeLeft == 240 then
		ScavSendNotification("scav_scavfinal04remain")
	end

	if BossWaveTimeLeft == 180 then
		ScavSendNotification("scav_scavfinal03remain")
	end

	if BossWaveTimeLeft == 120 then
		ScavSendNotification("scav_scavfinal02remain")
	end

	if BossWaveTimeLeft == 60 then
		ScavSendNotification("scav_scavfinal01remain")
	end

	if BossWaveTimeLeft == 10 then
		-- since ScavSendNotification would put this in a queue, we cant use that method for this message
		ScavSendVoiceMessage(scavengerSoundPath.."scavfinalcountdown.wav")
		ScavSendMessage("10")
	end

	if BossWaveTimeLeft == 9 then
		ScavSendMessage("9")
	end
	if BossWaveTimeLeft == 8 then
		ScavSendMessage("8")
	end
	if BossWaveTimeLeft == 7 then
		ScavSendMessage("7")
	end
	if BossWaveTimeLeft == 6 then
		ScavSendMessage("6")
	end
	if BossWaveTimeLeft == 5 then
		ScavSendMessage("5")
	end
	if BossWaveTimeLeft == 4 then
		ScavSendMessage("4")
	end
	if BossWaveTimeLeft == 3 then
		ScavSendMessage("3")
	end
	if BossWaveTimeLeft == 2 then
		ScavSendMessage("2")
	end
	if BossWaveTimeLeft == 1 then
		ScavSendMessage("1")
	end

	if BossWaveTimeLeft == 0 then
		ScavSendNotification("scav_scavfinalboss")
		--ScavSendNotification("scav_scavfinalvictory")
		FinalMessagePlayed = true
	end
end

return {
	pregameMessages = pregameMessages,
	BossFightMessages = bossFightMessages,
}