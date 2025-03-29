local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Keybind/Mouse Info",
		desc = "Provides information on the controls",
		author = "Bluestone",
		date = "April 2015",
		license = "GNU GPL, v2 or later, Mouthwash",
		layer = -99990,
		enabled = true,
	}
end

local keyConfig = VFS.Include("luaui/configs/keyboard_layouts.lua")
local currentLayout

local keybindsText
local lineType = {
	title = 1,
	blank = 2,
	key = 3,
}

local tabs = {"Keybindings", "Grid Keys", "Grid CTRL Keys", "Grid ALT Keys", "Legacy Keys", "Legacy CTRL Keys", "Legacy ALT Keys",}

local keybindsimages = {
	["Grid Keys"]        = "luaui/images/keybinds/grid_keys.png",
	['Grid CTRL Keys']   = "luaui/images/keybinds/grid_keys_CTRL.png",
	['Grid ALT Keys']    = "luaui/images/keybinds/grid_keys_ALT.png",
	['Legacy Keys']      = "luaui/images/keybinds/legacy_keys.png",
	['Legacy CTRL Keys'] = "luaui/images/keybinds/legacy_keys_CTRL.png",
	['Legacy ALT Keys']  = "luaui/images/keybinds/legacy_keys_ALT.png",
}

local tabrects = {}
local lasttab = "Keybindings"

local doUpdate
local actionHotkeys

local function getActionHotkey(action)
	local key = actionHotkeys[action]

	if not key then return "(none)" end

	return keyConfig.sanitizeKey(key, currentLayout):gsub("%+"," + ")
end

local vsx, vsy = Spring.GetViewGeometry()
local fontfile2 = "fonts/" .. Spring.GetConfigString("bar_font2", "Exo2-SemiBold.otf")

local screenHeightOrg = 550
local screenWidthOrg = 1050
local screenHeight = screenHeightOrg
local screenWidth = screenWidthOrg

local glCreateList = gl.CreateList
local glCallList = gl.CallList
local glDeleteList = gl.DeleteList

local RectRound, UiElement, elementCorner = WG.FlowUI.elementCorner

local showOnceMore = false

local keybindColor = "\255\235\185\070"
local titleColor = "\255\254\254\254"
local descriptionColor = "\255\192\190\180"

local widgetScale = (vsy / 1080)
local centerPosX = 0.5
local centerPosY = 0.5
local screenX = math.floor((vsx * centerPosX) - (screenWidth / 2))
local screenY = math.floor((vsy * centerPosY) + (screenHeight / 2))
local math_isInRect = math.isInRect

local font, font2, titleRect, keybinds, backgroundGuishader, show

