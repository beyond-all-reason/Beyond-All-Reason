
--ScavSendMessage("addmessage Global score: "..globalScore)

function pregameMessages(n)
	if n == 1800 then
		ScavSendMessage("WARNING")
		--ScavSendVoiceMessage(scavengerSoundPath.."warning.wav")
	end
	
	if n == 1830 then
		--ScavSendMessage("Unidentified objects have been detected in the vicinity...")
		--ScavSendVoiceMessage(scavengerSoundPath.."unidentifiedObjectsDetected.wav")
		ScavSendNotification("scav_unidentifiedObjectsDetected")
	end
	
	-- if n == 2100 then
	-- 	ScavSendMessage("... waiting for further data ... ")
	-- 	ScavSendVoiceMessage(scavengerSoundPath.."waitingForIntel.wav")
	-- end
	
	if n == 3900 then
		--ScavSendMessage("Unidentified objects are now classified as Scavengers")
		--ScavSendVoiceMessage(scavengerSoundPath.."classifiedAsScavengers.wav")
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
		ScavSendMessage("WARNING")
		--ScavSendVoiceMessage(scavengerSoundPath.."warning.wav")
	end
	
	if n == 7230 then
		ScavSendMessage("Scavenger Droppods detected in the area")
		ScavSendVoiceMessage(scavengerSoundPath.."droppodsDetectedInArea.wav")
	end
	
	if n == 9000 then
		ScavSendMessage("WARNING")
		--ScavSendVoiceMessage(scavengerSoundPath.."warning.wav")
	end
	
	if n == 9030 then
		ScavSendMessage("Scavengers are dropping units in the area")
		ScavSendVoiceMessage(scavengerSoundPath.."droppingUnits.wav")
	end
	
end

function BossFightMessages(BossWaveTimeLeft)
	if not BossWaveFirstMessage then
		ScavSendVoiceMessage(scavengerSoundPath.."scavfinalattack.wav")
		ScavSendMessage("placeholder-scav-final-attack")
		BossWaveFirstMessage = true
	end

	if BossWaveTimeLeft == 750 then
		ScavSendVoiceMessage(scavengerSoundPath.."scavfinal12remain.wav")
		ScavSendMessage("placeholder-scav-12min")
	end

	if BossWaveTimeLeft == 600 then
		ScavSendVoiceMessage(scavengerSoundPath.."scavfinal10remain.wav")
		ScavSendMessage("placeholder-scav-10min")
	end

	if BossWaveTimeLeft == 540 then
		ScavSendVoiceMessage(scavengerSoundPath.."scavfinal09remain.wav")
		ScavSendMessage("placeholder-scav-9min")
	end

	if BossWaveTimeLeft == 480 then
		ScavSendVoiceMessage(scavengerSoundPath.."scavfinal08remain.wav")
		ScavSendMessage("placeholder-scav-8min")
	end

	if BossWaveTimeLeft == 420 then
		ScavSendVoiceMessage(scavengerSoundPath.."scavfinal07remain.wav")
		ScavSendMessage("placeholder-scav-7min")
	end

	if BossWaveTimeLeft == 360 then
		ScavSendVoiceMessage(scavengerSoundPath.."scavfinal06remain.wav")
		ScavSendMessage("placeholder-scav-6min")
	end

	if BossWaveTimeLeft == 300 then
		ScavSendVoiceMessage(scavengerSoundPath.."scavfinal05remain.wav")
		ScavSendMessage("placeholder-scav-5min")
	end

	if BossWaveTimeLeft == 240 then
		ScavSendVoiceMessage(scavengerSoundPath.."scavfinal04remain.wav")
		ScavSendMessage("placeholder-scav-4min")
	end

	if BossWaveTimeLeft == 180 then
		ScavSendVoiceMessage(scavengerSoundPath.."scavfinal03remain.wav")
		ScavSendMessage("placeholder-scav-3min")
	end

	if BossWaveTimeLeft == 120 then
		ScavSendVoiceMessage(scavengerSoundPath.."scavfinal02remain.wav")
		ScavSendMessage("placeholder-scav-2min")
	end

	if BossWaveTimeLeft == 60 then
		ScavSendVoiceMessage(scavengerSoundPath.."scavfinal01remain.wav")
		ScavSendMessage("placeholder-scav-1min")
	end

	if BossWaveTimeLeft == 10 then
		ScavSendVoiceMessage(scavengerSoundPath.."scavfinalcountdown.wav")
		ScavSendMessage("placeholder-scav-finalcountdown")
	end

	if BossWaveTimeLeft == 0 then
		ScavSendVoiceMessage(scavengerSoundPath.."scavfinalvictory.wav")
		ScavSendMessage("placeholder-scav-victory")
	end
end