local eventFile

local randomEventsFileList = VFS.DirList('luarules/gadgets/scavengers/RandomEvents/' .. Game.gameShortName .. '/','*.lua')
for i = 1, #randomEventsFileList do
	eventFile = VFS.Include(randomEventsFileList[i])

	for _, event in pairs(eventFile) do
		table.insert(RandomEventsList, event)
	end

	Spring.Echo("[Scavengers] Loading random event file: " .. randomEventsFileList[i])
end

local function refreshEventsList()
	UsedRandomEventsList = {}
	for i = 1,#RandomEventsList do
		table.insert(UsedRandomEventsList,RandomEventsList[i])
	end
end
refreshEventsList()

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
				refreshEventsList()
			end
		end
	end
end
