local musicTrackFilters = {}

-- Shared engine config so LuaUI, LuaIntro, and other music consumers use one source of truth.
-- Values are normalized track paths serialized as a pipe-delimited set.
musicTrackFilters.CONFIG_DISABLED_TRACKS = "MusicDisabledTracks"
musicTrackFilters.CONFIG_ENABLED_OVERRIDES = "MusicEnabledTrackOverrides"
musicTrackFilters.CONFIG_DISABLED_COMPOSERS = "MusicDisabledComposers"

local separator = "|"

function musicTrackFilters.NormalizePath(path)
	path = string.gsub(path or "", "\\", "/")
	path = string.gsub(path, "/$", "")
	return string.lower(path)
end

function musicTrackFilters.ParseSet(raw)
	local set = {}
	for value in string.gmatch(raw or "", "[^" .. separator .. "]+") do
		value = musicTrackFilters.NormalizePath(value)
		if value ~= "" then
			set[value] = true
		end
	end
	return set
end

function musicTrackFilters.SerializeSet(set)
	local values = {}
	for value, enabled in pairs(set or {}) do
		if enabled then
			values[#values + 1] = value
		end
	end
	table.sort(values)
	return table.concat(values, separator)
end

function musicTrackFilters.GetDisabledTracks()
	return musicTrackFilters.ParseSet(Spring.GetConfigString(musicTrackFilters.CONFIG_DISABLED_TRACKS, ""))
end

function musicTrackFilters.GetEnabledOverrides()
	return musicTrackFilters.ParseSet(Spring.GetConfigString(musicTrackFilters.CONFIG_ENABLED_OVERRIDES, ""))
end

function musicTrackFilters.GetDisabledComposers()
	return musicTrackFilters.ParseSet(Spring.GetConfigString(musicTrackFilters.CONFIG_DISABLED_COMPOSERS, ""))
end

local composerAliases = {
	["russel lucas-nutt"] = "Russell Lucas-Nutt",
}

local coverStyleSuffixes = {
	metal = true,
	christmas = true,
	polka = true,
}

local function trim(value)
	value = string.gsub(value or "", "^%s+", "")
	value = string.gsub(value, "%s+$", "")
	return string.gsub(value, "%s+", " ")
end

function musicTrackFilters.NormalizeComposer(composer)
	composer = trim(composer)
	local displayName = composerAliases[string.lower(composer)] or composer
	return string.lower(displayName), displayName
end

function musicTrackFilters.GetTrackComposers(trackPath)
	local filename = string.gsub(trackPath or "", "\\", "/")
	filename = string.match(filename, "([^/]+)$") or filename
	filename = string.gsub(filename, "%.%w+$", "")

	local composers = {}
	local seen = {}
	local function addComposer(name)
		local key, displayName = musicTrackFilters.NormalizeComposer(name)
		if key ~= "" and not seen[key] then
			seen[key] = true
			composers[#composers + 1] = { key = key, name = displayName }
		end
	end

	local primaryComposer = string.match(filename, "^(.-)%s+%-%s+")
	addComposer(primaryComposer or "Other Artists")

	-- Remix and cover credits are additional artists, not replacements for the
	-- original composer. Quoted subtitles and common style words are not names.
	for credit in string.gmatch(filename, "%(([^()]*)%)") do
		credit = trim(credit)
		local lowerCredit = string.lower(credit)
		if string.find(lowerCredit, "%sremix$") or string.find(lowerCredit, "%scover$") then
			local creditedArtist = trim(string.gsub(credit, "%s+[^%s]+%s*$", ""))
			local beforeSubtitle = string.match(creditedArtist, "^(.-)%s+['\"]")
			if beforeSubtitle then
				creditedArtist = trim(beforeSubtitle)
			end
			local nameWithoutStyle, finalWord = string.match(creditedArtist, "^(.*)%s+(%S+)$")
			if finalWord and coverStyleSuffixes[string.lower(finalWord)] then
				creditedArtist = trim(nameWithoutStyle)
			end
			if string.lower(creditedArtist) ~= "techno" then
				addComposer(creditedArtist)
			end
		end
	end

	return composers
end

function musicTrackFilters.IsTrackDisabledByComposer(trackPath, disabledComposers)
	for _, composer in ipairs(musicTrackFilters.GetTrackComposers(trackPath)) do
		if disabledComposers[composer.key] then
			return true
		end
	end
	return false
end

-- Infer the user-facing soundtrack pack from its stable VFS path.
function musicTrackFilters.GetTrackPack(trackPath)
	local path = musicTrackFilters.NormalizePath(trackPath)
	if string.find(path, "^music/custom/") then
		return "custom"
	elseif string.find(path, "^music/map/") then
		return "map"
	elseif string.find(path, "/events/raptors/") then
		return "raptors"
	elseif string.find(path, "/events/scavengers/") then
		return "scavengers"
	elseif string.find(path, "/events/aprilfools/") then
		return "aprilfools"
	elseif string.find(path, "/events/halloween/") then
		return "halloween"
	elseif string.find(path, "/events/xmas/") then
		return "xmas"
	elseif string.find(path, "^music/original/") then
		return "original"
	end
end

function musicTrackFilters.IsTrackInPack(trackPath, pack)
	local path = musicTrackFilters.NormalizePath(trackPath)
	if pack == "original" then
		return string.find(path, "^music/original/") ~= nil
	end
	return musicTrackFilters.GetTrackPack(path) == pack
end

function musicTrackFilters.IsPackEnabled(pack)
	if pack == "custom" then
		return Spring.GetConfigInt('UseSoundtrackCustom', 1) == 1
	elseif pack == "map" or pack == "original" then
		return Spring.GetConfigInt('UseSoundtrackNew', 1) == 1
	end

	if Spring.GetConfigInt('UseSoundtrackNew', 1) ~= 1 then
		return false
	elseif pack == "raptors" then
		-- The scenario owns its event soundtrack. Outside that scenario, the regular-game
		-- opt-in remains off by default unless the user enables the pack or a track override.
		return Spring.Utilities.Gametype.IsRaptors() or Spring.GetConfigInt('UseSoundtrackRaptors', 0) == 1
	elseif pack == "scavengers" then
		return Spring.Utilities.Gametype.IsScavengers() or Spring.GetConfigInt('UseSoundtrackScavengers', 0) == 1
	end

	-- Only one seasonal toggle is relevant at a time: the event toggle during its
	-- holiday window, or the post-event toggle during the rest of the year.
	local holidays = Spring.Utilities.Gametype.GetCurrentHolidays()
	if pack == "aprilfools" then
		if holidays["aprilfools"] then
			return Spring.GetConfigInt('UseSoundtrackAprilFools', 1) == 1
		end
		return Spring.GetConfigInt('UseSoundtrackAprilFoolsPostEvent', 0) == 1
	elseif pack == "halloween" then
		if holidays["halloween"] then
			return Spring.GetConfigInt('UseSoundtrackHalloween', 1) == 1
		end
		return Spring.GetConfigInt('UseSoundtrackHalloweenPostEvent', 0) == 1
	elseif pack == "xmas" then
		if holidays["xmas"] then
			return Spring.GetConfigInt('UseSoundtrackXmas', 1) == 1
		end
		return Spring.GetConfigInt('UseSoundtrackXmasPostEvent', 0) == 1
	end

	return true
end

function musicTrackFilters.IsTrackEnabled(trackPath, disabledTracks, enabledOverrides, disabledComposers)
	local normalizedTrack = musicTrackFilters.NormalizePath(trackPath)
	-- An explicit track inclusion is the highest-priority user choice and may
	-- intentionally bypass both its pack and any disabled credited composer.
	if enabledOverrides and enabledOverrides[normalizedTrack] then
		return true
	end
	if disabledTracks and disabledTracks[normalizedTrack] then
		return false
	end

	-- Composer exclusions combine as a union: a shared track remains off while
	-- any credited composer is disabled, regardless of other composer toggles.
	disabledComposers = disabledComposers or musicTrackFilters.GetDisabledComposers()
	if musicTrackFilters.IsTrackDisabledByComposer(normalizedTrack, disabledComposers) then
		return false
	end
	return musicTrackFilters.IsPackEnabled(musicTrackFilters.GetTrackPack(normalizedTrack))
end

function musicTrackFilters.FilterPlaylist(playlist, disabledTracks, enabledOverrides, disabledComposers)
	local filtered = {}
	disabledComposers = disabledComposers or musicTrackFilters.GetDisabledComposers()
	for i = 1, #playlist do
		if musicTrackFilters.IsTrackEnabled(playlist[i], disabledTracks, enabledOverrides, disabledComposers) then
			filtered[#filtered + 1] = playlist[i]
		end
	end
	return filtered
end

function musicTrackFilters.ClearPackEntries(set, pack)
	-- A pack toggle is authoritative and resets every per-track exception beneath it.
	for trackPath in pairs(set) do
		if musicTrackFilters.IsTrackInPack(trackPath, pack) then
			set[trackPath] = nil
		end
	end
end

return musicTrackFilters
