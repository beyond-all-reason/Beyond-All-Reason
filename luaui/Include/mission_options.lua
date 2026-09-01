-- Mission options: the `missionoptions` modoption, decoded and reduced to the questions
-- widgets actually ask of it.
--
-- Format is base64url(zlib(json)); see modoptions.lua. Spring.GetModOptions() lowercases
-- the outer modoption key, but the keys inside the payload keep their original casing.
--
-- Decoding costs a zlib inflate plus a json parse, and these do it on every call. The
-- modoption cannot change during a game, so call once at widget file scope or in
-- Initialize and keep the boolean; never per frame.

local ModoptionPayload = VFS.Include("common/luaUtilities/modoption_payload.lua")

local missionOptions = {}

local function getOptions()
	return ModoptionPayload.Decode(Spring.GetModOptions().missionoptions)
end

--- Whether the mission places the starting units itself, leaving no commander to pick a
--- start position for or to queue pregame builds against.
---@return boolean
function missionOptions.IsInitialCommanderSpawnDisabled()
	local options = getOptions()
	if not options then
		return false
	end

	if options.disableInitialCommanderSpawn then
		return true
	end

	return not table.isNilOrEmpty(options.unitloadout)
end

--- Whether the mission fixes the player's faction instead of letting them choose one.
---@return boolean
function missionOptions.IsFactionPickerDisabled()
	local options = getOptions()

	return options ~= nil and options.disableFactionPicker == true
end

return missionOptions
