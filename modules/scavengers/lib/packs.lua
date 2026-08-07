--- The packs: named intensities of the same roster.
---
--- A pack is the noun a mission file and a mode preset both name. It is NOT
--- a separate roster — the scavengers have one roster — it is a shape:
--- Skirmish is pressure without a conclusion, Assault is a real fight, Horde
--- is the multiplayer mode with its boss at the end.
---
--- Composition is defined HERE, once, and not per mission. A mission picks a
--- pack and turns dials; it does not get to author a wave, because a mission
--- that authored its own composition would go stale the first time the
--- roster changed underneath it.

local Packs = {}

--- Each pack's name is its director name and its savegame key, and carries
--- the two domains it is used in: `domain` for the mode grammar's verbs,
--- `module`/`pack` for the mission DSL's spec rebuild.
---@type table<string, WavePackRef>
Packs.Nouns = {
	Skirmish = { domain = "waves", name = "scavengers.skirmish", module = "scavengers", pack = "skirmish" },
	Assault = { domain = "waves", name = "scavengers.assault", module = "scavengers", pack = "assault" },
	Horde = { domain = "waves", name = "scavengers.horde", module = "scavengers", pack = "horde" },
}

--- What each pack does to the roster it draws from.
---
--- `difficulty` picks a rung by name; nil means "whatever the host set",
--- which is what makes Horde the multiplayer mode rather than a preset of
--- it. `boss = false` means the pressure has no ending of its own — a
--- mission ends it with a trigger, which is the whole point of a skirmish.
---
--- The two mission packs also compress the clocks. A multiplayer game opens
--- with four minutes of quiet because the players are building a base; a
--- mission beat that opened with four minutes of quiet would just be four
--- minutes of nothing. Pressure starts when the mission says it starts.
---@type table<string, { difficulty: string|nil, boss: boolean, placement: WaveBurrowPlacement|nil, intensity: number, endless: boolean|nil, grace: number|nil, pace: number|nil }>
Packs.Presets = {
	skirmish = {
		difficulty = "easy",
		boss = false,
		-- No start box to grow out of in a mission: beacons appear wherever
		-- the players are not looking.
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
---@return WavePackRef|nil
function Packs.Ref(packName)
	for _, noun in pairs(Packs.Nouns) do
		if noun.pack == packName then
			return noun
		end
	end
	return nil
end

---The modoption snapshot a pack wants, laid over the host's.
---
---A pack that pins a difficulty pins it by rewriting the snapshot the roster
---builder reads, not by patching the roster afterwards — so a mission's
---"easy" is exactly the easy rung a multiplayer game would get.
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
