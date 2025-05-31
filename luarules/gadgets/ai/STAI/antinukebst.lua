AntinukeBST = class(Behaviour)

function AntinukeBST:Name()
	return "AntinukeBST"
end

function AntinukeBST:Init()
	self.DebugEnabled = false
end

function AntinukeBST:Update()
	self:SetStock()
end

function AntinukeBST:SetStock()

	self.stock, self.pile = self.unit:Internal():CurrentStockpile()
	if self.stock + self.pile < 2 then
		self.ai.tool:GiveOrder(self.unit:Internal():ID(),CMD.STOCKPILE,0,0,'1-1')
	end
end

function AntinukeBST:Priority()
	return 100
end
