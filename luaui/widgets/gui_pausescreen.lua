include("keysym.h.lua")
local versionNumber = "1.34"

function widget:GetInfo()
    return {
        name      = "Pause Screen",
        desc      = "Displays an overlay when the game is paused",
        author    = "very_bad_soldier (enhanced by: Floris)",
        date      = "2009.08.16",
        license   = "GNU GPL v2",
        layer     = 0,
        enabled   = true
    }
end

--------------------------------------------------------------------------------
-- Console commands
--------------------------------------------------------------------------------

-- /pausescreen_autofade            -- toggles auto fadeout

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local spGetGameSeconds      = Spring.GetGameSeconds
local spGetMouseState       = Spring.GetMouseState
local spEcho                = Spring.Echo

local spGetGameSpeed         = Spring.GetGameSpeed

local max                    = math.max

local glColor               = gl.Color
local glTexture             = gl.Texture
local glScale                = gl.Scale
local glPopMatrix           = gl.PopMatrix
local glPushMatrix          = gl.PushMatrix
local glTranslate           = gl.Translate
local glBeginEnd            = gl.BeginEnd
local glTexRect             = gl.TexRect
local glLoadFont            = gl.LoadFont
local glDeleteFont            = gl.DeleteFont
local glRect                = gl.Rect
local glLineWidth           = gl.LineWidth
local glDepthTest           = gl.DepthTest

local osClock                = os.clock

----------------------------------------------------------------------------------

-- CONFIGURATION

local sizeMultiplier     = 1
local maxAlpha           = 0.66
local boxWidth           = 200
local boxHeight          = 35
local slideTime          = 0.4
local fadeTime           = 0.22
local fadeToAlpha        = 0
local fadeToTextAlpha    = 0.25
local wndBorderSize      = 4
local imgWidth           = 92     --drawing size of the image (independent from the real image pixel size)
local imgTexCoordX       = 0.625  --image texture coordinate X -- textures image's dimension is a power of 2 (i use 0.625 cause my image has a width of 256, but region to use is only 160 pixel -> 160 / 256 = 0.625 )
local imgTexCoordY       = 0.62   --image texture coordinate Y -- enter values other than 1.0 to use just a region of the texture image
local fontSizeHeadline   = 24
local fontSizeAddon      = 15
local windowIconPath     = "LuaUI/Images/SpringIconmkII.png"
local fontPath           = "LuaUI/Fonts/MicrogrammaDBold.ttf"
local imgCloseWidth      = 0
local autoFade           = true
local autoFadeTime       = 1
local forceHideWindow    = false
--Color config in drawPause function
    
----------------
local screenx, screeny
local myFont
local clickTimestamp = 0
local autoFadeTimestamp = 0
local pauseTimestamp = 0 --start or end of pause
local lastPause = false
local screenCenterX = nil
local screenCenterY = nil
local wndX1 = nil
local wndY1 = nil
local wndX2 = nil
local wndY2 = nil
local textX = nil
local textY = nil
local lineOffset = nil
local yCenter = nil
local xCut = nil
local mouseOverClose = false
local checkedWindowSize = false
local usedSizeMultiplier = 1
local winSizeX, winSizeY = Spring.GetWindowGeometry()
local widgetInitTime = osClock()
local previousGameframeClock = osClock()
local previousDrawScreenClock = osClock()
local paused = false


function widget:Initialize()
    myFont = glLoadFont( fontPath, fontSizeHeadline )
    updateWindowCoords()
    winSizeX, winSizeY = Spring.GetWindowGeometry()
    usedSizeMultiplier = (0.66 + ((winSizeX*winSizeY)/10000000)) * sizeMultiplier
    checkedWindowSize = true
end

function widget:Shutdown()
    glDeleteFont( myFont )
end

function widget:DrawScreen()
    local now = osClock()
    local drawScreenDelay = now - previousDrawScreenClock
    previousDrawScreenClock = now
    
    local _, _, isPaused = spGetGameSpeed()        -- note: when viewing a replay.. isPaused wont be set true if you pause
    local diffPauseTime = ( now - pauseTimestamp)
    
    if not paused and ((spGetGameSeconds() > 0 and previousGameframeClock <= (now-1.5)-(drawScreenDelay*2)) or isPaused) then
        paused = true
    end
    
    
    local diffPauseTime = ( now - pauseTimestamp)
    
    if ( ( not paused and lastPause ) or ( paused and not lastPause ) ) then
        --pause switch
        pauseTimestamp = osClock()
        if ( diffPauseTime <= slideTime ) then
            pauseTimestamp = pauseTimestamp - ( slideTime - ( diffPauseTime / slideTime ) * slideTime )
        end
    end
    
    if ( paused and not lastPause ) then
        --new pause
        clickTimestamp = nil
        autoFadeTimestamp = nil
        if widgetInitTime + 5 > now then        -- so if you do /luaui reload when paused, it wont re-animate
            clickTimestamp = nil
            autoFadeTimestamp = now - autoFadeTime
            pauseTimestamp = now - (slideTime + autoFadeTime)
        end
    end
    
    lastPause = paused
    
    if ( paused or ( ( now - pauseTimestamp) <= slideTime ) ) then
        drawPause()
    end
    
    ResetGl()
