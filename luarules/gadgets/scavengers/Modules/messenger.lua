
--ScavSendMessage("addmessage Global score: "..globalScore)

function pregameMessages(n)

	if n == 1800 then
		ScavSendMessage("... warning ...")
	end
	
	if n == 1830 then
		ScavSendMessage("Unidentified objects have been detected in the vicinity...")
	end
	
	if n == 2100 then
		ScavSendMessage("... waiting for further intel ... ")
	end
	
	if n == 5400 then
		ScavSendMessage("Unidentified objects are now classified as Scavengers")
	end
	
	if n == 6300 then
		ScavSendMessage("... warning ...")
	end
	
	if n == 6330 then
		ScavSendMessage("Scavenger Droppods detected nearby")
	end
	
	if n == 7200 then
		ScavSendMessage("... warning ...")
	end
	
	if n == 7230 then
		ScavSendMessage("Scavenger Droppods detected in our area")
	end
	
	if n == 9000 then
		ScavSendMessage("... warning ...")
	end
	
	if n == 9030 then
		ScavSendMessage("Scavengers are dropping units in our area")
	end
	
end