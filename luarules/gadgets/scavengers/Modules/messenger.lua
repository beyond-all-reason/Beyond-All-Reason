
--ScavSendMessage("addmessage Global score: "..globalScore)

function pregameMessages(n)
	if n == 1800 then
		ScavSendMessage("WARNING")
		--ScavSendVoiceMessage(scavengerSoundPath.."warning.wav")
	end
	
	if n == 1830 then
		ScavSendMessage("Unidentified objects have been detected in the vicinity...")
		ScavSendVoiceMessage(scavengerSoundPath.."unidentifiedObjectsDetected.wav")
	end
	
	-- if n == 2100 then
	-- 	ScavSendMessage("... waiting for further data ... ")
	-- 	ScavSendVoiceMessage(scavengerSoundPath.."waitingForIntel.wav")
	-- end
	
	if n == 3900 then
		ScavSendMessage("Unidentified objects are now classified as Scavengers")
		ScavSendVoiceMessage(scavengerSoundPath.."classifiedAsScavengers.wav")
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