end

function isOverWindow(x, y)
    if ( ( x > screenCenterX - (boxWidth*usedSizeMultiplier)) and ( y < screenCenterY + (boxHeight*usedSizeMultiplier) ) and 
        ( x < screenCenterX + (boxWidth*usedSizeMultiplier) ) and ( y > screenCenterY - (boxHeight*usedSizeMultiplier) ) ) then    
        return true
    end
    return false
 end

function widget:MousePress(x, y, button)
  if ( not clickTimestamp and not forceHideWindow ) then
    if ( isOverWindow(x, y)) then    
        
        --hide window for the rest of the game if it was a right mouse button
        if ( button == 3 and not autoFade) then
            forceHideWindow = true
            autoFadeTimestamp = osClock()
        else
            --do not update clickTimestamp any more after right mouse button click
            if ( not autoFadeTimestamp ) then
                clickTimestamp = osClock()
            end
        end
        
        --return true
    end
  end
  
  return false
end


function widget:IsAbove(x,y)
    local _, _, paused = spGetGameSpeed()
    if ( paused and not forceHideWindow and not clickTimestamp and isOverWindow( x, y ) ) then
        return true
    end
    return false
end

function widget:GameFrame()
    local _, _, isPaused = spGetGameSpeed()
    if not isPaused then
        paused = false
    end
    previousGameframeClock = osClock()
end

function widget:Update()
    local x,y = spGetMouseState()
    if ( isOverWindow(x, y) ) then    
        mouseOverClose = true
    else
        mouseOverClose = false
    end
end

function widget:GetTooltip(x, y)
    if ( ( clickTimestamp == nil and forceHideWindow == false ) and isOverWindow(x, y) ) then
        return "Click left mouse button to hide pause window.\nClick right mouse button to hide pause window for the rest of the game."
    end
end