local function drawTextTable(lines, x, y)
	local lineIndex = 0
	local height = 0
	local width = 0
	local fontSize = (screenHeight * 0.96) / math.ceil(#keybindsText / 3)
	font:Begin()
	for _, line in pairs(lines) do
		if line.type == lineType.blank then
			-- nothing here
		elseif line.type == lineType.title then
			-- title line
			local title = line.text
			local text = titleColor .. title
			font:Print(text, x + 4, y - ((fontSize * 0.92) * lineIndex) + 5, fontSize)
			screenWidth = math.max(font:GetTextWidth(text) * 13, screenWidth)
		elseif line.type == lineType.key then
			-- keybind line
			local bind = string.upper(line.key)
			local description = line.text
			local text = keybindColor .. bind .. "   " .. descriptionColor .. description
			font:Print(text, x + 14, y - (fontSize * 0.92) * lineIndex, fontSize * 0.8)
			width = math.max(font:GetTextWidth(text) * 11, width)
		end
		height = height + 13

		lineIndex = lineIndex + 1
		-- dont let the first line of a column be blank
		if lineIndex == 1 and line.blankLine then
			lineIndex = lineIndex - 1
		end
	end
	font:End()

	return x, lineIndex
end

local function drawWindow(activetab)
	local activetab = activetab or lasttab
	if activetab == nil then activetab = 'Keybindings' end

	-- background
	UiElement(screenX, screenY - screenHeight, screenX + screenWidth, screenY, 0, 1, 1, 1, 1,1,1,1, math.max(0.75, Spring.GetConfigFloat("ui_opacity", 0.7)))

	local titleFontSize = 18 * widgetScale

	local tabx = 0
	for i,tab in ipairs(tabs) do
		local tabwidth = font2:GetTextWidth(tab)
		tabrects[tab] = {
			math.floor(screenX + tabx),
			screenY,
			math.floor(screenX + tabx + tabwidth * titleFontSize + (titleFontSize*1.5)),
			math.floor(screenY + (titleFontSize*1.7)),
			tabx
		}
		tabx = tabx + (tabwidth  * titleFontSize +  (titleFontSize*1.5))
		gl.Color(0, 0, 0, math.max(0.75, Spring.GetConfigFloat("ui_opacity", 0.7)))
		RectRound(tabrects[tab][1], tabrects[tab][2], tabrects[tab][3], tabrects[tab][4], elementCorner, 1, 1, 0, 0)
	end

	-- title
	font2:Begin()
	font2:SetTextColor(1, 1, 1, 1)
	font2:SetOutlineColor(0, 0, 0, 0.4)
	for i,tab in ipairs(tabs) do
		local tabcolor = keybindColor
		if tab ~= activetab then
			tabcolor = titleColor
		end
		font2:Print(tabcolor .. tab, screenX + (titleFontSize * 0.75) + tabrects[tab][5], screenY + (8*widgetScale), titleFontSize, "on")
	end
	font2:End()


	if activetab ~= "Keybindings" and keybindsimages[activetab] then
		gl.Color(1,1,1,1)
		gl.Texture(0, ":l:"..keybindsimages[activetab])
		local zoom = 0.05
		gl.TexRect(screenX,screenY - screenHeight, screenX + screenWidth, screenY, 0 + 0.02, 1 - zoom, 1 - 0.02 , 0 + zoom)
		gl.Texture(0, false)
	else

		local entriesPerColumn = math.ceil(#keybindsText / 3)
		local entries1 = {}
		local entries2 = {}
		local entries3 = {}
		for k, line in pairs(keybindsText) do
			if k <= entriesPerColumn then
				entries1[#entries1 + 1] = line
			elseif k > entriesPerColumn and k <= entriesPerColumn * 2 then
				entries2[#entries2 + 1] = line
			else
				entries3[#entries3 + 1] = line
			end
		end
		local textPadding = 8 * widgetScale
		local textTopPadding = 28 * widgetScale
		local x = screenX + textPadding
		drawTextTable(entries1, x, screenY - textTopPadding)
		x = x + (350*widgetScale)
		drawTextTable(entries2, x, screenY - textTopPadding)
		x = x + (350*widgetScale)
		drawTextTable(entries3, x, screenY - textTopPadding)

		gl.Color(1, 1, 1, 1)
		font:Begin()
		font:Print(Spring.I18N('ui.keybinds.disclaimer'), screenX + (12*widgetScale), screenY - screenHeight + (34*widgetScale), 12.5*widgetScale)
		font:Print(Spring.I18N('ui.keybinds.howtochangekeybinds'), screenX + (12*widgetScale), screenY - screenHeight + (20*widgetScale), 12.5*widgetScale)
		font:End()
	end
end

local function refreshText()
	actionHotkeys = VFS.Include("luaui/Include/action_hotkeys.lua")
	currentLayout = Spring.GetConfigString("KeyboardLayout", "qwerty")

	keybindsText = {
		{ type = lineType.title, text = Spring.I18N('ui.keybinds.chat.title') },
		{ type = lineType.key, key = getActionHotkey('chat'),		text = Spring.I18N('ui.keybinds.chat.send')			},
		{ type = lineType.key, key = Spring.I18N('ui.keybinds.chat.alliesKey'),		text = Spring.I18N('ui.keybinds.chat.allies')		},
		{ type = lineType.key, key = Spring.I18N('ui.keybinds.chat.spectatorsKey'),	text = Spring.I18N('ui.keybinds.chat.spectators')	},
		{ type = lineType.key, key = Spring.I18N('ui.keybinds.chat.ignoreKey'),		text = Spring.I18N('ui.keybinds.chat.ignore')		},
		{ type = lineType.blank },
		{ type = lineType.title, text = Spring.I18N('ui.keybinds.menus.title') },
		{ type = lineType.key, key = getActionHotkey('options'),		text = Spring.I18N('ui.keybinds.menus.settings')	},
		{ type = lineType.key, key = getActionHotkey('sharedialog'),			text = Spring.I18N('ui.keybinds.menus.share')		},
		{ type = lineType.blank },
		{ type = lineType.title, text = Spring.I18N('ui.keybinds.camera.title') },
		{ type = lineType.key, key = Spring.I18N('ui.keybinds.camera.zoomKey'),	text = Spring.I18N('ui.keybinds.camera.zoom')	},
		{ type = lineType.key, key = Spring.I18N('ui.keybinds.camera.panKey'),	text = Spring.I18N('ui.keybinds.camera.pan')	},
		{ type = lineType.key, key = Spring.I18N('ui.keybinds.camera.tiltKey'),	text = Spring.I18N('ui.keybinds.camera.tilt')	},
		{ type = lineType.key, key = Spring.I18N('ui.keybinds.camera.dragKey'),	text = Spring.I18N('ui.keybinds.camera.drag')	},
		{ type = lineType.key, key = getActionHotkey('cameraflip'),	text = Spring.I18N('ui.keybinds.camera.flip')	},
		{ type = lineType.blank },
		{ type = lineType.title, text = Spring.I18N('ui.keybinds.cameraModes.title') },
		{ type = lineType.key, key = getActionHotkey('viewta') .. ', ' .. getActionHotkey('viewspring'),			text = Spring.I18N('ui.keybinds.cameraModes.change')		},
		{ type = lineType.key, key = Spring.I18N('ui.keybinds.cameraModes.fullscreenKey'),		text = Spring.I18N('ui.keybinds.cameraModes.fullscreen')	},
		{ type = lineType.key, key = getActionHotkey('toggleoverview'),		text = Spring.I18N('ui.keybinds.cameraModes.overview')		},
		{ type = lineType.key, key = getActionHotkey('togglelos'),				text = Spring.I18N('ui.keybinds.cameraModes.los')			},
		{ type = lineType.key, key = getActionHotkey('showelevation'),		text = Spring.I18N('ui.keybinds.cameraModes.heightmap')		},
		{ type = lineType.key, key = getActionHotkey('showpathtraversability'),	text = Spring.I18N('ui.keybinds.cameraModes.traversability')},
		{ type = lineType.key, key = getActionHotkey('lastmsgpos'),		text = Spring.I18N('ui.keybinds.cameraModes.mapmarks')		},
		{ type = lineType.key, key = getActionHotkey('showmetalmap'),	text = Spring.I18N('ui.keybinds.cameraModes.resourceSpots')	},
		{ type = lineType.key, key = getActionHotkey('hideinterface'),		text = Spring.I18N('ui.keybinds.cameraModes.interface')		},
		{ type = lineType.blank },
		{ type = lineType.title, text = Spring.I18N('ui.keybinds.sound.title') },
		{ type = lineType.key, key = Spring.I18N('ui.keybinds.sound.volumeKey'),	text = Spring.I18N('ui.keybinds.sound.volume')	},
		{ type = lineType.key, key = getActionHotkey('mutesound'),		text = Spring.I18N('ui.keybinds.sound.mute')	},
		{ type = lineType.blank },
		{ type = lineType.title, text = Spring.I18N('ui.keybinds.selection.title') },
		{ type = lineType.key, key = Spring.I18N('ui.keybinds.selection.unitsKey'), text = Spring.I18N('ui.keybinds.selection.units') },
		{ type = lineType.blank },
		{ type = lineType.title, text = Spring.I18N('ui.keybinds.issueContextOrders.title') },
		{ type = lineType.key, key = Spring.I18N('ui.keybinds.issueContextOrders.orderKey'),			text = Spring.I18N('ui.keybinds.issueContextOrders.order')			},
		{ type = lineType.key, key = Spring.I18N('ui.keybinds.issueContextOrders.formationOrderKey'),	text = Spring.I18N('ui.keybinds.issueContextOrders.formationOrder')	},
		{ type = lineType.blank },
		{ type = lineType.title, text = Spring.I18N('ui.keybinds.orders.title') },
		{ type = lineType.key, key = Spring.I18N('ui.keybinds.orders.defaultKey'),		text = Spring.I18N('ui.keybinds.orders.default')		},
		{ type = lineType.key, key = getActionHotkey('move'),			text = Spring.I18N('ui.keybinds.orders.move')			},
		{ type = lineType.key, key = getActionHotkey('attack'),		text = Spring.I18N('ui.keybinds.orders.attack')			},
		{ type = lineType.key, key = getActionHotkey('settarget'),	text = Spring.I18N('ui.keybinds.orders.setTarget')		},
		{ type = lineType.key, key = getActionHotkey('repair'),		text = Spring.I18N('ui.keybinds.orders.repair')			},
		{ type = lineType.key, key = getActionHotkey('reclaim'),		text = Spring.I18N('ui.keybinds.orders.reclaim')		},
		{ type = lineType.key, key = getActionHotkey('resurrect'),	text = Spring.I18N('ui.keybinds.orders.resurrect')		},
		{ type = lineType.key, key = getActionHotkey('fight'),		text = Spring.I18N('ui.keybinds.orders.fight')			},
		{ type = lineType.key, key = getActionHotkey('patrol'),		text = Spring.I18N('ui.keybinds.orders.patrol')			},
		{ type = lineType.key, key = getActionHotkey('wantcloak'),		text = Spring.I18N('ui.keybinds.orders.cloak')			},
		{ type = lineType.blank },
		{ type = lineType.key, key = getActionHotkey('stop'),			text = Spring.I18N('ui.keybinds.orders.stop')			},
		{ type = lineType.key, key = getActionHotkey('wait'),			text = Spring.I18N('ui.keybinds.orders.wait')			},
		{ type = lineType.key, key = getActionHotkey('canceltarget'),	text = Spring.I18N('ui.keybinds.orders.cancelTarget')	},
		{ type = lineType.blank },
		{ type = lineType.key, key = getActionHotkey('manualfire'),			text = Spring.I18N('ui.keybinds.orders.dGun')			},
		{ type = lineType.key, key = getActionHotkey('selfd'),	text = Spring.I18N('ui.keybinds.orders.selfDestruct')	},
		{ type = lineType.blank },
		{ type = lineType.title, text = Spring.I18N('ui.keybinds.issueOrders.title') },
		{ type = lineType.key, key = Spring.I18N('ui.keybinds.issueOrders.orderKey'),		text = Spring.I18N('ui.keybinds.issueOrders.order')		},
		{ type = lineType.key, key = Spring.I18N('ui.keybinds.issueOrders.revertKey'),		text = Spring.I18N('ui.keybinds.issueOrders.revert')	},
		{ type = lineType.key, key = Spring.I18N('ui.keybinds.issueOrders.formationKey'),	text = Spring.I18N('ui.keybinds.issueOrders.formation')	},
		{ type = lineType.blank },
		{ type = lineType.title, text = Spring.I18N('ui.keybinds.queues.title') },
		{ type = lineType.key, key = Spring.I18N('ui.keybinds.queues.appendKey'),	text = Spring.I18N('ui.keybinds.queues.append')	},
		{ type = lineType.key, key = Spring.I18N('ui.keybinds.queues.prependKey'),	text = Spring.I18N('ui.keybinds.queues.prepend')},
		{ type = lineType.blank },
		{ type = lineType.title, text = Spring.I18N('ui.keybinds.buildOrders.title') },
		{ type = lineType.key, key = Spring.I18N('ui.keybinds.buildOrders.selectTileKey'),	text = Spring.I18N('ui.keybinds.buildOrders.selectTile')},
		{ type = lineType.key, key = Spring.I18N('ui.keybinds.buildOrders.metalKey'),		text = Spring.I18N('ui.keybinds.buildOrders.metal')		},
		{ type = lineType.key, key = Spring.I18N('ui.keybinds.buildOrders.energyKey'),		text = Spring.I18N('ui.keybinds.buildOrders.energy')	},
		{ type = lineType.key, key = Spring.I18N('ui.keybinds.buildOrders.intelKey'),		text = Spring.I18N('ui.keybinds.buildOrders.intel')		},
		{ type = lineType.key, key = Spring.I18N('ui.keybinds.buildOrders.factoriesKey'),	text = Spring.I18N('ui.keybinds.buildOrders.factories')	},
		{ type = lineType.key, key = Spring.I18N('ui.keybinds.buildOrders.rotateKey'),		text = Spring.I18N('ui.keybinds.buildOrders.rotate')	},
		{ type = lineType.blank },
		{ type = lineType.title, text = Spring.I18N('ui.keybinds.issueBuildOrders.title') },
		{ type = lineType.key, key = Spring.I18N('ui.keybinds.issueBuildOrders.orderKey'),			text = Spring.I18N('ui.keybinds.issueBuildOrders.order')			},
		{ type = lineType.key, key = Spring.I18N('ui.keybinds.issueBuildOrders.deselect'),			text = Spring.I18N('ui.keybinds.issueBuildOrders.deselect')			},
		{ type = lineType.key, key = Spring.I18N('ui.keybinds.issueBuildOrders.lineKey'),			text = Spring.I18N('ui.keybinds.issueBuildOrders.line')				},
		{ type = lineType.key, key = Spring.I18N('ui.keybinds.issueBuildOrders.gridKey'),			text = Spring.I18N('ui.keybinds.issueBuildOrders.grid')				},
		{ type = lineType.key, key = Spring.I18N('ui.keybinds.issueBuildOrders.spacingUpKey'),		text = Spring.I18N('ui.keybinds.issueBuildOrders.spacingUp')		},
		{ type = lineType.key, key = Spring.I18N('ui.keybinds.issueBuildOrders.spacingDownKey'),		text = Spring.I18N('ui.keybinds.issueBuildOrders.spacingDown')	},
		{ type = lineType.blank },
		{ type = lineType.title, text = Spring.I18N('ui.keybinds.massSelect.title') },
		{ type = lineType.key, key = Spring.I18N('ui.keybinds.massSelect.allKey'),			text = Spring.I18N('ui.keybinds.massSelect.all')		},
		{ type = lineType.key, key = Spring.I18N('ui.keybinds.massSelect.buildersKey'),		text = Spring.I18N('ui.keybinds.massSelect.builders')	},
		{ type = lineType.key, key = Spring.I18N('ui.keybinds.massSelect.createGroupKey'),	text = Spring.I18N('ui.keybinds.massSelect.createGroup')},
		{ type = lineType.key, key = Spring.I18N('ui.keybinds.massSelect.createAutoGroupKey'),	text = Spring.I18N('ui.keybinds.massSelect.createAutoGroup')},
		{ type = lineType.key, key = getActionHotkey('remove_from_autogroup'),	text = Spring.I18N('ui.keybinds.massSelect.removeAutoGroup')},
		{ type = lineType.key, key = Spring.I18N('ui.keybinds.massSelect.groupKey'),		text = Spring.I18N('ui.keybinds.massSelect.group')		},
		{ type = lineType.key, key = Spring.I18N('ui.keybinds.massSelect.sameTypeKey'),		text = Spring.I18N('ui.keybinds.massSelect.sameType')	},
		{ type = lineType.blank },
		{ type = lineType.title, text = Spring.I18N('ui.keybinds.drawing.title') },
		{ type = lineType.key, key = Spring.I18N('ui.keybinds.drawing.mapmarkKey'),	text = Spring.I18N('ui.keybinds.drawing.mapmark')	},
		{ type = lineType.key, key = Spring.I18N('ui.keybinds.drawing.drawKey'),		text = Spring.I18N('ui.keybinds.drawing.draw')		},
		{ type = lineType.key, key = Spring.I18N('ui.keybinds.drawing.eraseKey'),		text = Spring.I18N('ui.keybinds.drawing.erase')		},
		{ type = lineType.blank },
		{ type = lineType.title, text = Spring.I18N('ui.keybinds.console.title') },
		{ type = lineType.key, key = Spring.I18N('ui.keybinds.console.eraseKey'),	text = Spring.I18N('ui.keybinds.console.erase')	},
		{ type = lineType.key, key = Spring.I18N('ui.keybinds.console.pauseKey'),	text = Spring.I18N('ui.keybinds.console.pause')	},
	}
end

function widget:ViewResize()
	vsx, vsy = Spring.GetViewGeometry()
	widgetScale = (vsy / 1080)

	screenHeight = math.floor(screenHeightOrg * widgetScale)
	screenWidth = math.floor(screenWidthOrg * widgetScale)
	screenX = math.floor((vsx * centerPosX) - (screenWidth / 2))
	screenY = math.floor((vsy * centerPosY) + (screenHeight / 2))

	font = WG['fonts'].getFont()
	font2 = WG['fonts'].getFont(fontfile2)
	elementCorner = WG.FlowUI.elementCorner

	RectRound = WG.FlowUI.Draw.RectRound
	UiElement = WG.FlowUI.Draw.Element

	if keybinds then
		gl.DeleteList(keybinds)
	end
	keybinds = gl.CreateList(drawWindow)
end



function widget:DrawScreen()

	-- draw the help
	if doUpdate then
		if keybinds then
			gl.DeleteList(keybinds)
		end
		keybinds = gl.CreateList(drawWindow)

		doUpdate = false
	end

	if not keybinds then
		keybinds = glCreateList(drawWindow)
	end

	doUpdate = false

	if show or showOnceMore then
		gl.Texture(false)	-- some other widget left it on
		glCallList(keybinds)
		if WG['guishader'] then
			if backgroundGuishader ~= nil then
				glDeleteList(backgroundGuishader)
			end
			backgroundGuishader = glCreateList(function()
				-- background
				RectRound(screenX, screenY - screenHeight, screenX + screenWidth, screenY, elementCorner, 0, 1, 1, 1)
				-- title
				for k, tabrect in pairs(tabrects) do
					RectRound(tabrect[1], tabrect[2], tabrect[3], tabrect[4], elementCorner, 1, 1, 0, 0)
				end
			end)
			WG['guishader'].InsertDlist(backgroundGuishader, 'keybindinfo')
		end
		showOnceMore = false

		local x, y, pressed = Spring.GetMouseState()
		if math_isInRect(x, y, screenX, screenY - screenHeight, screenX + screenWidth, screenY)  then
			Spring.SetMouseCursor('cursornormal')
		end
	else
		if WG['guishader'] then
			WG['guishader'].DeleteDlist('keybindinfo')
		end
	end
end

function widget:KeyPress(key)
	if key == 27 then
		-- ESC
		show = false
	end
end

local function mouseEvent(x, y, button, release)
	if Spring.IsGUIHidden() then
		return false
	end

	if show then
		-- on window
		if math_isInRect(x, y, screenX, screenY - screenHeight, screenX + screenWidth, screenY) then
			return true
		else
			for tab, tabrect in pairs(tabrects) do
				if math_isInRect(x, y, tabrect[1], tabrect[2], tabrect[3], tabrect[4]) then
					if keybinds then
						gl.DeleteList(keybinds)
					end
					lasstab = tab
					keybinds = gl.CreateList(drawWindow, tab)
					return true
				end
			end
			if release or not release then
				showOnceMore = show        -- show once more because the guishader lags behind, though this will not fully fix it
				show = false
			end
		end
	end
end

function widget:MousePress(x, y, button)
	return mouseEvent(x, y, button, false)
end

function widget:MouseRelease(x, y, button)
	return mouseEvent(x, y, button, true)
end

function widget:Initialize()
	refreshText()

	WG['keybinds'] = {}
	WG['keybinds'].toggle = function(state)
		if state ~= nil then
			show = state
		else
			show = not show
		end
	end
	WG['keybinds'].isvisible = function()
		return show
	end
	WG['keybinds'].reloadBindings = function()
		refreshText()
		doUpdate = true
	end
	widget:ViewResize()
end

function widget:Shutdown()
	if keybinds then
		glDeleteList(keybinds)
		keybinds = nil
	end
	if WG['guishader'] then
		WG['guishader'].DeleteDlist('keybindinfo')
	end
end

function widget:LanguageChanged()
	refreshText()
	doUpdate = true
	widget:ViewResize()
end
