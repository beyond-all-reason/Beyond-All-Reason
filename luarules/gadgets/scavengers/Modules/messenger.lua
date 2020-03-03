
--ScavSendMessage("addmessage Global score: "..globalScore)

function pregameMessages(n)
	if n == 1800 then
		--ScavSendMessage("WARNING")
		--ScavSendVoiceMessage(scavengerSoundPath.."warning.wav")
	end
	
	if n == 1830 then
		ScavSendNotification("scav_unidentifiedObjectsDetected")
	end
	
	-- if n == 2100 then
	-- 	ScavSendMessage("... waiting for further data ... ")
	-- 	ScavSendVoiceMessage(scavengerSoundPath.."waitingForIntel.wav")
	-- end
	
	if n == 3900 then
		ScavSendNotification("scav_classifiedAsScavengers")
	end
	
	-- if n == 6300 then
	-- 	ScavSendMessage("WARNING")
	-- 	--ScavSendVoiceMessage(scavengerSoundPath.."warning.wav")
	-- end
	
	-- if n == 6330 then
	-- 	ScavSendMessage("Scavenger Droppods detected nearby")
	-- 	ScavSendVoiceMessage(scavengerSoundPath.."droppodsDetectedNearby.wav")
	-- end
	
	if n == 7200 then
		--ScavSendMessage("WARNING")
		--ScavSendVoiceMessage(scavengerSoundPath.."warning.wav")
	end
	
	if n == 7230 then
		ScavSendNotification("scav_droppodsDetectedInArea")
	end
	
	if n == 9000 then
		--ScavSendMessage("WARNING")
		--ScavSendVoiceMessage(scavengerSoundPath.."warning.wav")
	end
	
	if n == 9030 then
		ScavSendNotification("scav_droppingUnits")
	end
	
end

function BossFightMessages(BossWaveTimeLeft)
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
		ScavSendMessage("placeholder-scav-finalcountdown")
	end

	if BossWaveTimeLeft == 0 then
		ScavSendNotification("scav_scavfinalvictory")
	end
end