function drawPause()
    local now = osClock()
    local diffPauseTime = ( now - pauseTimestamp)
    
    local text           = { 1.0, 1.0, 1.0, 1.0*maxAlpha }
    local text2          = { 0.9, 0.9, 0.9, 1.0*maxAlpha }
    local outline        = { 0.0, 0.0, 0.0, 1.0*maxAlpha }    
    local outline2       = { 0.4, 0.4, 0.4, 0.5*maxAlpha }    
    local colorWnd       = { 0.0, 0.0, 0.0, 0.6*maxAlpha }
    local colorWnd2      = { 0.5, 0.5, 0.5, 0.6*maxAlpha }
    local iconColor      = { 1.0, 1.0, 1.0, 1.0*maxAlpha }
    local mouseOverColor = { 1.0, 1.0, 0.0, 1.0*maxAlpha }
    
    -- check window size and change scale accordingly
    if ( diffPauseTime <= slideTime ) then
        if  not checkedWindowSize then
            winSizeX, winSizeY = Spring.GetWindowGeometry()
            usedSizeMultiplier = (0.5 + ((winSizeX*winSizeY)/5000000)) * sizeMultiplier
            checkedWindowSize = true
        end
    else
        checkedWindowSize = false
    end
    
    --adjust transparency when clicked
    if ( clickTimestamp ~= nil or forceHideWindow or autoFadeTimestamp or  diffPauseTime <= slideTime ) then
        local factor = 0.0
        if ( clickTimestamp and clickTimestamp + fadeTime > now) then        
            factor = ( 1.0 - ( now - clickTimestamp ) / fadeTime )*maxAlpha
        elseif autoFadeTimestamp and autoFadeTimestamp + autoFadeTime > now then
            factor = ( 1.0 - ( now - autoFadeTimestamp ) / autoFadeTime )*maxAlpha
        elseif not paused and pauseTimestamp and pauseTimestamp + slideTime > now then 
            factor = ( ( now - pauseTimestamp ) / slideTime ) * 0.66
        elseif paused and pauseTimestamp and pauseTimestamp + slideTime > now then
            factor = ( 0.5 + ( now - pauseTimestamp ) / (slideTime*1.5))
        end
        if factor > maxAlpha then 
            factor = maxAlpha 
        end
        factor = max( factor, fadeToAlpha )
        colorWnd[4] = colorWnd[4] * factor
        text[4] = (text[4]  * factor) + fadeToTextAlpha
        text2[4] = text2[4] * factor
        outline[4] = (outline[4] * factor) + (fadeToTextAlpha/2.25)
        outline2[4] = outline2[4] * factor
        iconColor[4] = iconColor[4] * (factor - (fadeToAlpha/4))
        iconColor[1] = iconColor[1] * (factor + 0.44)
        iconColor[2] = iconColor[2] * (factor + 0.44)
        iconColor[3] = iconColor[3] * (factor + 0.44)
        mouseOverColor[4] = mouseOverColor[4] * factor    
    end
    local imgWidthHalf = imgWidth * 0.5
    
    --draw window
    glPushMatrix()
    glTranslate(-winSizeX*(usedSizeMultiplier-1)/2,  -winSizeY*(usedSizeMultiplier-1)/2, 0)
    glScale(usedSizeMultiplier,usedSizeMultiplier,1)
    if ( diffPauseTime <= slideTime ) then
        --we are sliding
        if ( paused ) then
            --sliding in
            glTranslate( (( screenx - wndX1 ) / usedSizeMultiplier) * ( 1.0 - ( diffPauseTime / slideTime ) ), 0, 0)
        else
            --sliding out
            glTranslate( (( screenx - wndX1 ) / usedSizeMultiplier) * ( ( diffPauseTime / slideTime ) ), 0, 0)
        end
    end
    glColor( colorWnd )
    glRect( wndX1, wndY1, wndX2, wndY2 )
    glColor( colorWnd )
    glRect( wndX1 - wndBorderSize, wndY1 + wndBorderSize, wndX2 + wndBorderSize, wndY2 - wndBorderSize)
    
    --draw text
    myFont:Begin()
    myFont:SetOutlineColor( outline )
    myFont:SetTextColor( text )
    myFont:Print( "GAME  PAUSED", textX, textY, fontSizeHeadline, "O" )
    myFont:End()
    
    glPopMatrix()
    
    
    --draw logo
    glPushMatrix()
    glColor(  iconColor )
    glTexture( ":n:" .. windowIconPath )
    glTranslate(-winSizeX*(usedSizeMultiplier-1)/2,  -winSizeY*(usedSizeMultiplier-1)/2, 0)
    glScale(usedSizeMultiplier,usedSizeMultiplier,1)
    
    if ( diffPauseTime <= slideTime ) then
        --we are sliding
        if ( paused ) then
            --sliding in
            glTranslate( 0,  (( yCenter + imgWidthHalf ) / usedSizeMultiplier) * ( 1 - ( diffPauseTime / slideTime ) ), 0)
        else
            --sliding out
            glTranslate( 0, ( (yCenter + imgWidthHalf ) / usedSizeMultiplier) * ( diffPauseTime / slideTime ), 0)
        end
    elseif (autoFade or forceHideWindow) and not autoFadeTimestamp then
        autoFadeTimestamp = osClock()
    end
    
    glTexRect( xCut - imgWidthHalf, yCenter + imgWidthHalf, xCut + imgWidthHalf, yCenter - imgWidthHalf, 0.0, 0.0, imgTexCoordX, imgTexCoordY )
    glPopMatrix()
    ResetGl()
end

function updateWindowCoords()
    screenx, screeny = widgetHandler:GetViewSizes()
    
    screenCenterX = screenx / 2
    screenCenterY = screeny / 2
    wndX1 = screenCenterX - boxWidth
    wndY1 = screenCenterY + boxHeight
    wndX2 = screenCenterX + boxWidth
    wndY2 = screenCenterY - boxHeight

    textX = wndX1 + ( wndX2 - wndX1 ) * 0.33
    textY = wndY2 + ( wndY1 - wndY2 ) * 0.4
    lineOffset = ( wndY1 - wndY2 ) * 0.32
    
    yCenter = wndY2 + ( wndY1 - wndY2 ) * 0.5
    xCut = wndX1 + ( wndX2 - wndX1 ) * (imgWidth * 0.00165)
end

function widget:ViewResize(viewSizeX, viewSizeY)
  updateWindowCoords()
 end

--Commons
function ResetGl()
    glScale(1,1,1)
    glColor( { 1.0, 1.0, 1.0, 1.0 } )
    glLineWidth( 1.0 )
    glDepthTest(false)
    glTexture(false)
end

function widget:GetConfigData(data)
    savedTable = {}
    savedTable.autoFade = autoFade
    return savedTable
end

function widget:SetConfigData(data)
    if data.autoFade ~= nil     then  autoFade    = data.autoFade end
end

function widget:TextCommand(command)
    if (string.find(command, "pausescreen_autofade") == 1  and  string.len(command) == 20) then 
        autoFade = not autoFade
        if autoFade then
            Spring.Echo("Pause screen:  Autofade on")
        else
            Spring.Echo("Pause screen:  Autofade off")
        end
    end
end
