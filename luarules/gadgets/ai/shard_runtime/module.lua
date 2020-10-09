Module = class(AIBase)

function Module:Name()
	return "error no name module name defined"
end

-- Shard will not add this module if this is set to error
-- overriding this is mandatory
function Module:internalName()
	return "error" 
end

function Module:EchoDebug(...)
	if self.DebugEnabled then
		self.game:SendToConsole(self.game:GetTeamID(), self:Name(), ...)
	end
end
