AnitnukeBST = class(Behaviour)

function AnitnukeBST:Name()
	return "AnitnukeBST"
end

AnitnukeBST.DebugEnabled = false



local CMD_STOCKPILE = 100

function AnitnukeBST:Init()
    self.lastStockpileFrame = 0
    self.finished = false
end

function AnitnukeBST:OwnerBuilt()
	self.finished = true
end

function AnitnukeBST:Update()
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

function AnitnukeBST:Activate()
	self.active = true
end

function AnitnukeBST:Deactivate()
	self.active = false
end

function AnitnukeBST:Priority()
	return 100
end
