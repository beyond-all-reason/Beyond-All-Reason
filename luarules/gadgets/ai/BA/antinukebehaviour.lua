AntinukeBehaviour = class(Behaviour)

function AntinukeBehaviour:Name()
	return "AntinukeBehaviour"
end

local DebugEnabled = false

local function EchoDebug(inStr)
	if DebugEnabled then
		game:SendToConsole("AntinukeBehaviour: " .. inStr)
	end
end

local CMD_STOCKPILE = 100

function AntinukeBehaviour:Init()
    self.lastStockpileFrame = 0
    self.finished = false
end

function AntinukeBehaviour:OwnerBuilt()
	self.finished = true
end

function AntinukeBehaviour:Update()
	if not self.active then return end

	if self.finished and self.ai.needAntinuke then
		local f = game:Frame()
		if self.lastStockpileFrame == 0 or f > self.lastStockpileFrame + 1000 then
			local floats = api.vectorFloat()
			floats:push_back(1)
			self.unit:Internal():ExecuteCustomCommand(CMD_STOCKPILE, floats)
			self.lastStockpileFrame = f
		end
	end
end

function AntinukeBehaviour:Activate()
	self.active = true
end

function AntinukeBehaviour:Deactivate()
	self.active = false
end

function AntinukeBehaviour:Priority()
	return 100
end