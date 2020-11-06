Module = class(AIBase)

--- What is the human readable name off this object?
--
-- @return string the human friendly name
function Module:Name()
	return "error no name module name defined"
end

--- What is the internal name of this object?
--
-- Shard will not add this module if this is set to error
-- overriding this is *mandatory*
--
-- This gets used to define variable names in places
--
-- @return string the internal name
function Module:internalName()
	return "error"
end

function Module:Warn(...)
	self.game:SendToConsole(self.game:GetTeamID(), self.ai:Name(), self:Name(), 'Warning:', ...)
end

function Module:EchoDebug(...)
	if self.DebugEnabled then
		self.game:SendToConsole(self.game:GetTeamID(), self.ai:Name(), self:Name(), ...)
	end
end
