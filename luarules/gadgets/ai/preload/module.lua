Module = class(AIBase)

function Module:Name()
	return "no name defined"
end

function Module:internalName()
	return "module"
end

function Module:EchoDebug(...)
	if self.DebugEnabled then
		self.game:SendToConsole(self.game:GetTeamID(), self:Name(), ...)
	end
end

function Module:SetAI(ai)
	self.ai = ai
	self.game = ai.game
	self.map = ai.map
end