-- The regular (FlowUI) look of the Picture-in-Picture's interface: frame, buttons, rewind timeline and the
-- tracked player's overlay around the map. What's in it comes from pip_interface.lua. Another look is a table
-- of the same functions, made by a factory(ui) given to WG["pipN"].setView:
--   DrawFrame(w, h)  behind the map (reads and clears pipR2T.frameNeedsUpdate)
--   DrawMapMask(stripH)  the map's shape, runs inside gl.CreateList
--   DrawTrackingBorder()  DrawControls(mx, my, lmb)  DrawTimeline(lay, mx, my)  over the map
--   DrawTrackedName()  DrawTrackedResources()
--   DrawMinimized(mx, my)  instead of all of those while minimized
--   UpdateBlur()  RemoveBlur()
--   HitResize(mx, my)  HitMinimize(mx, my)  ButtonIndexAt(mx, my)  what the mouse is on (over the map)
--   HitResizeOutside(mx, my)  a resize grab past the map: on the frame or the timeline
--   ReleaseFrame()  ReleaseText()  Release()  drop GL objects: frame, text, everything and the blur

local M = {}

---@param ui table the window's interface (pip_interface.lua)
---@return table view
function M.new(ui)
	local view = {}
	local render, config, uiState = ui.render, ui.config, ui.uiState
	local interactionState, miscState, pools = ui.interactionState, ui.miscState, ui.pools
	local pipR2T, glFunc, glConst = ui.pipR2T, ui.glFunc, ui.glConst
	local spFunc, pipNumber, isMinimapMode = ui.spFunc, ui.pipNumber, ui.isMinimapMode

	local function ResizeHandleVertices()
		glFunc.Vertex(render.dim.r, render.dim.b)
		glFunc.Vertex(render.dim.r - render.usedButtonSize, render.dim.b)
		glFunc.Vertex(render.dim.r, render.dim.b + render.usedButtonSize)
	end

	-- Helper function to compute chamfered corner params based on screen bounds
	-- Returns tl, tr, br, bl (TopLeft, TopRight, BottomRight, BottomLeft)
	-- Corners are disabled (0) when the element touches or exceeds screen bounds
	local function GetChamferedCorners(l, b, r, t)
		local atLeft = l <= 0
		local atBottom = b <= 0
		local atRight = r >= render.vsx
		local atTop = t >= render.vsy

		-- tl (TopLeft) - disabled if at left or top edge
		local tl = (atLeft or atTop) and 0 or 1
		-- tr (TopRight) - disabled if at right or top edge
		local tr = (atRight or atTop) and 0 or 1
		-- br (BottomRight) - disabled if at right or bottom edge
		local br = (atRight or atBottom) and 0 or 1
		-- bl (BottomLeft) - disabled if at left or bottom edge
		local bl = (atLeft or atBottom) and 0 or 1

		return tl, tr, br, bl
	end

	function view.RemoveBlur()
		if WG.guishader then
			if WG.guishader.RemoveDlist then
				WG.guishader.RemoveDlist("pip" .. pipNumber)
			elseif WG.guishader.RemoveRect then
				WG.guishader.RemoveRect("pip" .. pipNumber)
			end
		end
	end

	function view.UpdateBlur()
		if WG.guishader and miscState.externalFrame.active then
			-- the frame blurs behind itself
			view.RemoveBlur()
		elseif WG.guishader then
			-- Determine the correct bounds based on mode
			local blurL, blurB, blurR, blurT
			if isMinimapMode and miscState.minimapMinimized then
				-- Minimap minimized: blur behind the maximize button
				local buttonSize = math.floor(render.usedButtonSize * config.maximizeSizemult)
				blurL = render.dim.l - render.elementPadding
				blurB = render.dim.t - buttonSize - render.elementPadding
				blurR = render.dim.l + buttonSize + render.elementPadding
				blurT = render.dim.t + render.elementPadding
			elseif uiState.inMinMode and not uiState.isAnimating then
				-- Use minimized button position
				local buttonSize = math.floor(render.usedButtonSize * config.maximizeSizemult)
				blurL = uiState.minModeL - render.elementPadding
				blurB = uiState.minModeB - render.elementPadding
				blurR = uiState.minModeL + buttonSize + render.elementPadding
				blurT = uiState.minModeB + buttonSize + render.elementPadding
			else
				-- Use regular PIP dimensions
				blurL = render.dim.l - render.elementPadding
				blurB = render.dim.b - miscState.hist.StripH() - render.elementPadding
				blurR = render.dim.r + render.elementPadding
				blurT = render.dim.t + render.elementPadding
			end

			-- Use InsertDlist for rounded corner blur support
			if WG.guishader.InsertDlist then
				-- Clean up old dlist ourselves before creating new one
				if render.guishaderDlist then
					gl.DeleteList(render.guishaderDlist)
					render.guishaderDlist = nil
				end
				-- Create new dlist with rounded rectangle
				render.guishaderDlist = gl.CreateList(function()
					render.RectRound(blurL, blurB, blurR, blurT, render.elementCorner)
				end)
				-- Use force=true to ensure immediate stencil texture update
				WG.guishader.InsertDlist(render.guishaderDlist, "pip" .. pipNumber, true)
			elseif WG.guishader.InsertRect then
				-- Fallback to InsertRect if InsertDlist not available
				WG.guishader.InsertRect(blurL, blurB, blurR, blurT, "pip" .. pipNumber)
			end
		end
	end

	function view.DrawTimeline(lay, mx, my)
		local hist = miscState.hist
		local hover = ui.TimelineHover(lay, mx, my)
		local dark, light = config.panelBorderColorDark, config.panelBorderColorLight
		local accent = hist.mode and { 1, 0.72, 0.28, 1 } or light

		glFunc.Texture(false)
		glFunc.Color(dark)
		-- the strip is the panel's bottom edge: cut its bottom corners like the content mask does
		local edge = 2
		local atBottom = lay.b <= edge
		local br = (lay.r >= render.vsx - edge or atBottom) and 0 or 1
		local bl = (lay.l <= edge or atBottom) and 0 or 1
		render.RectRound(lay.l, lay.b, lay.r, lay.t, render.elementCorner * 0.5, 0, 0, br, bl)
		if lay.empty then
			-- nothing recorded yet: an empty track
			glFunc.Color(0, 0, 0, 0.55)
			gl.Rect(lay.trackL, lay.cy - lay.trackH * 0.5, lay.trackR, lay.cy + lay.trackH * 0.5)
			glFunc.Color(1, 1, 1, 1)
			return
		end

		-- play / pause and skip-to-live: active while rewinding, a faint hint at live
		local ib = lay.ib
		local px, cy = lay.playL, lay.cy
		local hoverLive = hover.live
		if hist.mode then
			glFunc.Color(accent)
		else
			glFunc.Color(light[1], light[2], light[3], 0.18)
		end
		if hist.mode and hist.playing then
			local w = ib * 0.22
			gl.Rect(px + ib * 0.2, cy - ib * 0.32, px + ib * 0.2 + w, cy + ib * 0.32)
			gl.Rect(px + ib * 0.8 - w, cy - ib * 0.32, px + ib * 0.8, cy + ib * 0.32)
		else
			glFunc.BeginEnd(GL.TRIANGLES, function()
				glFunc.Vertex(px + ib * 0.25, cy - ib * 0.34)
				glFunc.Vertex(px + ib * 0.25, cy + ib * 0.34)
				glFunc.Vertex(px + ib * 0.82, cy)
			end)
		end
		-- skip-to-live glyph: a triangle against an end bar
		local lx = lay.liveL
		if hist.mode then
			glFunc.Color(light[1], light[2], light[3], hoverLive and 1 or 0.85)
		else
			glFunc.Color(light[1], light[2], light[3], 0.18)
		end
		local gh = math.floor(ib * 0.34)
		local bw = math.max(2, math.floor(ib * 0.12))
		glFunc.BeginEnd(GL.TRIANGLES, function()
			glFunc.Vertex(lx + ib * 0.18, cy - gh)
			glFunc.Vertex(lx + ib * 0.18, cy + gh)
			glFunc.Vertex(lx + ib * 0.66, cy)
		end)
		gl.Rect(lx + ib * 0.7, cy - gh, lx + ib * 0.7 + bw, cy + gh)
		local fontSize = lay.fontSize
		ui.font:Begin()
		ui.font:SetOutlineColor(0, 0, 0, 0.6)
		local labelY = math.floor(cy - fontSize * 0.36)
		-- playback speed (left click faster, right click slower)
		local hoverSpeed = hover.speed
		if hist.mode then
			ui.font:SetTextColor(accent[1], accent[2], accent[3], hoverSpeed and 1 or 0.85)
		else
			ui.font:SetTextColor(light[1], light[2], light[3], hoverSpeed and 0.9 or 0.5)
		end
		local speedText = ((hist.direction or 1) < 0 and hist.mode) and ("-x" .. hist.speed) or ("x" .. hist.speed)
		ui.font:Print(speedText, math.floor((lay.speedL + lay.speedR) * 0.5), labelY, fontSize, "oc")
		ui.font:End()

		-- track
		local th = lay.trackH
		local trackB, trackT = cy - th * 0.5, cy + th * 0.5
		glFunc.Color(0, 0, 0, 0.55)
		gl.Rect(lay.trackL, trackB, lay.trackR, trackT)
		local viewFrame = hist.mode and hist.viewFrame or lay.live
		local tView = (viewFrame - lay.first) / math.max(1, lay.live - lay.first)
		tView = math.max(0, math.min(1, tView))
		local knobX = math.floor(lay.trackL + (lay.trackR - lay.trackL) * tView + 0.5)
		glFunc.Color(accent[1], accent[2], accent[3], hist.mode and 0.85 or 0.35)
		gl.Rect(lay.trackL, trackB, knobX, trackT)
		-- spilled ranges: coarse copy only (dark), loading (pulsing), detailed (nothing)
		local ranges = hist.store:SegmentRanges()
		if #ranges > 0 then
			local span = math.max(1, lay.live - lay.first)
			local trackW = lay.trackR - lay.trackL
			local pulse = 0.25 + 0.2 * math.sin(os.clock() * 6)
			for i = 1, #ranges do
				local r = ranges[i]
				if not r.loaded then
					local x0 = lay.trackL + trackW * math.max(0, (r.first - lay.first) / span)
					local x1 = lay.trackL + trackW * math.min(1, (r.last - lay.first) / span)
					if r.loading then
						glFunc.Color(1, 1, 1, pulse)
					else
						glFunc.Color(0, 0, 0, 0.45)
					end
					gl.Rect(x0, trackB, x1, trackT)
				end
			end
		end
		local kw = math.max(2, math.floor(ib * 0.08) * 2)
		local kh = math.floor(ib * 0.36)
		glFunc.Color(accent[1], accent[2], accent[3], 1)
		gl.Rect(knobX - kw * 0.5, cy - kh, knobX + kw * 0.5, cy + kh)

		-- hover preview marker on the track
		local hoverTrack = hover.track
		local labelFrame = viewFrame
		if hoverTrack and not hist.dragging then
			local hf = hist.FrameAt(mx)
			glFunc.Color(1, 1, 1, 0.5)
			local hh = math.floor(ib * 0.3)
			gl.Rect(math.floor(mx) - 1, cy - hh, math.floor(mx) + 1, cy + hh)
			labelFrame = hf
		end

		-- viewed (or hovered) time left of the track, live time right of it
		ui.font:Begin()
		ui.font:SetOutlineColor(0, 0, 0, 0.7)
		local textY = math.floor(cy - fontSize * 0.36)
		if hist.mode or hoverTrack then
			ui.font:SetTextColor(accent[1], accent[2], accent[3], 1)
			ui.font:Print(hist.FormatFrame(labelFrame), lay.timeX, textY, fontSize, "oc")
		end
		ui.font:SetTextColor(0.8, 0.8, 0.8, 0.8)
		ui.font:Print(hist.FormatFrame(lay.live), lay.liveX, textY, fontSize, "oc")
		ui.font:End()

		if hover.tooltipKey then
			ui.ShowTooltip(BAR.I18N(hover.tooltipKey))
		end
		glFunc.Color(1, 1, 1, 1)
	end

	-- Helper function to render PIP frame buttons without hover effects
	local function RenderFrameButtons()
		-- In minimap mode, don't render buttons at all (no minimize, no resize handle)
		if isMinimapMode and config.minimapModeShowButtons == false then
			return
		end

		local usedButtonSizeLocal = render.usedButtonSize
		local pipWidth = render.dim.r - render.dim.l
		local pipHeight = render.dim.t - render.dim.b

		-- Skip all rendering if showButtonsOnHoverOnly is enabled and mouse is not over PIP
		if config.showButtonsOnHoverOnly and not interactionState.isMouseOverPip then
			return
		end

		-- Resize handle (bottom-right corner) - hide in minimap mode if configured
		if not (isMinimapMode and config.minimapModeHideMoveResize) then
			glFunc.Color(config.panelBorderColorDark)
			glFunc.LineWidth(1.0)
			glFunc.BeginEnd(glConst.TRIANGLES, function()
				-- Relative coordinates for resize handle
				glFunc.Vertex(pipWidth - usedButtonSizeLocal, 0)
				glFunc.Vertex(pipWidth, 0)
				glFunc.Vertex(pipWidth, usedButtonSizeLocal)
			end)
		end

		-- Minimize button (top-right) - hide in minimap mode
		if not isMinimapMode then
			glFunc.Color(config.panelBorderColorDark)
			glFunc.Texture(false)
			render.RectRound(
				pipWidth - usedButtonSizeLocal - render.elementPadding,
				pipHeight - usedButtonSizeLocal - render.elementPadding,
				pipWidth,
				pipHeight,
				render.elementCorner * 0.65,
				0,
				0,
				0,
				1
			)
			glFunc.Color(config.panelBorderColorLight)
			glFunc.Texture("LuaUI/Images/pip/PipShrink.png")

			-- Rotate icon to point toward shrink position (opposite of expand direction)
			local rotation = ui.MaximizeIconRotation()
			local centerX = pipWidth - usedButtonSizeLocal * 0.5
			local centerY = pipHeight - usedButtonSizeLocal * 0.5
			glFunc.PushMatrix()
			glFunc.Translate(centerX, centerY, 0)
			glFunc.Rotate(rotation, 0, 0, 1)
			glFunc.Translate(-centerX, -centerY, 0)

			glFunc.TexRect(pipWidth - usedButtonSizeLocal, pipHeight - usedButtonSizeLocal, pipWidth, pipHeight)
			glFunc.PopMatrix()
			glFunc.Texture(false)
		end

		-- Bottom-left buttons
		local visibleButtons = ui.ComputeVisibleButtons(pools.visibleButtons)

		local buttonCount = #visibleButtons
		glFunc.Color(config.panelBorderColorDark)
		glFunc.Texture(false)
		render.RectRound(
			0,
			0,
			(buttonCount * usedButtonSizeLocal) + math.floor(render.elementPadding * 0.75),
			usedButtonSizeLocal + math.floor(render.elementPadding * 0.75),
			render.elementCorner * 0.65,
			0,
			1,
			0,
			0
		)

		local bx = 0
		for i = 1, buttonCount do
			local isActive = ui.IsButtonActive(visibleButtons[i])

			if isActive then
				glFunc.Color(config.panelBorderColorLight)
				glFunc.Texture(false)
				render.RectRound(
					bx,
					0,
					bx + usedButtonSizeLocal,
					usedButtonSizeLocal,
					render.elementCorner * 0.4,
					1,
					1,
					1,
					1
				)
				glFunc.Color(config.panelBorderColorDark)
			else
				glFunc.Color(config.panelBorderColorLight)
			end
			glFunc.Texture(visibleButtons[i].texture)
			glFunc.TexRect(bx, 0, bx + usedButtonSizeLocal, usedButtonSizeLocal)
			bx = bx + usedButtonSizeLocal
		end
		glFunc.Texture(false)
	end

	-- Helper function to draw tracked player name (uses cached display list)
	function view.DrawTrackedName()
		local playerName, teamID = ui.TrackedPlayerName()
		if not playerName then
			return
		end

		-- Check if we need to regenerate the display list (player changed or name changed)
		local needsUpdate = pipR2T.playerNameDlist == nil
			or pipR2T.playerNameLastPlayerID ~= interactionState.trackingPlayerID
			or pipR2T.playerNameLastName ~= playerName

		if needsUpdate then
			-- Clean up old display list
			if pipR2T.playerNameDlist then
				gl.DeleteList(pipR2T.playerNameDlist)
			end

			-- Get team color
			local r, g, b = Spring.GetTeamColor(teamID)
			local fontSize = math.floor(20 * render.widgetScale)
			local padding = math.floor(17 * render.widgetScale)
			local centerX = (render.dim.l + render.dim.r) / 2

			-- Create new display list
			pipR2T.playerNameDlist = gl.CreateList(function()
				ui.font:Begin()
				ui.font:SetTextColor(r, g, b, 1)
				ui.font:SetOutlineColor(0, 0, 0, 0.8)
				ui.font:Print(playerName, centerX, render.dim.t - padding - (fontSize * 1.6), fontSize * 2, "con")
				ui.font:End()
			end)

			pipR2T.playerNameLastPlayerID = interactionState.trackingPlayerID
			pipR2T.playerNameLastName = playerName
		end

		-- Draw the cached display list
		if pipR2T.playerNameDlist then
			gl.CallList(pipR2T.playerNameDlist)
		end
	end

	-- Helper function to format resource numbers compactly
	local function shortRes(n)
		if n >= 10000000 then
			return string.format("%.1fm", n / 1000000)
		elseif n >= 10000 then
			return string.format("%.1fk", n / 1000)
		elseif n >= 1000 then
			return string.format("%.0f", n)
		else
			return string.format("%.0f", n)
		end
	end

	-- Helper function to draw resource bars when tracking a player camera (hidden when PIP is hovered)
	-- Bars update every frame, text updates at ~2 FPS via cached display list
	function view.DrawTrackedResources()
		local res = ui.TrackedResources()
		if not res then
			return
		end
		local hist = miscState.hist
		local metalCur, metalMax, metalPull, metalIncome, metalShare =
			res.metalCur, res.metalMax, res.metalPull, res.metalIncome, res.metalShare
		local energyCur, energyMax, energyPull, energyIncome, energyShare =
			res.energyCur, res.energyMax, res.energyPull, res.energyIncome, res.energyShare
		local mmLevel, hasTeammates = res.mmLevel, res.hasTeammates

		-- Calculate bar dimensions - compact version at top of PIP
		local pipWidth = render.dim.r - render.dim.l
		local padding = math.floor(20 * render.widgetScale) * math.max(1, (render.vsx / 2700))
		local barHeight = math.floor(math.max(5, 7 * render.widgetScale)) * math.max(1, (render.vsx / 2400))
		local totalBarWidth = math.min(math.floor(pipWidth * 0.32), config.minPanelSize * 0.5) -- Each bar is 32% of PIP width
		local gapBetweenBars = math.floor(totalBarWidth * 0.28)

		-- Position: top of PIP, with padding from edge and corner
		local topY = render.dim.t - padding - render.elementCorner * 0.5
		local barY = topY - barHeight
		local centerX = (render.dim.l + render.dim.r) / 2

		-- Metal bar on left of center
		local metalBarRight = centerX - gapBetweenBars / 2
		local metalBarLeft = metalBarRight - totalBarWidth

		-- Energy bar on right of center
		local energyBarLeft = centerX + gapBetweenBars / 2
		local energyBarRight = energyBarLeft + totalBarWidth

		-- Calculate fill amounts
		local metalFill = math.min(1, math.max(0, metalCur / metalMax))
		local energyFill = math.min(1, math.max(0, energyCur / energyMax))

		-- Draw background boxes
		local bgAlpha = 0.6
		local cornerRadius = barHeight * 0.25

		glFunc.Color(0, 0, 0, bgAlpha)
		render.RectRound(metalBarLeft - 2, barY - 2, metalBarRight + 2, topY + 2, cornerRadius, 1, 1, 1, 1)
		render.RectRound(energyBarLeft - 2, barY - 2, energyBarRight + 2, topY + 2, cornerRadius, 1, 1, 1, 1)

		-- Draw metal bar fill
		if metalFill > 0.01 then
			local fillRight = metalBarLeft + (totalBarWidth * metalFill)
			glFunc.Color(0.77, 0.77, 0.77, 0.9)
			render.RectRound(
				metalBarLeft,
				barY,
				fillRight,
				topY,
				cornerRadius,
				1,
				metalFill >= 0.02 and 1 or 0,
				metalFill >= 0.02 and 1 or 0,
				1
			)
		end

		-- Draw energy bar fill
		if energyFill > 0.01 then
			local fillRight = energyBarLeft + (totalBarWidth * energyFill)
			glFunc.Color(1, 1, 0, 0.9)
			render.RectRound(
				energyBarLeft,
				barY,
				fillRight,
				topY,
				cornerRadius,
				1,
				energyFill >= 0.02 and 1 or 0,
				energyFill >= 0.02 and 1 or 0,
				1
			)
		end

		-- Draw sliders
		local sliderRadius = math.floor(barHeight * 0.55)
		local sliderY = barY + barHeight / 2

		-- Energy conversion slider (yellow, on energy bar only)
		if mmLevel and mmLevel < 0.745 and mmLevel > 0.755 then
			local convX = energyBarLeft + (totalBarWidth * mmLevel)
			glFunc.Color(0.94, 0.94, 0.66, 1)
			-- Draw slider knob as a circle
			local steps = 10
			glFunc.BeginEnd(GL.TRIANGLE_FAN, function()
				glFunc.Vertex(convX, sliderY, 0)
				for i = 0, steps do
					local angle = (i / steps) * 2 * math.pi
					glFunc.Vertex(convX + math.cos(angle) * sliderRadius, sliderY + math.sin(angle) * sliderRadius, 0)
				end
			end)
			-- Draw outline
			glFunc.Color(0, 0, 0, 0.6)
			glFunc.LineWidth(1)
			glFunc.BeginEnd(GL.LINE_LOOP, function()
				for i = 0, steps - 1 do
					local angle = (i / steps) * 2 * math.pi
					glFunc.Vertex(convX + math.cos(angle) * sliderRadius, sliderY + math.sin(angle) * sliderRadius, 0)
				end
			end)
		end

		-- Share sliders (red, only if player has teammates)
		if hasTeammates then
			-- Metal share slider
			if metalShare and metalShare < 0.98 then -- default metalShare = 0.99
				local shareX = metalBarLeft + (totalBarWidth * metalShare)
				glFunc.Color(0.9, 0.2, 0.2, 0.9)
				local steps = 10
				glFunc.BeginEnd(GL.TRIANGLE_FAN, function()
					glFunc.Vertex(shareX, sliderY, 0)
					for i = 0, steps do
						local angle = (i / steps) * 2 * math.pi
						glFunc.Vertex(
							shareX + math.cos(angle) * sliderRadius,
							sliderY + math.sin(angle) * sliderRadius,
							0
						)
					end
				end)
				glFunc.Color(0, 0, 0, 0.6)
				glFunc.LineWidth(1)
				glFunc.BeginEnd(GL.LINE_LOOP, function()
					for i = 0, steps - 1 do
						local angle = (i / steps) * 2 * math.pi
						glFunc.Vertex(
							shareX + math.cos(angle) * sliderRadius,
							sliderY + math.sin(angle) * sliderRadius,
							0
						)
					end
				end)
			end

			-- Energy share slider
			if energyShare and energyShare < 0.94 or energyShare > 0.96 then -- default energyShare = 0.949999
				local shareX = energyBarLeft + (totalBarWidth * energyShare)
				glFunc.Color(0.9, 0.2, 0.2, 0.9)
				local steps = 10
				glFunc.BeginEnd(GL.TRIANGLE_FAN, function()
					glFunc.Vertex(shareX, sliderY, 0)
					for i = 0, steps do
						local angle = (i / steps) * 2 * math.pi
						glFunc.Vertex(
							shareX + math.cos(angle) * sliderRadius,
							sliderY + math.sin(angle) * sliderRadius,
							0
						)
					end
				end)
				glFunc.Color(0, 0, 0, 0.6)
				glFunc.LineWidth(1)
				glFunc.BeginEnd(GL.LINE_LOOP, function()
					for i = 0, steps - 1 do
						local angle = (i / steps) * 2 * math.pi
						glFunc.Vertex(
							shareX + math.cos(angle) * sliderRadius,
							sliderY + math.sin(angle) * sliderRadius,
							0
						)
					end
				end)
			end
		end

		-- Text rendering - use cached display list, update at ~2 FPS and on each frame a paused or dragged rewind lands on
		local currentTime = os.clock()
		local needsTextUpdate = pipR2T.resbarTextDlist == nil
			or pipR2T.resbarTextLastPlayerID ~= interactionState.trackingPlayerID
			or pipR2T.resbarTextLastMode ~= hist.mode
			or (hist.mode and (not hist.playing or hist.dragging) and pipR2T.resbarTextLastFrame ~= hist.viewFrame)
			or (currentTime - pipR2T.resbarTextLastUpdate) >= pipR2T.resbarTextUpdateRate

		if needsTextUpdate then
			-- Clean up old display list
			if pipR2T.resbarTextDlist then
				gl.DeleteList(pipR2T.resbarTextDlist)
			end

			-- Create new display list with current resource text
			local fontSize = math.floor(math.max(12, 20 * render.widgetScale)) * math.max(1, (render.vsx / 2700))
			local smallFontSize = math.floor(fontSize * 0.8)
			local textY = barY + (barHeight / 2) + smallFontSize * 0.1
			local incomeY = barY - smallFontSize * 0.65
			local metalCenterX = (metalBarLeft + metalBarRight) / 2
			local energyCenterX = (energyBarLeft + energyBarRight) / 2

			pipR2T.resbarTextDlist = gl.CreateList(function()
				ui.font:Begin()
				ui.font:SetOutlineColor(0, 0, 0, 1)

				-- Metal: current amount centered on bar
				ui.font:SetTextColor(1, 1, 1, 1)
				ui.font:Print(shortRes(metalCur), metalCenterX, textY, fontSize, "ocn")

				-- Metal: income and pull below bar
				ui.font:SetTextColor(0.5, 1, 0.5, 1)
				ui.font:Print("+" .. shortRes(metalIncome), metalCenterX - 4, incomeY, smallFontSize, "orn")
				ui.font:SetTextColor(1, 0.5, 0.5, 1)
				ui.font:Print("-" .. shortRes(metalPull), metalCenterX + 4, incomeY, smallFontSize, "oln")

				-- Energy: current amount centered on bar
				ui.font:SetTextColor(1, 1, 0.7, 1)
				ui.font:Print(shortRes(energyCur), energyCenterX, textY, fontSize, "ocn")

				-- Energy: income and pull below bar
				ui.font:SetTextColor(0.5, 1, 0.5, 1)
				ui.font:Print("+" .. shortRes(energyIncome), energyCenterX - 4, incomeY, smallFontSize, "orn")
				ui.font:SetTextColor(1, 0.5, 0.5, 1)
				ui.font:Print("-" .. shortRes(energyPull), energyCenterX + 4, incomeY, smallFontSize, "oln")

				ui.font:End()
			end)

			pipR2T.resbarTextLastUpdate = currentTime
			pipR2T.resbarTextLastPlayerID = interactionState.trackingPlayerID
			pipR2T.resbarTextLastMode = hist.mode
			pipR2T.resbarTextLastFrame = hist.viewFrame
		end

		-- Draw the cached text display list
		if pipR2T.resbarTextDlist then
			gl.CallList(pipR2T.resbarTextDlist)
		end

		glFunc.Color(1, 1, 1, 1)
	end

	function view.DrawFrame(pipWidth, pipHeight)
		if not gl.R2tHelper then
			return
		end
		tracy.ZoneBeginN("W:PIP:R2T:Frame")

		local stripH = miscState.hist.StripH()
		local frameH = pipHeight + stripH
		-- Check if frame size changed
		if math.floor(pipWidth) ~= pipR2T.frameLastWidth or math.floor(frameH) ~= pipR2T.frameLastHeight then
			pipR2T.frameNeedsUpdate = true
			if pipR2T.frameBackgroundTex then
				gl.DeleteTexture(pipR2T.frameBackgroundTex)
				pipR2T.frameBackgroundTex = nil
			end
			if pipR2T.frameButtonsTex then
				gl.DeleteTexture(pipR2T.frameButtonsTex)
				pipR2T.frameButtonsTex = nil
			end
			-- Invalidate text display lists when size changes (positions change)
			if pipR2T.resbarTextDlist then
				gl.DeleteList(pipR2T.resbarTextDlist)
				pipR2T.resbarTextDlist = nil
			end
			if pipR2T.playerNameDlist then
				gl.DeleteList(pipR2T.playerNameDlist)
				pipR2T.playerNameDlist = nil
			end
			pipR2T.frameLastWidth = math.floor(pipWidth)
			pipR2T.frameLastHeight = math.floor(frameH)
		end

		-- Update frame textures if needed
		if pipR2T.frameNeedsUpdate and pipWidth >= 1 and pipHeight >= 1 then
			tracy.ZoneBeginN("W:PIP:R2T:Frame:Render")
			-- Create texture large enough to include elementPadding on all sides
			local bgTexWidth = math.floor(pipWidth + render.elementPadding * 2)
			local bgTexHeight = math.floor(frameH + render.elementPadding * 2)

			if not pipR2T.frameBackgroundTex then
				pipR2T.frameBackgroundTex = gl.CreateTexture(bgTexWidth, bgTexHeight, {
					target = GL.TEXTURE_2D,
					format = GL.RGBA8,
					fbo = true,
				})
			end
			if pipR2T.frameBackgroundTex then
				gl.R2tHelper.RenderToTexture(pipR2T.frameBackgroundTex, function()
					glFunc.Translate(-1, -1, 0)
					glFunc.Scale(2 / bgTexWidth, 2 / bgTexHeight, 0)
					-- Render UiElement using actual screen coordinates for proper shading
					local padL = render.dim.l - render.elementPadding
					local padB = render.dim.b - stripH - render.elementPadding
					local padR = render.dim.r + render.elementPadding
					local padT = render.dim.t + render.elementPadding
					-- Translate to origin for texture rendering
					glFunc.Translate(-padL, -padB, 0)
					local tl, tr, br, bl = GetChamferedCorners(padL, padB, padR, padT)
					render.UiElement(padL, padB, padR, padT, tl, tr, br, bl, nil, nil, nil, nil, nil, nil, nil, nil)
				end, true)
			end

			if not pipR2T.frameButtonsTex then
				pipR2T.frameButtonsTex = gl.CreateTexture(math.floor(pipWidth), math.floor(pipHeight), {
					target = GL.TEXTURE_2D,
					format = GL.RGBA8,
					fbo = true,
				})
			end
			if pipR2T.frameButtonsTex then
				gl.R2tHelper.RenderToTexture(pipR2T.frameButtonsTex, function()
					glFunc.Translate(-1, -1, 0)
					glFunc.Scale(2 / pipWidth, 2 / pipHeight, 0)
					RenderFrameButtons()
				end, true)
			end

			pipR2T.frameNeedsUpdate = false
			tracy.ZoneEnd()
		end

		if miscState.externalFrame.active then
			tracy.ZoneEnd()
			return -- the frame around it draws the background
		end
		if pipR2T.frameBackgroundTex then
			-- Blit the cached UiElement background (includes padding)
			gl.R2tHelper.BlendTexRect(
				pipR2T.frameBackgroundTex,
				render.dim.l - render.elementPadding,
				render.dim.b - stripH - render.elementPadding,
				render.dim.r + render.elementPadding,
				render.dim.t + render.elementPadding,
				true
			)
		else
			-- Fallback to direct rendering if texture not available
			local padL = render.dim.l - render.elementPadding
			local padB = render.dim.b - stripH - render.elementPadding
			local padR = render.dim.r + render.elementPadding
			local padT = render.dim.t + render.elementPadding
			local tl, tr, br, bl = GetChamferedCorners(padL, padB, padR, padT)
			render.UiElement(padL, padB, padR, padT, tl, tr, br, bl, nil, nil, nil, nil, nil, nil, nil, nil)
		end
		tracy.ZoneEnd()
	end

	function view.DrawMapMask(maskStripH)
		-- Draw rounded rectangle shape for stencil mask
		-- Use slightly larger corner radius so diagonal border looks same thickness as straight edges
		-- Disable corner rounding at screen edges
		local edgeTolerance = 2
		local atLeft = render.dim.l <= edgeTolerance
		local atRight = render.dim.r >= render.vsx - edgeTolerance
		-- the timeline strip below takes the bottom corner cuts
		local atBottom = render.dim.b <= edgeTolerance or maskStripH > 0
		local atTop = render.dim.t >= render.vsy - edgeTolerance
		-- inside another widget's frame the map is a plain rect: the frame gives the look
		local framed = miscState.externalFrame.active
		local tl = (framed or atLeft or atTop) and 0 or 1
		local tr = (framed or atRight or atTop) and 0 or 1
		local br = (framed or atRight or atBottom) and 0 or 1
		local bl = (framed or atLeft or atBottom) and 0 or 1
		render.RectRound(
			render.dim.l,
			render.dim.b,
			render.dim.r,
			render.dim.t,
			render.elementCorner * 0.5,
			tl,
			tr,
			br,
			bl
		)
	end

	-- Helper function to draw tracking indicators
	function view.DrawTrackingBorder()
		-- inside another widget's frame the map's corners are square
		local round = miscState.externalFrame.active and 0 or 1
		if interactionState.areTracking and #interactionState.areTracking > 0 then
			local lineWidth = math.ceil(2 * (render.vsx / 1920))
			local outlineColor = pools.trackingOutlineColor
			glFunc.Color(1, 1, 1, 0.22)
			render.RectRoundOutline(
				render.dim.l,
				render.dim.b,
				render.dim.r,
				render.dim.t,
				render.elementCorner * 0.5,
				lineWidth,
				round,
				round,
				round,
				round,
				outlineColor,
				outlineColor
			)
		end

		if interactionState.trackingPlayerID then
			local playerName, active, isSpec, teamID = spFunc.GetPlayerInfo(interactionState.trackingPlayerID, false)
			if teamID then
				local r, g, b = Spring.GetTeamColor(teamID)
				local lineWidth = math.ceil(3 * (render.vsx / 1920))
				local teamColor = pools.trackingTeamColor
				teamColor[1], teamColor[2], teamColor[3], teamColor[4] = r, g, b, 0.5
				glFunc.Color(r, g, b, 0.5)
				render.RectRoundOutline(
					render.dim.l,
					render.dim.b,
					render.dim.r,
					render.dim.t,
					render.elementCorner * 0.5,
					lineWidth,
					round,
					round,
					round,
					round,
					teamColor,
					teamColor
				)
			end
		end
	end

	-- Helper function to draw interactive overlays (buttons, pip number, etc.)
	local function drawHoverOverlays(mx, my)
		tracy.ZoneBeginN("W:PIP:UI:InteractiveOverlays")
		-- Draw pipNumber text only when hovering (and only for pip 2+)
		if pipNumber > 1 and interactionState.isMouseOverPip then
			glFunc.Color(config.panelBorderColorDark)
			render.RectRound(
				render.dim.l,
				render.dim.t - render.usedButtonSize,
				render.dim.l + render.usedButtonSize,
				render.dim.t,
				render.elementCorner * 0.4,
				0,
				0,
				1,
				0
			)
			local fontSize = 14
			local padding = 12
			ui.font:Begin()
			ui.font:SetTextColor(0.85, 0.85, 0.85, 1)
			ui.font:SetOutlineColor(0, 0, 0, 0.5)
			ui.font:Print(
				pipNumber,
				render.dim.l + padding,
				render.dim.t - (fontSize * 1.15) - padding,
				fontSize * 2,
				"no"
			)
			ui.font:End()
		end

		-- Bottom-left buttons hover
		local visibleButtons = pools.visibleButtons

		-- inside another widget's frame the frame draws them (WG.minimap.getFrameButtons)
		if #visibleButtons > 0 and not miscState.externalFrame.active then
			-- Draw base buttons when showing on hover
			if config.showButtonsOnHoverOnly and interactionState.isMouseOverPip then
				tracy.ZoneBeginN("W:PIP:UI:DrawButtonBase")
				glFunc.Color(config.panelBorderColorDark)
				glFunc.Texture(false)
				render.RectRound(
					render.dim.l,
					render.dim.b,
					render.dim.l + (#visibleButtons * render.usedButtonSize) + math.floor(render.elementPadding * 0.75),
					render.dim.b + render.usedButtonSize + math.floor(render.elementPadding * 0.75),
					render.elementCorner,
					0,
					1,
					0,
					0
				)
				local bx = render.dim.l
				for i = 1, #visibleButtons do
					if ui.IsButtonActive(visibleButtons[i]) then
						glFunc.Color(config.panelBorderColorLight)
						glFunc.Texture(false)
						render.RectRound(
							bx,
							render.dim.b,
							bx + render.usedButtonSize,
							render.dim.b + render.usedButtonSize,
							render.elementCorner * 0.4,
							1,
							1,
							1,
							1
						)
						glFunc.Color(config.panelBorderColorDark)
					else
						glFunc.Color(config.panelBorderColorLight)
					end
					glFunc.Texture(visibleButtons[i].texture)
					glFunc.TexRect(bx, render.dim.b, bx + render.usedButtonSize, render.dim.b + render.usedButtonSize)
					bx = bx + render.usedButtonSize
				end
				glFunc.Texture(false)
				tracy.ZoneEnd()
			end

			-- Button hover interactions (always check for hover, not just when showing on hover)
			tracy.ZoneBeginN("W:PIP:UI:HoverButtons")
			local bx = render.dim.l
			for i = 1, #visibleButtons do
				if
					mx >= bx
					and mx <= bx + render.usedButtonSize
					and my >= render.dim.b
					and my <= render.dim.b + render.usedButtonSize
				then
					if visibleButtons[i].tooltipKey then
						ui.ShowTooltip(ui.ButtonTooltip(visibleButtons[i]))
					end
					glFunc.Color(1, 1, 1, 0.12)
					glFunc.Texture(false)
					render.RectRound(
						bx,
						render.dim.b,
						bx + render.usedButtonSize,
						render.dim.b + render.usedButtonSize,
						render.elementCorner * 0.4,
						1,
						1,
						1,
						1
					)
					if ui.IsButtonActive(visibleButtons[i]) then
						glFunc.Color(config.panelBorderColorDark)
					else
						glFunc.Color(1, 1, 1, 1)
					end
					glFunc.Texture(visibleButtons[i].texture)
					glFunc.TexRect(bx, render.dim.b, bx + render.usedButtonSize, render.dim.b + render.usedButtonSize)
					-- Draw hover highlight on top for better visibility
					glFunc.Color(1, 1, 1, 0.2)
					glFunc.Texture(false)
					render.RectRound(
						bx,
						render.dim.b,
						bx + render.usedButtonSize,
						render.dim.b + render.usedButtonSize,
						render.elementCorner * 0.4,
						1,
						1,
						1,
						1
					)
					glFunc.Texture(false)
					break
				end
				bx = bx + render.usedButtonSize
			end
			tracy.ZoneEnd()
		end
		tracy.ZoneEnd()
	end

	local function drawMinimapMinimized(mx, my)
		local buttonSize = math.floor(render.usedButtonSize * config.maximizeSizemult)
		local btnL = render.dim.l
		local btnB = render.dim.t - buttonSize
		local btnR = btnL + buttonSize
		local btnT = render.dim.t

		-- Background
		local tl, tr, br, bl = GetChamferedCorners(
			btnL - render.elementPadding,
			btnB - render.elementPadding,
			btnR + render.elementPadding,
			btnT + render.elementPadding
		)
		render.UiElement(
			btnL - render.elementPadding,
			btnB - render.elementPadding,
			btnR + render.elementPadding,
			btnT + render.elementPadding,
			tl,
			tr,
			br,
			bl,
			nil,
			nil,
			nil,
			nil,
			nil,
			nil,
			nil,
			nil
		)

		-- Icon with rotation based on expansion direction
		local sw, sh = Spring.GetWindowGeometry()
		local onLeftSide = (btnL < sw * 0.5)
		local onBottomSide = (btnB < sh * 0.25)
		local rotation
		if onLeftSide and onBottomSide then
			rotation = 180
		elseif not onLeftSide and onBottomSide then
			rotation = 270
		elseif not onLeftSide and not onBottomSide then
			rotation = 0
		else
			rotation = 90
		end
		local centerX = (btnL + btnR) * 0.5
		local centerY = (btnB + btnT) * 0.5
		glFunc.Color(config.panelBorderColorLight)
		glFunc.Texture("LuaUI/Images/pip/PipExpand.png")
		glFunc.PushMatrix()
		glFunc.Translate(centerX, centerY, 0)
		glFunc.Rotate(rotation, 0, 0, 1)
		glFunc.Translate(-centerX, -centerY, 0)
		glFunc.TexRect(btnL, btnB, btnR, btnT)
		glFunc.PopMatrix()
		glFunc.Texture(false)

		-- Hover highlight
		if mx >= btnL and mx <= btnR and my >= btnB and my <= btnT then
			if WG.tooltip then
				WG.tooltip.ShowTooltip("pip" .. pipNumber, BAR.I18N("ui.pip.minimap_maximize"), nil, nil, nil)
			end
			glFunc.Color(1, 1, 1, 0.12)
			glFunc.Texture(false)
			render.RectRound(btnL, btnB, btnR, btnT, render.elementCorner * 0.4, 1, 1, 1, 1)
		end
	end

	local function drawWindowMinimized(mx, my)
		local buttonSize = math.floor(render.usedButtonSize * config.maximizeSizemult)

		-- Draw render.UiElement background FIRST (with proper screen coordinates)
		--render.UiElement(uiState.minModeL-render.elementPadding, uiState.minModeB-render.elementPadding, uiState.minModeL+buttonSize+render.elementPadding, uiState.minModeB+buttonSize+render.elementPadding, 1, 1, 1, 1, nil, nil, nil, nil, nil, nil, nil, nil)

		-- Then draw icon on top using display list
		local offset = render.elementPadding + 2 -- to prevent touching screen edges and FlowUI Element will remove borders

		-- Check if we need to recreate display list due to position change (affects rotation)
		local sw, sh = Spring.GetWindowGeometry()
		local currentQuadrant = (uiState.minModeL < sw * 0.5 and 1 or 2) + (uiState.minModeB < sh * 0.25 and 0 or 2)
		-- Also track edge state for chamfered corners
		local actualL = uiState.minModeL - render.elementPadding
		local actualB = uiState.minModeB - render.elementPadding
		local actualR = uiState.minModeL + buttonSize + render.elementPadding
		local actualT = uiState.minModeB + buttonSize + render.elementPadding
		local currentEdgeState = (actualL <= 0 and 1 or 0)
			+ (actualB <= 0 and 2 or 0)
			+ (actualR >= render.vsx and 4 or 0)
			+ (actualT >= render.vsy and 8 or 0)
		if
			(render.minModeQuadrant ~= currentQuadrant or render.minModeEdgeState ~= currentEdgeState)
			and render.minModeDlist
		then
			gl.DeleteList(render.minModeDlist)
			render.minModeDlist = nil
		end
		render.minModeQuadrant = currentQuadrant
		render.minModeEdgeState = currentEdgeState

		if not render.minModeDlist then
			render.minModeDlist = gl.CreateList(function()
				-- Draw render.UiElement background (only borders, no fill to avoid double opacity)
				-- Compute actual screen coordinates for chamfered corners
				local actualL = uiState.minModeL - render.elementPadding
				local actualB = uiState.minModeB - render.elementPadding
				local actualR = uiState.minModeL + buttonSize + render.elementPadding
				local actualT = uiState.minModeB + buttonSize + render.elementPadding
				local tl, tr, br, bl = GetChamferedCorners(actualL, actualB, actualR, actualT)
				render.UiElement(
					offset - render.elementPadding,
					offset - render.elementPadding,
					offset + buttonSize + render.elementPadding,
					offset + buttonSize + render.elementPadding,
					tl,
					tr,
					br,
					bl,
					nil,
					nil,
					nil,
					nil,
					nil,
					nil,
					nil,
					nil
				)

				-- Draw icon at origin (0,0) - will be transformed to actual position
				glFunc.Color(config.panelBorderColorLight)
				glFunc.Texture("LuaUI/Images/pip/PipExpand.png")

				-- Rotate icon based on expansion direction
				local rotation = ui.MaximizeIconRotation()
				local centerX = offset + buttonSize * 0.5
				local centerY = offset + buttonSize * 0.5
				glFunc.PushMatrix()
				glFunc.Translate(centerX, centerY, 0)
				glFunc.Rotate(rotation, 0, 0, 1)
				glFunc.Translate(-centerX, -centerY, 0)

				glFunc.TexRect(offset, offset, offset + buttonSize, offset + buttonSize)
				glFunc.PopMatrix()
				glFunc.Texture(false)
			end)
		end

		-- Apply transform and draw the cached icon at actual position
		glFunc.PushMatrix()
		glFunc.Translate(uiState.minModeL - offset, uiState.minModeB - offset, 0)
		glFunc.CallList(render.minModeDlist)
		glFunc.PopMatrix()

		-- Draw hover overlay if needed (dynamic)
		glFunc.Color(config.panelBorderColorDark)
		glFunc.Texture(false)
		if
			mx >= uiState.minModeL - render.elementPadding
			and mx <= uiState.minModeL + buttonSize + render.elementPadding
			and my >= uiState.minModeB - render.elementPadding
			and my <= uiState.minModeB + buttonSize + render.elementPadding
		then
			if WG.tooltip then
				WG.tooltip.ShowTooltip("pip" .. pipNumber, BAR.I18N("ui.pip.tooltip"), nil, nil, nil)
			end
			glFunc.Color(1, 1, 1, 0.12)
			glFunc.Texture(false)
			render.RectRound(
				uiState.minModeL,
				uiState.minModeB,
				uiState.minModeL + buttonSize,
				uiState.minModeB + buttonSize,
				render.elementCorner * 0.4,
				1,
				1,
				1,
				1
			)
		end
	end

	function view.DrawMinimized(mx, my)
		if isMinimapMode and miscState.minimapMinimized then
			drawMinimapMinimized(mx, my)
		else
			drawWindowMinimized(mx, my)
		end
	end

	function view.DrawControls(mx, my, mbl)
		-- Blit frame buttons
		if pipR2T.frameButtonsTex then
			tracy.ZoneBeginN("W:PIP:UI:FrameButtonsTex")
			gl.R2tHelper.BlendTexRect(
				pipR2T.frameButtonsTex,
				render.dim.l,
				render.dim.b,
				render.dim.r,
				render.dim.t,
				true
			)
			tracy.ZoneEnd()
		end

		-- Draw resize handle when showing on hover (hide in minimap mode if configured)
		tracy.ZoneBeginN("W:PIP:UI:ResizeHover")
		if
			config.showButtonsOnHoverOnly
			and interactionState.isMouseOverPip
			and not (isMinimapMode and config.minimapModeHideMoveResize)
		then
			glFunc.Color(config.panelBorderColorDark)
			glFunc.LineWidth(1.0)
			glFunc.BeginEnd(glConst.TRIANGLES, ResizeHandleVertices)
		end

		-- Draw dynamic hover overlays
		-- Resize handle hover (skip in minimap mode if configured)
		local hover = false
		if not (isMinimapMode and config.minimapModeHideMoveResize) then
			hover = uiState.areResizing or false
			if mx >= render.dim.l and mx <= render.dim.r and my >= render.dim.b and my <= render.dim.t then
				if render.dim.r - mx + my - render.dim.b <= render.usedButtonSize then
					hover = true
					if WG.tooltip then
						WG.tooltip.ShowTooltip("pip" .. pipNumber, BAR.I18N("ui.pip.resize"), nil, nil, nil)
					end
				end
			end
			if hover then
				local mult = mbl and 4.5 or 1.5
				glFunc.Color(
					config.panelBorderColorDark[1] * mult,
					config.panelBorderColorDark[2] * mult,
					config.panelBorderColorDark[3] * mult,
					1
				)
				glFunc.LineWidth(1.0)
				glFunc.BeginEnd(glConst.TRIANGLES, ResizeHandleVertices)
			end
		end
		tracy.ZoneEnd()

		-- Minimize button hover (show in minimap mode on hover for MinimapMinimize)
		tracy.ZoneBeginN("W:PIP:UI:MinimizeHover")
		hover = false
		if not isMinimapMode or config.minimapModeShowMinimizeButton then -- In minimap mode, only show if configured
			if config.showButtonsOnHoverOnly and interactionState.isMouseOverPip then
				-- Draw minimize button base when showing on hover
				glFunc.Color(config.panelBorderColorDark)
				glFunc.Texture(false)
				render.RectRound(
					render.dim.r - render.usedButtonSize - render.elementPadding,
					render.dim.t - render.usedButtonSize - render.elementPadding,
					render.dim.r,
					render.dim.t,
					render.elementCorner,
					0,
					0,
					0,
					1
				)
				glFunc.Color(config.panelBorderColorLight)
				glFunc.Texture("LuaUI/Images/pip/PipShrink.png")

				-- Rotate icon opposite to maximize direction (points toward shrink position)
				local rotation = ui.MaximizeIconRotation()
				local centerX = render.dim.r - render.usedButtonSize * 0.5
				local centerY = render.dim.t - render.usedButtonSize * 0.5
				glFunc.PushMatrix()
				glFunc.Translate(centerX, centerY, 0)
				glFunc.Rotate(rotation, 0, 0, 1)
				glFunc.Translate(-centerX, -centerY, 0)

				glFunc.TexRect(
					render.dim.r - render.usedButtonSize,
					render.dim.t - render.usedButtonSize,
					render.dim.r,
					render.dim.t
				)
				glFunc.PopMatrix()
				glFunc.Texture(false)
			end
			if
				mx >= render.dim.r - render.usedButtonSize - render.elementPadding
				and mx <= render.dim.r - render.elementPadding
				and my >= render.dim.t - render.usedButtonSize - render.elementPadding
				and my <= render.dim.t - render.elementPadding
			then
				hover = true
				if WG.tooltip then
					WG.tooltip.ShowTooltip(
						"pip" .. pipNumber,
						BAR.I18N(isMinimapMode and "ui.pip.minimap_minimize" or "ui.pip.minimize"),
						nil,
						nil,
						nil
					)
				end
				glFunc.Color(1, 1, 1, 0.12)
				glFunc.Texture(false)
				render.RectRound(
					render.dim.r - render.usedButtonSize,
					render.dim.t - render.usedButtonSize,
					render.dim.r,
					render.dim.t,
					render.elementCorner * 0.4,
					1,
					1,
					1,
					1
				)
				glFunc.Color(1, 1, 1, 1)
				glFunc.Texture("LuaUI/Images/pip/PipShrink.png")

				-- Rotate icon opposite to maximize direction (points toward shrink position)
				local rotation = ui.MaximizeIconRotation()
				local centerX = render.dim.r - render.usedButtonSize * 0.5
				local centerY = render.dim.t - render.usedButtonSize * 0.5
				glFunc.PushMatrix()
				glFunc.Translate(centerX, centerY, 0)
				glFunc.Rotate(rotation, 0, 0, 1)
				glFunc.Translate(-centerX, -centerY, 0)

				glFunc.TexRect(
					render.dim.r - render.usedButtonSize,
					render.dim.t - render.usedButtonSize,
					render.dim.r,
					render.dim.t
				)
				glFunc.PopMatrix()
				glFunc.Texture(false)
			end
		end
		tracy.ZoneEnd()

		-- Bottom-left buttons hover and pip number
		drawHoverOverlays(mx, my)
	end

	function view.HitResize(mx, my)
		return render.dim.r - mx + my - render.dim.b <= render.usedButtonSize
	end

	function view.HitResizeOutside()
		return false
	end

	function view.HitMinimize(mx, my)
		return mx >= render.dim.r - render.usedButtonSize and my >= render.dim.t - render.usedButtonSize
	end

	-- which of the visible buttons, nil when not on the row (the index can be past the last one)
	function view.ButtonIndexAt(mx, my)
		if my <= render.dim.b + render.usedButtonSize then
			return 1 + math.floor((mx - render.dim.l) / render.usedButtonSize)
		end
		return nil
	end

	function view.ReleaseFrame()
		if render.minModeDlist then
			gl.DeleteList(render.minModeDlist)
			render.minModeDlist = nil
		end
		if pipR2T.frameBackgroundTex then
			gl.DeleteTexture(pipR2T.frameBackgroundTex)
			pipR2T.frameBackgroundTex = nil
		end
		if pipR2T.frameButtonsTex then
			gl.DeleteTexture(pipR2T.frameButtonsTex)
			pipR2T.frameButtonsTex = nil
		end
	end

	function view.ReleaseText()
		if pipR2T.resbarTextDlist then
			gl.DeleteList(pipR2T.resbarTextDlist)
			pipR2T.resbarTextDlist = nil
		end
		if pipR2T.playerNameDlist then
			gl.DeleteList(pipR2T.playerNameDlist)
			pipR2T.playerNameDlist = nil
		end
	end

	function view.Release()
		view.ReleaseFrame()
		view.ReleaseText()
		view.RemoveBlur()
		if render.guishaderDlist then
			gl.DeleteList(render.guishaderDlist)
			render.guishaderDlist = nil
		end
	end

	return view
end

return M
