--
-- Custom Options Definition Table format
--
-- A detailed example of how this format works can be found
-- in the spring source under:
-- AI/Skirmish/NullAI/data/AIOptions.lua
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local options = {
	{ -- section
		key    = 'performance',
		name   = 'Performance Relevant Settings',
		desc   = 'These settings may be relevant for both CPU usage and AI difficulty.',
		type   = 'section',
	},
	{ -- bool
		key     = 'cheating',
		name    = 'LOS cheating',
		desc    = 'Enable LOS cheating',
		type    = 'bool',
		section = 'performance',
		def     = false,
	},
	{ -- bool
		key     = 'ally_aware',
		name    = 'Alliance awareness',
		desc    = 'Consider allies presence while making expansion desicions',
		type    = 'bool',
		section = 'performance',
		def     = true,
	},
	{ -- bool
		key     = 'comm_merge',
		name    = 'Merge neighbour Circuits',
		desc    = 'Merge spatially close Circuit ally commanders',
		type    = 'bool',
		section = 'performance',
		def     = true,
	},
-- 	{ -- number (int->uint)
-- 		key     = 'random_seed',
-- 		name    = 'Random seed',
-- 		desc    = 'Seed for random number generator (int)',
-- 		type    = 'number',
-- 		def     = 1337
-- 	},

	{ -- string
		key     = 'disabledunits',
		name    = 'Disabled units',
		desc    = 'Disable usage of specific units.\nSyntax: armwar+armpw+raveparty\nkey: disabledunits',
		type    = 'string',
		def     = '',
	},
	{ -- string
		key     = 'config_file',
		name    = 'Config file parts',
		desc    = 'Load only specific config files, e.g. behaviour.json, economy.json, factory.json.\nSyntax: behaviour+economy+factory\nkey: config_file',
		type    = 'string',
		def     = 'behaviour+block_map+build_chain+commander+economy+factory+response',
	},
--	{ -- string
--		key     = 'json',
--		name    = 'JSON',
--		desc    = 'Per-AI config.\nkey: json',
--		type    = 'string',
--		def     = '',
--	},

--	{ -- section
--		key    = 'config_override',
--		name   = 'Config parts',
--		desc   = 'Overrides config elements.',
--		type   = 'section',
--	},
--	{ -- string
--		key     = 'factory',
--		name    = 'Factory config',
--		desc    = 'Overrides factory part of config.',
--		type    = 'string',
--		section = 'config_override',
--		def     = '',
--	},
--	{ -- string
--		key     = 'behaviour',
--		name    = 'Behaviour config',
--		desc    = 'Overrides behaviour part of config.',
--		type    = 'string',
--		section = 'config_override',
--		def     = '',
--	},
}

return options
