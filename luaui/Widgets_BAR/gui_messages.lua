function widget:GetInfo()
    return {
        name      = "Messages",
        desc      = "Typewrites messages at the center-bottom of the screen",
        author    = "Floris",
        date      = "September 2019",
        license   = "GNU GPL, v2 or later",
        layer     = 0,
        enabled   = true
    }
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- Widgets can call: WG['messages'].addMessage('message text')
-- Gadgets (unsynced) can call: Script.LuaUI.GadgetAddMessage('message text')
-- plain text (without markup) via: /addmessage message text

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local charSize = 17
local charDelay = 0.015
local maxLines = 7
local maxLinesScroll = 10
local lineTTL = 15

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local fontfile = LUAUI_DIRNAME .. "fonts/" .. Spring.GetConfigString("bar_font", "Poppins-Regular.otf")
local vsx,vsy = Spring.GetViewGeometry()
local fontfileScale = (0.5 + (vsx*vsy / 5700000))
local fontfileSize = 34
local fontfileOutlineSize = 7.5
local fontfileOutlineStrength = 1.7
local font = gl.LoadFont(fontfile, fontfileSize*fontfileScale, fontfileOutlineSize*fontfileScale, fontfileOutlineStrength)

local vsx, vsy = gl.GetViewSizes()
local widgetScale = (0.5 + (vsx*vsy / 5700000))

local glPopMatrix      = gl.PopMatrix
local glPushMatrix     = gl.PushMatrix
local glDeleteList     = gl.DeleteList
local glCreateList     = gl.CreateList
local glCallList       = gl.CallList
local glTranslate      = gl.Translate

local messageLines = {}
local currentLine = 0
local scrolling = false

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function lines(str)
    local t = {}
    local function helper(line) t[#t+1] = line return "" end
    helper((str:gsub("(.-)\r?\n", helper)))
    return t
end

local vsx, vsy = widgetHandler:GetViewSizes()
function widget:ViewResize(n_vsx,n_vsy)
    vsx,vsy = Spring.GetViewGeometry()
    widgetScale = (0.5 + (vsx*vsy / 5700000))

    local newFontfileScale = (0.5 + (vsx*vsy / 5700000))
    if (fontfileScale ~= newFontfileScale) then
        fontfileScale = newFontfileScale
        gl.DeleteFont(font)
        font = gl.LoadFont(fontfile, fontfileSize*fontfileScale, fontfileOutlineSize*fontfileScale, fontfileOutlineStrength)
    end
end

function addMessage(text)
    if text then
        local textLines = lines(text)
        for i, line in ipairs(textLines) do
            --local lineWidth, _, _ = font:GetTextWidth(line)   -- todo: limit line width
            messageLines[#messageLines+1] = {
                os.clock(),  -- will be refreshed after every update
                line,
                string.len(line),
                0,  -- num typed chars
                0,  -- time passed during typing chars (used to calc 'num typed chars')
                glCreateList(function() end),
                0   -- num chars the displaylist contains
            }
        end
        -- update currentline to start typewriting
        if not messageLines[currentLine] or messageLines[currentLine][4] >= messageLines[currentLine][3] then
            currentLine = currentLine + 1
            if currentLine > #messageLines then
                currentLine = #messageLines
            end
        end
    end
end

function widget:Initialize()
    widgetHandler:RegisterGlobal('GadgetAddMessage', addMessage)
    WG['messages'] = {}
    WG['messages'].addMessage = function(text)
        addMessage(text)
    end
    -- test msg
    --if Spring.GetGameFrame() < 30 then
    addMessage("\255\230\255\200Commander,\nWe're in a peculiar situation so you have to begin on your own...\nInitiate a base and we'll redirect reinforcements right after...")
    --end
end

local sec = 0
local testmessaged = 0
function widget:Update(dt)
    sec = sec + dt
    if testmessaged < 1 and sec > 3.5 then
        testmessaged = 1
        addMessage("\nStandby we will keep you updated.\nGood luck!")
    end
    if testmessaged < 2 and sec > 12 then --and Spring.GetGameFrame() < 30*11 then
        testmessaged = 2
        addMessage("\n\nEnemies have been detected in your vicinity!\nBetter expand quick.")
    end

    if messageLines[currentLine] ~= nil then

        -- continue typewriting line
        if messageLines[currentLine][4] <= messageLines[currentLine][3] then
            messageLines[currentLine][5] = messageLines[currentLine][5] + dt
            messageLines[currentLine][4] = math.ceil(messageLines[currentLine][5]/charDelay)

            -- typewrite next line when complete
            if messageLines[currentLine][4] >= messageLines[currentLine][3] then
                currentLine = currentLine + 1
                if currentLine > #messageLines then
                    currentLine = #messageLines
                end
            end
        end
    end
end


function widget:DrawScreen()
    if messageLines[currentLine] then
        glPushMatrix()
        glTranslate((vsx * 0.31), (vsy * 0.133), 0)
        local displayedLines = 0
        local i = currentLine
        local now = os.clock()
        local usedMaxLines = maxLines
        if scrolling then
            usedMaxLines = maxLinesScroll
        end
        while i > 0 do
            glTranslate(0, (charSize*1.15*widgetScale), 0)
            if scrolling or now - messageLines[i][1] < lineTTL then
                if messageLines[i][4] ~= messageLines[i][7] then
                    messageLines[i][7] = messageLines[i][4]
                    local text = string.sub(messageLines[i][2], 1, messageLines[i][4])
                    messageLines[i][1] = now
                    glDeleteList(messageLines[i][6])
                    messageLines[i][6] = glCreateList(function()
                        font:Begin()
                        font:Print(text, 0, 0, charSize*widgetScale, "o")
                        font:End()
                    end)
                end
                glCallList(messageLines[i][6])
            end
            displayedLines = displayedLines + 1
            if displayedLines >= usedMaxLines then
                break
            end
            i = i - 1
        end
        glPopMatrix()
    end
end


function widget:GameOver()
    widgetHandler:RemoveWidget(self)
end


function widget:Shutdown()
    WG['messages'] = nil
    gl.DeleteFont(font)
    for i, _ in ipairs(messageLines) do
        if messageLines[i][6] then
            glDeleteList(messageLines[i][6])
        end
    end
end


function widget:TextCommand(command)
    if string.sub(command,1, 11) == "addmessage " then
        addMessage(string.sub(command, 11))
    end
end