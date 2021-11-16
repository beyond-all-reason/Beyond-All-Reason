DefendBST = class(Behaviour)

function DefendBST:Name()
	return "DefendBST"
end

function DefendBST:Init()

end

function DefendBST:Update()
	local f = self.game:Frame()
	if f % 33 ~= 0 then
		return

	end
	self.prio = 0
	local distance = math.huge
	local tg = nil
	for dist,cell in pairs(self.ai.defendhst:scanRisk() )do
		local d = self.ai.tool:Distance(self.unit:Internal():GetPosition(),cell.target)
		if d < distance then
			distance = d
			tg = cell.target
		end


	end
	if tg  then
		self.unit:Internal():Move(tg)
		self.prio = 1000

	end



end

function DefendBST:Priority()
	return self.prio or 0
end
