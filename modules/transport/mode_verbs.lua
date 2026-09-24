local ModeBuilder = VFS.Include("modules/mode_builder.lua")
local ModeEnums = VFS.Include("modules/game/enums.lua")
local TransportEnums = VFS.Include("modules/transport/enums.lua")

local Opt = TransportEnums.ModOptions

---@class GameModeChain
---@field SlowComTransport fun(enabled: boolean): GameModeChain Whether carrying your own commander slows a transport: writes comm_trans_slow.
---@field EnemyTransporting fun(which: TransportEnemyKey): GameModeChain Which enemy units transports may pick up: writes transportenemy.

return {
	category = ModeEnums.ModeCategories.Game,
	verbs = {
		SlowComTransport = ModeBuilder.Verb(function(modeName, enabled)
			assert(type(enabled) == "boolean", modeName .. ": .SlowComTransport expects true or false")
			return { enabled = enabled }
		end, function(p, lock)
			return { [Opt.CommanderTransportSlow] = { value = p.enabled, locked = lock.noun } }
		end),

		EnemyTransporting = ModeBuilder.Verb(function(modeName, which)
			ModeBuilder.OneOf(modeName, "EnemyTransporting", TransportEnums.TransportEnemy, which)
			return { which = which }
		end, function(p, lock)
			return { [Opt.TransportEnemy] = { value = p.which, locked = lock.noun } }
		end),
	},
}
