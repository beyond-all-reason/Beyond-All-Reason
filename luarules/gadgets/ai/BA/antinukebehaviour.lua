AntinukeBehaviour = class(Behaviour)

function AntinukeBehaviour:Name()
	return "AntinukeBehaviour"
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
	if Spring.GetGameFrame() % 6000 == 4 then
		self.unit:Internal():ExecuteCustomCommand(CMD_STOCKPILE)
	end
end

function AntinukeBehaviour:Activate()
		self.active = true
end

function AntinukeBehaviour:Deactivate()
		self.active = false
end

function AntinukeBehaviour:Priority()
	return 51
end