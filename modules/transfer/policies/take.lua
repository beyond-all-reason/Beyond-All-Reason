--- One Compute: callers need the delay terms to explain a refusal, so the answer
--- is always a record with a mode in it rather than an early nil.

local ModeEnums = VFS.Include("modules/context/mode_enums.lua")

Policies.Pipeline()
	.Compute("ModeAndDelay", function(ctx)
		local modOptions = (ctx and ctx.modOptions) or Spring.GetModOptions()
		return {
			mode = modOptions[ModeEnums.ModOptions.TakeMode] or ModeEnums.TakeMode.Enabled,
			delaySeconds = tonumber(modOptions[ModeEnums.ModOptions.TakeDelaySeconds]) or 30,
			delayCategory = modOptions[ModeEnums.ModOptions.TakeDelayCategory] or ModeEnums.UnitCategory.Resource,
		}
	end)
	.Register()
