--- Synced contract of the construction module.
---
--- A builder can be told to stand down for a while — the delay a mode
--- attaches to receiving a constructor. Transfer applies it (it is the one
--- that knows a unit changed hands); construction serves it, because whether
--- a build step is allowed is construction's question and the engine asks it
--- here.

local Debuff = VFS.Include("modules/construction/lib/build_debuff.lua")

return {
	---Hold a builder off building until `seconds` have passed.
	---@param unitID integer
	---@param seconds number
	DelayBuilder = function(unitID, seconds)
		Debuff.Apply(unitID, seconds)
	end,

	---@param unitID integer
	---@return boolean
	IsBuilderDelayed = function(unitID)
		return Debuff.IsDelayed(unitID)
	end,
}
