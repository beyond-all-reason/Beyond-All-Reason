AntinukeBST = class(Behaviour)

function AntinukeBST:Name()
	return "AntinukeBST"
end

function AntinukeBST:Init()
	self.DebugEnabled = true
	self.unit:Internal():Stockpile()
	self.unit:Internal():Stockpile()
end

function AntinukeBST:Update()
	self.stock, self.pile = self:CurrentStockpile()
	if self.stock + self.pile < 2 then
		self.unit:Internal():Stockpile()
	end
end

function AntinukeBST:Priority()
	return 100
end
