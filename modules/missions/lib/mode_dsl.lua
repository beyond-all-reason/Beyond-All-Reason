--- Mission mode vocabulary over modules/mode_builder.lua: nouns for what the
--- mission runtime owns, serializers for the options those policies pin.

local ModeBuilder = VFS.Include("modules/mode_builder.lua")

local M = {}

M.Match = {
	End = { domain = "end" },
}

local Serializers = {
	-- triggers own the verdict: engine elimination never ends the match
	["end.scripted"] = function(_p, lock)
		return { deathmode = { value = "neverend", locked = lock.structure } }
	end,
}

M.Mode = ModeBuilder.Grammar({
	category = "missions",
	serializers = Serializers,
	verbs = {
		---The mission owns the noun's domain outright.
		Own = function(modeName, noun)
			return { ModeBuilder.DomainOf(modeName, "Own", noun, { ["end"] = true }, "Match.End") .. ".scripted" }
		end,
	},
})

return M
