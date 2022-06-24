AntinukeBST = class(Behaviour)

function AntinukeBST:Name()
	return "AntinukeBST"
end

AntinukeBST.DebugEnabled = true

function AntinukeBST:Init()
    self.finished = false
end

function AntinukeBST:OwnerBuilt()
	self.finished = true
	self.unit:Internal():Stockpile()
	self.unit:Internal():Stockpile()
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
