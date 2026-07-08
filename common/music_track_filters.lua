local musicTrackFilters = {}

-- Shared engine config so LuaUI, LuaIntro, and other music consumers use one source of truth.
-- Values are normalized track paths serialized as a pipe-delimited set.
musicTrackFilters.CONFIG_DISABLED_TRACKS = "MusicDisabledTracks"
musicTrackFilters.CONFIG_ENABLED_OVERRIDES = "MusicEnabledTrackOverrides"

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
		return Spring.Utilities.Gametype.IsRaptors() or Spring.GetConfigInt('UseSoundtrackRaptors', 0) == 1
	elseif pack == "scavengers" then
		return Spring.Utilities.Gametype.IsScavengers() or Spring.GetConfigInt('UseSoundtrackScavengers', 0) == 1
	end

	if pack == "aprilfools" then
		return Spring.GetConfigInt('UseSoundtrackAprilFools', 1) == 1
			or Spring.GetConfigInt('UseSoundtrackAprilFoolsPostEvent', 0) == 1
	elseif pack == "halloween" then
		return Spring.GetConfigInt('UseSoundtrackHalloween', 1) == 1
			or Spring.GetConfigInt('UseSoundtrackHalloweenPostEvent', 0) == 1
	elseif pack == "xmas" then
		return Spring.GetConfigInt('UseSoundtrackXmas', 1) == 1
			or Spring.GetConfigInt('UseSoundtrackXmasPostEvent', 0) == 1
	end

	return true
end

function musicTrackFilters.IsTrackEnabled(trackPath, disabledTracks, enabledOverrides)
	local normalizedTrack = musicTrackFilters.NormalizePath(trackPath)
	if disabledTracks and disabledTracks[normalizedTrack] then
		return false
	end
	if enabledOverrides and enabledOverrides[normalizedTrack] then
		return true
	end

	return musicTrackFilters.IsPackEnabled(musicTrackFilters.GetTrackPack(normalizedTrack))
end

function musicTrackFilters.FilterPlaylist(playlist, disabledTracks, enabledOverrides)
	local filtered = {}
	for i = 1, #playlist do
		if musicTrackFilters.IsTrackEnabled(playlist[i], disabledTracks, enabledOverrides) then
			filtered[#filtered + 1] = playlist[i]
		end
	end
	return filtered
end

function musicTrackFilters.ClearPackEntries(set, pack)
	for trackPath in pairs(set) do
		if musicTrackFilters.IsTrackInPack(trackPath, pack) then
			set[trackPath] = nil
		end
	end
end

return musicTrackFilters
