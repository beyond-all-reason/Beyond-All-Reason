local WavesVerbs = VFS.Include("modules/waves/lib/mission_verbs.lua")

local Packs = {}

---@type table<string, MissionWavePack>
Packs.Nouns = {
	Skirmish = WavesVerbs.Pack({ domain = "waves", name = "raptors.skirmish", module = "raptors", pack = "skirmish" }),
	Assault = WavesVerbs.Pack({ domain = "waves", name = "raptors.assault", module = "raptors", pack = "assault" }),
	Swarm = WavesVerbs.Pack({ domain = "waves", name = "raptors.swarm", module = "raptors", pack = "swarm" }),
}

--- difficulty nil means whatever the host set, which is what makes Swarm the multiplayer mode
--- rather than a preset of it. queens = false: a mission ends the pressure with a trigger.
---@type table<string, { difficulty: string|nil, queens: boolean, placement: WaveBurrowPlacement|nil, intensity: number, endless: boolean|nil, grace: number|nil, pace: number|nil }>
Packs.Presets = {
	skirmish = {
		difficulty = "easy",
		queens = false,
		placement = "avoid",
		intensity = 0.5,
		endless = false,
		grace = 0.1,
		pace = 3,
	},
	assault = {
		difficulty = "normal",
		queens = false,
		placement = "avoid",
		intensity = 1,
		endless = false,
		grace = 0.25,
		pace = 2,
	},
	swarm = {
		difficulty = nil,
		queens = true,
		placement = nil,
		intensity = 1,
		endless = nil,
	},
}

---@param packName string
---@return MissionWavePack|nil
function Packs.Ref(packName)
	for _, noun in pairs(Packs.Nouns) do
		if noun.pack == packName then
			return noun
		end
	end
	return nil
end

---A pack pins its dials by rewriting the snapshot the roster builder reads.
---@param packName string
---@param modOptions table the host's snapshot
---@return table
function Packs.ModOptions(packName, modOptions)
	local preset = Packs.Presets[packName]
	local snapshot = {}
	for key, value in pairs(modOptions) do
		snapshot[key] = value
	end
	if preset == nil then
		return snapshot
	end
	if preset.difficulty then
		snapshot.raptor_difficulty = preset.difficulty
	end
	if preset.placement then
		snapshot.raptor_raptorstart = preset.placement
	end
	if preset.endless ~= nil then
		snapshot.raptor_endless = preset.endless
	end
	if not preset.queens then
		snapshot.raptor_queen_count = 0
	end
	if preset.grace then
		snapshot.raptor_graceperiodmult = preset.grace
	end
	if preset.pace then
		snapshot.raptor_spawntimemult = preset.pace
	end
	return snapshot
end

return Packs
