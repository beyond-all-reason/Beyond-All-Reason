StockpileBehavior = class(Behaviour)

function StockpileBehavior:Name()
	return "StockpileBehavior"
end

local CMD_STOCKPILE = 100

function StockpileBehavior:Init()
    self.lastStockpileFrame = 0
    self.finished = false
end

function StockpileBehavior:OwnerBuilt()
	self.finished = true
end

function StockpileBehavior:Update()
	if Spring.GetGameFrame() % 6000 == 4 then
		self.unit:Internal():ExecuteCustomCommand(CMD_STOCKPILE)
	end
end

function StockpileBehavior:Activate()
		self.active = true
end

function StockpileBehavior:Deactivate()
		self.active = false
end

function StockpileBehavior:Priority()
	return 51
end