if not RmlUi then
	return false
end
-- todo: disable widget if we are not playing a mission

-- Usage example in other widgets / mission api:   WG['mission_dialogue'].SendDialogue("Some Dude","Hello World!", "somedude.png", "left", "dialogue1.wav")
-- somedude.png must be in "/luaui/images/character_portraits/" and dialogue1.wav must be in "/luaui/sounds/mission_dialogue/".

function widget:GetInfo()
	return {
		name      = "Mission Dialogue",
		desc      = "Draws dialogue popups with character portraits",
		author    = "RebelNode",
		date      = "2025",
		license   = "https://unlicense.org/",
		layer     = 1,
		handler   = true,
		enabled   = true
	}
end
local dm_handle
local messagebuffer
local popup_timer = 0
local spPlaySoundFile = Spring.PlaySoundFile

function SendDialogue(character_name, message, character_portrait, side, soundfile)
	dm_handle.character_name = character_name
	dm_handle.message = message

	character_portrait_element:SetAttribute("src", "/luaui/images/character_portraits/" .. character_portrait)
	
	-- For whatever reason using `character_portrait_element.style.marginleft = "auto"` doesn't work so we use SetAttribute instead
	if side == "left" then
		character_portrait_element:SetAttribute("style", "display: block; margin-left: 0px;")
	end
	if side == "right" then
		character_portrait_element:SetAttribute("style", "display: block; margin-left: auto;")
	end

	document:Show()
	popup_timer = 0

	if soundfile then
		spPlaySoundFile("luaui/sounds/mission_dialogue/" .. soundfile, 10, nil, "sfx")
	end
	
	-- todo: message buffering: print 1 letter at a time

end

function widget:Initialize()
	widget.rmlContext = RmlUi.CreateContext(widget.whInfo.name)

	-- use the DataModel handle to set values
	-- only keys declared at the DataModel's creation can be used
	dm_handle = widget.rmlContext:OpenDataModel("data_model_test", {
		character_name = "Some dude",
		message = "Hello world!"
	});
	document = widget.rmlContext:LoadDocument("LuaUi/Widgets/rml_widget_assets/gui_dialogue.rml", widget)
	document:ReloadStyleSheet()

	character_portrait_element = document:GetElementById("character_portrait")

	WG['mission_dialogue'] = {}
	WG['mission_dialogue'].SendDialogue = SendDialogue

end

function widget:Update(dt)

	--hide dialogue popup after a while
	popup_timer = popup_timer + dt
	if popup_timer > 5 then
		document:Hide()
		popup_timer = 0
	end
end

function widget:Shutdown()
	if document then
		document:Close()
	end
	if widget.rmlContext then
		RmlUi.RemoveContext(widget.whInfo.name)
	end
end
