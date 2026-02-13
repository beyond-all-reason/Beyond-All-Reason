local stateHotkeyHints = VFS.Include("luaui/Include/state_hotkey_hints.lua")

local function sanitizeHotkey(rawHotkey)
	return rawHotkey:gsub("sc_", "")
end

function test_builds_and_sorts_state_hotkeys_by_tap_count()
	local actionHotkeys = {
		firestate_0 = "sc_l,sc_l",
		firestate_1 = "sc_l,sc_l,sc_l",
		firestate_2 = "sc_l",
	}
	local stateLabels = {
		[0] = "Hold fire",
		[1] = "Fire at will",
		[2] = "Return fire",
	}

	local hints = stateHotkeyHints.buildStateHotkeyHints(
		actionHotkeys,
		"firestate",
		3,
		sanitizeHotkey,
		function(stateValue)
			return stateLabels[stateValue]
		end
	)

	assert(#hints == 3, "expected 3 hotkey hints")
	assert(hints[1].hotkey == "l", "single tap hotkey should be first")
	assert(hints[1].stateLabel == "Return fire", "single tap state label mismatch")
	assert(hints[1].taps == 1, "single tap count mismatch")
	assert(hints[2].hotkey == "l,l", "double tap hotkey should be second")
	assert(hints[2].taps == 2, "double tap count mismatch")
	assert(hints[3].hotkey == "l,l,l", "triple tap hotkey should be third")
	assert(hints[3].taps == 3, "triple tap count mismatch")
end

function test_formats_state_hotkeys_with_labels()
	local hints = {
		{ hotkey = "l", stateLabel = "Return fire", taps = 1 },
		{ hotkey = "l,l", stateLabel = "Hold fire", taps = 2 },
	}

	local text = stateHotkeyHints.formatStateHotkeyHints(hints, "<H>", "<T>")

	assert(text:find("<H>L<T> = Return fire", 1, true) ~= nil, "formatted output missing first line")
	assert(text:find("<H>L,L<T> = Hold fire", 1, true) ~= nil, "formatted output missing second line")
end

function test()
	test_builds_and_sorts_state_hotkeys_by_tap_count()
	test_formats_state_hotkeys_with_labels()
end
