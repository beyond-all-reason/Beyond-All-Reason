RandomEventsFileList = VFS.DirList('luarules/gadgets/scavengers/RandomEvents/'..GameShortName..'/','*.lua')
for i = 1,#RandomEventsFileList do
	VFS.Include(RandomEventsFileList[i])
	Spring.Echo("Scav Random Events Directory: " ..RandomEventsFileList[i])
end

function RandomEventTrigger(CurrentFrame)
	if not LastRandomEventFrame then LastRandomEventFrame = 1 end
	if not RandomEventMinimumDelay then RandomEventMinimumDelay = randomEventsConfig.randomEventMinimumDelay end
	if not RandomEventChance then RandomEventChance = randomEventsConfig.randomEventChance end
	RandomEventDice = math_random(1,RandomEventChance)
	
	if CurrentFrame - LastRandomEventFrame > RandomEventMinimumDelay then
		if RandomEventDice == 1 then
			local Event = RandomEventsList[math_random(1,#RandomEventsList)]
			Event(CurrentFrame)
			LastRandomEventFrame(CurrentFrame)
		end
	end
end

