local randomEvents = {}
local availableRandomEvents = {}

local eventFile
local randomEventsFileList = VFS.DirList('luarules/gadgets/scavengers/RandomEvents/' .. Game.gameShortName .. '/','*.lua')
for i = 1, #randomEventsFileList do
	eventFile = VFS.Include(randomEventsFileList[i])

	for _, event in pairs(eventFile) do
		table.insert(randomEvents, event)
	end

	Spring.Echo("[Scavengers] Loading random event file: " .. randomEventsFileList[i])
end

local function refreshEventsList()
	availableRandomEvents = {}
	for i = 1, #randomEvents do
		table.insert(availableRandomEvents,randomEvents[i])
	end
end

refreshEventsList()

local lastRandomEventFrame = 1

local function triggerRandomEvent(currentFrame)
	if not RandomEventMinimumDelay then RandomEventMinimumDelay = randomEventsConfig.randomEventMinimumDelay end
	if not RandomEventChance then RandomEventChance = randomEventsConfig.randomEventChance end
	local randomEventDice = math_random(1, RandomEventChance)
	local eventNumber
	
	if currentFrame - lastRandomEventFrame > RandomEventMinimumDelay then
		if randomEventDice == 1 then
			eventNumber = math_random(1,#availableRandomEvents)

			local event = availableRandomEvents[eventNumber]
			event(currentFrame)
			lastRandomEventFrame = currentFrame
			table.remove(availableRandomEvents, eventNumber)

			if #availableRandomEvents == 0 then
				refreshEventsList()
			end
		end
	end
end

return {
	TriggerRandomEvent = triggerRandomEvent
}