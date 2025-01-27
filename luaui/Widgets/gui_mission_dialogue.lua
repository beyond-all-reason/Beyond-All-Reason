-- todo: disable widget if we are not playing a mission

-- Usage example in other widgets / mission api:   WG['mission_dialogue'].SendDialogue("Some Dude","Hello World!", "somedude.png", "left", "dialogue1.wav", 5)
-- somedude.png must be in "/luaui/images/character_portraits/" and dialogue1.wav must be in "/luaui/sounds/mission_dialogue/".

function widget:GetInfo()
	return {
		name      = "Mission Dialogue",
		desc      = "Draws dialogue popups with character portraits",
		author    = "RebelNode",
		date      = "2025",
		license   = "GNU GPL, v2 or later",
		layer     = 1,
		handler   = true,
		enabled   = true
	}
end
local datamodelHandle
local popupTimer = 0
local popupTimeout = 5
local spPlaySoundFile = Spring.PlaySoundFile

local function SendDialogue(characterName, message, characterPortrait, side, soundfile, popupTimeoutIn)
	datamodelHandle.characterName = characterName
	datamodelHandle.message = message
	
	if popupTimeoutIn then
		popupTimeout = popupTimeoutIn
	else
		popupTimeout = 5
	end

	characterPortraitElement:SetAttribute("src", "/luaui/images/character_portraits/" .. characterPortrait)
	
	-- For whatever reason using `characterPortraitElement.style.marginleft = "auto"` doesn't work so we use SetAttribute instead
	if side == "left" then
		characterPortraitElement:SetAttribute("style", "display: block; margin-left: 0px;")
	end
	if side == "right" then
		characterPortraitElement:SetAttribute("style", "display: block; margin-left: auto;")
	end

	document:Show()
	popupTimer = 0

	if soundfile then
		spPlaySoundFile("luaui/sounds/mission_dialogue/" .. soundfile, 10, nil, "sfx")
	end
end

function widget:Initialize()
	widget.rmlContext = RmlUi.CreateContext(widget.whInfo.name)

	-- only keys declared at the DataModel's creation can be used
	datamodelHandle = widget.rmlContext:OpenDataModel("mission_dialogue", {
		characterName = "Some dude",
		message = "Hello world!"
	});
	document = widget.rmlContext:LoadDocument("LuaUi/Widgets/rml/gui_dialogue.rml", widget)
	document:ReloadStyleSheet()

	characterPortraitElement = document:GetElementById("characterPortrait")

	WG['mission_dialogue'] = {}
	WG['mission_dialogue'].SendDialogue = SendDialogue

end

function widget:Update(dt)

	--hide dialogue popup after a while
	popupTimer = popupTimer + dt
	if popupTimer > popupTimeout then
		document:Hide()
		popupTimer = 0
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
