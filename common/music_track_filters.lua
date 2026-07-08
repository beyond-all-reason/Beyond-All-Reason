local musicTrackFilters = {}

musicTrackFilters.CONFIG_DISABLED_PACKS = "MusicDisabledPacks"
musicTrackFilters.CONFIG_DISABLED_TRACKS = "MusicDisabledTracks"

local separator = "|"

function musicTrackFilters.NormalizePath(path)
	path = string.gsub(path or "", "\\", "/")
	path = string.gsub(path, "/$", "")
	return string.lower(path)
end

function musicTrackFilters.GetPackPath(trackPath)
	return musicTrackFilters.NormalizePath(string.match(trackPath or "", "(.+)/[^/]+$") or "")
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

function musicTrackFilters.GetDisabledPacks()
	return musicTrackFilters.ParseSet(Spring.GetConfigString(musicTrackFilters.CONFIG_DISABLED_PACKS, ""))
end

function musicTrackFilters.GetDisabledTracks()
	return musicTrackFilters.ParseSet(Spring.GetConfigString(musicTrackFilters.CONFIG_DISABLED_TRACKS, ""))
end

function musicTrackFilters.IsTrackEnabled(trackPath, disabledPacks, disabledTracks)
	local normalizedTrack = musicTrackFilters.NormalizePath(trackPath)
	if disabledTracks and disabledTracks[normalizedTrack] then
		return false
	end

	local packPath = musicTrackFilters.GetPackPath(trackPath)
	if disabledPacks and disabledPacks[packPath] then
		return false
	end

	return true
end

function musicTrackFilters.FilterPlaylist(playlist, disabledPacks, disabledTracks)
	local filtered = {}
	for i = 1, #playlist do
		if musicTrackFilters.IsTrackEnabled(playlist[i], disabledPacks, disabledTracks) then
			filtered[#filtered + 1] = playlist[i]
		end
	end
	return filtered
end

return musicTrackFilters
