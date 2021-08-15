AntinukeBST = class(Behaviour)

function AntinukeBST:Name()
	return "AntinukeBST"
end

AntinukeBST.DebugEnabled = false



local CMD_STOCKPILE = 100

function AntinukeBST:Init()
    self.lastStockpileFrame = 0
    self.finished = false
end

function AntinukeBST:OwnerBuilt()
	self.finished = true
end

function AntinukeBST:Update()
	if not self.active then return end

	if self.finished and self.ai.needAntinuke then
		local f = self.game:Frame()
		if self.lastStockpileFrame == 0 or f > self.lastStockpileFrame + 1000 then
			local floats = api.vectorFloat()
			floats:push_back(1)
			self.unit:Internal():ExecuteCustomCommand(CMD_STOCKPILE, floats)
			self.lastStockpileFrame = f
		end
	end
end

function AntinukeBST:Activate()
	self.active = true
end

function AntinukeBST:Deactivate()
	self.active = false
end

function AntinukeBST:Priority()
	return 100
end
