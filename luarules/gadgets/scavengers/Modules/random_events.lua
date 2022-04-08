if not scavconfig.modules.randomEventsModule then
	return {
		GameFrame = function () end,
	}
end

local randomEvents = {}
local availableRandomEvents = {}

local eventFile
local randomEventsFileList = VFS.DirList('luarules/gadgets/scavengers/RandomEvents/' .. Game.gameShortName .. '/','*.lua')
for i = 1, #randomEventsFileList do
	eventFile = VFS.Include(randomEventsFileList[i])

	for _, event in ipairs(eventFile) do
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
local randomEventMinimumDelay = scavconfig.randomEventsConfig.randomEventMinimumDelay
local randomEventChance = scavconfig.randomEventsConfig.randomEventChance

local function triggerRandomEvent(currentFrame)
	local eventNumber
	eventNumber = math.random(1,#availableRandomEvents)

	local eventFunction = availableRandomEvents[eventNumber]
	eventFunction(currentFrame)
	lastRandomEventFrame = currentFrame
	table.remove(availableRandomEvents, eventNumber)

	if #availableRandomEvents == 0 then
		refreshEventsList()
	end
end

local function gameFrame(n)
	if n%30 == 20 and scavengerGamePhase ~= "initial" then
		local randomEventDice = math.random(1, randomEventChance)

		if n - lastRandomEventFrame > randomEventMinimumDelay then
			if randomEventDice == 1 then
				triggerRandomEvent(n)
			end
		end
	end
end

return {
	GameFrame = gameFrame,
}