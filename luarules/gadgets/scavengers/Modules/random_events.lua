RandomEventsFileList = VFS.DirList('luarules/gadgets/scavengers/RandomEvents/'..GameShortName..'/','*.lua')
for i = 1,#RandomEventsFileList do
	VFS.Include(RandomEventsFileList[i])
	Spring.Echo("Scav Random Events Directory: " ..RandomEventsFileList[i])
end

local function RefreshEventsList()
	UsedRandomEventsList = {}
	for i = 1,#RandomEventsList do
		table.insert(UsedRandomEventsList,RandomEventsList[i])
	end
end
RefreshEventsList()

function RandomEventTrigger(CurrentFrame)
	if not LastRandomEventFrame then LastRandomEventFrame = 1 end
	if not RandomEventMinimumDelay then RandomEventMinimumDelay = randomEventsConfig.randomEventMinimumDelay end
	if not RandomEventChance then RandomEventChance = randomEventsConfig.randomEventChance end
	RandomEventDice = math_random(1,RandomEventChance)
	
	if CurrentFrame - LastRandomEventFrame > RandomEventMinimumDelay then
		if RandomEventDice == 1 then
			if #UsedRandomEventsList > 1 then
				EventNumber = math_random(1,#UsedRandomEventsList)
			else
				EventNumber = 1
			end
			local Event = UsedRandomEventsList[EventNumber]
			Event(CurrentFrame)
			LastRandomEventFrame = CurrentFrame
			table.remove(UsedRandomEventsList, EventNumber)
			EventNumber = nil
			if #UsedRandomEventsList == 0 then
				RefreshEventsList()
			end
		end
	end
end
