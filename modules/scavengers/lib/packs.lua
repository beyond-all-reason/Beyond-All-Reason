local WavesVerbs = VFS.Include("modules/waves/lib/mission_verbs.lua")

local Packs = {}

---@type table<string, MissionWavePack>
Packs.Nouns = {
	Skirmish = WavesVerbs.Pack({
		domain = "waves",
		name = "scavengers.skirmish",
		module = "scavengers",
		pack = "skirmish",
	}),
	Assault = WavesVerbs.Pack({
		domain = "waves",
		name = "scavengers.assault",
		module = "scavengers",
		pack = "assault",
	}),
	Horde = WavesVerbs.Pack({ domain = "waves", name = "scavengers.horde", module = "scavengers", pack = "horde" }),
}

--- difficulty nil means whatever the host set: Horde is the multiplayer mode, not a preset of it.
--- Mission packs compress the clocks: four minutes of quiet in a mission beat is four minutes of nothing.
---@type table<string, { difficulty: string|nil, boss: boolean, placement: WaveBurrowPlacement|nil, intensity: number, endless: boolean|nil, grace: number|nil, pace: number|nil }>
Packs.Presets = {
	skirmish = {
		difficulty = "easy",
		boss = false,
		-- No start box to grow out of in a mission.
		placement = "avoid",
		intensity = 0.5,
		endless = false,
		grace = 0.1,
		pace = 3,
	},
	assault = {
		difficulty = "normal",
		boss = false,
		placement = "avoid",
		intensity = 1,
		endless = false,
		grace = 0.25,
		pace = 2,
	},
	horde = {
		difficulty = nil,
		boss = true,
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
		snapshot.scav_difficulty = preset.difficulty
	end
	if preset.placement then
		snapshot.scav_scavstart = preset.placement
	end
	if preset.endless ~= nil then
		snapshot.scav_endless = preset.endless
	end
	if not preset.boss then
		snapshot.scav_boss_count = 0
	end
	if preset.grace then
		snapshot.scav_graceperiodmult = preset.grace
	end
	if preset.pace then
		snapshot.scav_spawntimemult = preset.pace
	end
	return snapshot
end

return Packs
