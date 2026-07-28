--- Whether a seat may be taken, and on what terms.
---
--- /take moves an abandoned team's assets to whoever asks. The mode decides
--- if it is available at all, and whether the units arrive stunned or held
--- back for a while — the anti-abuse terms, without which taking a dying
--- ally is strictly better than fighting.
---
--- One Compute, like unit_transfer and for the same reason: callers need the
--- delay terms in order to explain a refusal, so the answer is always a
--- record with a mode in it rather than an early nil.

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
