local UDN = UnitDefNames
local gaiaTeamID = Spring.Utilities.GetScavTeamID() or Spring.GetGaiaTeamID()

local wallUnitDefs = {
	["arm"] = {
		[1] = {
			["land"] = {
				unarmed = {"armdrag"},
				armed = {"armclaw"},
			},
			["sea"] = {
				unarmed = {"armfdrag"},
				armed = {"armfdrag"}, -- placeholder,
			},
		},
		[2] = {
			["land"] = {
				unarmed = {"armfort"},
				armed = {"armlwall"},
			},
			["sea"] = {
				unarmed = {"armfdrag"}, -- placeholder,
				armed = {"armfdrag"}, -- placeholder,
			},
		},
	},
	["cor"] = {
		[1] = {
			["land"] = {
				unarmed = {"cordrag"},
				armed = {"cormaw"},
			},
			["sea"] = {
				unarmed = {"corfdrag"},
				armed = {"corfdrag"}, -- placeholder,
			},
		},
		[2] = {
			["land"] = {
				unarmed = {"corfort"},
				armed = {"cormwall"},
			},
			["sea"] = {
				unarmed = {"corfdrag"}, -- placeholder,
				armed = {"corfdrag"}, -- placeholder,
			},
		},
	},
	["leg"] = {
		[1] = {
			["land"] = {
				unarmed = {"legdrag"},
				armed = {"legdtr"},
			},
			["sea"] = {
				unarmed = {"legfdrag"},
				armed = {"legfdrag"}, -- placeholder,
			},
		},
		[2] = {
			["land"] = {
				unarmed = {"legforti"},
				armed = {"legrwall"},
			},
			["sea"] = {
				unarmed = {"legfdrag"}, -- placeholder,
				armed = {"legfdrag"}, -- placeholder,
			},
		},
	},
	["scav"] = {
		[1] = {
			["land"] = {
				unarmed = {"corscavdrag"},
				armed = {"corscavdtf", "corscavdtl", "corscavdtm"},
			},
			["sea"] = {
				unarmed = {"corfdrag"}, -- placeholder,
				armed = {"corfdrag"}, -- placeholder,
			},
		},
		[2] = {
			["land"] = {
				unarmed = {"corscavfort"},
				armed = {"corfdrag"}, -- placeholder,
			},
			["sea"] = {
				unarmed = {"corfdrag"}, -- placeholder,
				armed = {"corfdrag"}, -- placeholder,
			},
		},
	},
}


function BPWallOrPopup(faction, tier, surface)
	local wallRandom = math.random()
	if not faction then faction = "scav" end
	if not tier then tier = 1 end
	if not surface then surface = "land" end


	if wallRandom <= 0.1 and wallUnitDefs[faction][tier][surface].armed[1] then -- armed
		return UDN[wallUnitDefs[faction][tier][surface].armed[math.random(1, #wallUnitDefs[faction][tier][surface].armed)]].id
	elseif wallUnitDefs[faction][tier][surface].unarmed[1] then
		return UDN[wallUnitDefs[faction][tier][surface].unarmed[math.random(1, #wallUnitDefs[faction][tier][surface].unarmed)]].id
	else
		return UDN.corscavdrag.id
	end
end

local tiers = {
	T0 = 0,
	T1 = 1,
	T2 = 2,
	T3 = 3,
	T4 = 4,
}

local blueprintTypes = {
	Land = 1,
	Sea = 2,
}

return {
	Tiers = tiers,
	BlueprintTypes = blueprintTypes,
}
