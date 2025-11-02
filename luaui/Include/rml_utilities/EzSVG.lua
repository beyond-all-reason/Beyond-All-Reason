--[[
Copyright (c) 2012 Patrick Borgeat

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

Except as contained in this notice, the name(s) of the above copyright holders
shall not be used in advertising or otherwise to promote the sale, use or
other dealings in this Software without prior written authorization.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
]]--

local EzSVG = {}

EzSVG.knownTags = {
    "rect", "circle", "ellipse", "line",
    "polyline", "polygon", "path", "text",
    "tspan", "textPath", "image", "svg", "g",
    "defs", "tref", "linearGradient", "radialGradient",
    "stop", "use", "symbol", "pattern", "mask"
}

EzSVG.styleStack = {}

local function countElements(tbl)
    local num = 0
    for _, _ in pairs(tbl) do num = num + 1 end
    return num
end

local function mergeTable(dst, src)
    for k, v in pairs(src) do
        if not dst[k] then  dst[k] = src[k] end
    end
    return dst
end

local function overwriteTable(dst, src)
    for k, v in pairs(src) do
        dst[k] = src[k]
    end
    return dst
end

local function updashStyleTable(tbl)
    local ret = {}
    for k, v in pairs(tbl) do
        local nk = string.gsub(k, "_", "-")
        
        if k ~= nk then ret[nk] = v
        else ret[k] = v end
    end
    
    return ret
end

local function serializableValue(k, v)
    if type(v) == "function" then return false end
    if type(k) == "number" then return true end
    if string.sub(k, 1, k.len("__")) == "__" then return false end
    return true
end

local function processPropertyValues(tbl, run)
    for k,v in pairs(tbl) do
        if serializableValue(k, v) then
            if v ~= "" and v ~= nil then
                if type(v) == "table" then
                    tbl[k] = v:__propertyValue(k, run)
                end   
            end
        end
    end
end

local function defaultGenerateFunction(tbl, run)
    
    if run.preflight then
        processPropertyValues(tbl, run)
        processPropertyValues(tbl["__style"], run)
    end

    local pre = string.format("<%s ", tbl["__tag"])
    local post = "/>"
    
    if tbl["__content"] then
        post = string.format(">%s</%s>", tbl["__content"]:__generate(run), tbl["__tag"])
    end
    
    if tbl["__transform"] then
        tbl[tbl["__transformProperty"]] = tbl["__transform"]:__generate(run)
    end

    local ret = pre    
    
    if not run.preflight then
        for k,v in pairs(tbl) do
            if serializableValue(k, v) then
                if v ~= "" and v ~= nil then
                    ret = string.format("%s%s=%q ", ret, k, tostring(v))
                end
            end
        end
        
        for k,v in pairs(tbl["__style"]) do
            if serializableValue(k, v) then
                if v ~= "" and v ~= nil and tbl[k] == nil then
                    ret = string.format("%s%s=%q ", ret, k, tostring(v))
                end
            end
        end
        
        if tbl["__lastRunID"] ~= run["id"] and tbl["__id"] then
            ret = string.format("%sid=%q", ret, tbl["__id"])
        end
    end
        
    ret = ret .. post
    
    run["numObjects"]  = run["numObjects"] + 1
    tbl["__lastRunID"] = run["id"]
    
    return ret
end

local function transformGenerateFunction(tbl, run)

    if run.preflight then return "" end

    local ret = ""
    local seperator = ""
    
    for k, v in pairs(tbl["__functions"]) do
        if serializableValue(k, v) then
            local func = ""
            for i, vv in pairs(v) do
                if i == 1 then func = string.format("%s%s(", func, vv)
                elseif i == 2 then func = func .. vv
                else func = string.format("%s, %s", func, vv) end
            end
            ret = string.format("%s%s%s)", ret, seperator, func)
            seperator = "  "
        end
    end
    
    return ret
end

local function defaultPropertyValueFunction(tbl, key, run)
    local registerReference = function()
        if run then
            table.insert(run["referencedObjects"], tbl)
        end       
    end
    
    if key == "xlink:href" then
        registerReference()
        return tbl:getRef()
    end
    
    if key == "stroke" or key == "fill" then
        registerReference()
        return tbl:getURLRef()
    end
    
    if key == "mask" then
        registerReference()
        return tbl:getURLRef()
    end
    
    return tostring(tbl)
end

local function createStyleTable(tag, style, doInherit)
    local ret = {}
    
    if style then
        style = updashStyleTable(style)
        mergeTable(ret, style)
    end
        
    if doInherit then mergeTable(ret, EzSVG.styles[tag]) end
    
    -- ret["__generate"] = styleGenerateFunction
    
    return ret
end

local function attachTransformFunctions(tbl)
    tbl["rotate"] = function(tbl, angle, cx, cy)
        table.insert(tbl["__transform"]["__functions"], {"rotate", angle, cx, cy})
        return tbl
    end
    
    tbl["translate"] = function(tbl, x, y)
        table.insert(tbl["__transform"]["__functions"], {"translate", x, y})
        return tbl
    end
    
    tbl["scale"] = function(tbl, sx, sy)
        table.insert(tbl["__transform"]["__functions"], {"scale", sx, sy})
        return tbl
    end
    
    tbl["skewX"] = function(tbl, angle)
        table.insert(tbl["__transform"]["__functions"], {"skewX", angle})
        return tbl
    end
    
    tbl["skewY"] = function(tbl, angle)
        table.insert(tbl["__transform"]["__functions"], {"skewY", angle})
        return tbl
    end
    
    tbl["matrix"] = function(tbl, a, b, c, d, e, f)
        table.insert(tbl["__transform"]["__functions"], {"matrix", a, b, c, d, e, f})
        return tbl
    end
    
    tbl["__transformProperty"] = "transform"
end

local function attachStyleFunctions(tbl)
    tbl["setStyle"] = function(tbl, key, value)
        if type(key) == "table" then
            key = updashStyleTable(key)
            overwriteTable(tbl["__style"], key)
        else
            key = string.gsub(key, "_", "-")
            tbl["__style"][key] = value
        end
        
        return tbl
    end
    
    tbl["mergeStyle"] = function(tbl, key, value)
        if type(key) == "table" then
            key = updashStyleTable(key)
            mergeTable(tbl["__style"], key)
        else
            if not tbl["__style"][key] then
                tbl["__style"][key] = value
            end
        end
        return tbl
    end
    
    tbl["clearStyle"] = function(tbl)
        tbl["__style"] = createStyleTable(tbl["__tag"], nil, false)
        return tbl
    end
end

local function createTransformTable()
    local ret = {}
    
    ret["__functions"] = {}
    ret["__generate"] = transformGenerateFunction
    
    return ret
end

local currentUniqueID = 1000
local function nextUniqueID()
    currentUniqueID = currentUniqueID + 1
    return currentUniqueID
end

local function createTagTable(tag, style)
    local ret = {}
    
    ret["__tag"] = tag
    ret["__style"] = createStyleTable(tag, style, true)
    ret["__transform"] = createTransformTable()
    ret["__generate"] = defaultGenerateFunction
    
    attachTransformFunctions(ret)
    attachStyleFunctions(ret)
    
    local assureID = function(tbl)
        if not tbl["__id"] then
            tbl:setID("auto-unique-"..nextUniqueID())
        end
    end
    
    ret["setID"] = function(tbl, id)
        tbl["__id"] = id
        return tbl
    end
    
    ret["getID"] = function(tbl) return tbl["__id"] end
    
    ret["getRef"] = function(tbl)
        assureID(tbl)
        return "#" .. tbl["__id"]
    end
    
    ret["getURLRef"] = function(tbl)
        assureID(tbl)
        return "url(#" .. tbl["__id"] .. ")"
    end
    
    ret["__propertyValue"] = defaultPropertyValueFunction
    
    return ret
end

local function createContentTable(content)
    local ret = {}
    ret["__text"] = content
    ret["__generate"] = function(tbl, run)
        return tbl["__text"]
    end
    
    return ret
end

local function createGroupTable(tag, style)
    local ret = createTagTable(tag, style)
    ret["__content"] = {}
    
    ret["__content"]["__generate"] = function(tbl, run)
        local stringTable = {}
        for k, v in pairs(tbl) do
            if serializableValue(k, v) then
                table.insert(stringTable, v:__generate(run))
            end
        end
        return table.concat(stringTable, " ")
    end
    
    ret["add"] = function(tbl, item)
        table.insert(tbl["__content"], item)
    end
    
    return ret
end

local function setDefaultStyles(key, value, tag)
    if tag then
        EzSVG.styles[string.lower(tag)][key] = value
    else
        for _, v in pairs(EzSVG.styles) do
            v[key] = value
        end
    end
end

function EzSVG.clearStyle()
    EzSVG.styles = {}
    for _, v in pairs(EzSVG.knownTags) do
        EzSVG.styles[v] = {}
    end
end

function EzSVG.pushStyle()
    -- copy all styles
    -- metatables could do the trick too I suppose
    local style = {}
    for k, v in pairs(EzSVG.styles) do
        style[k] = {}
        for kk, vv in pairs(v) do
            style[k][kk] = vv
        end
    end
    table.insert(EzSVG.styleStack, style)
end

function EzSVG.popStyle()
    if #EzSVG.styleStack < 1 then
        error("Style Stack Underflow!")
    else
        EzSVG.styles = table.remove(EzSVG.styleStack)
    end
end

function EzSVG.setStyle(key, value, tag)
    if type(key) == "table" then
        key = updashStyleTable(key)
        tag = value -- promote
        for k, v in pairs(key) do
            setDefaultStyles(k, v, tag)
        end
    elseif type(key) == "string" then
        key = string.gsub(key, "_", "-")
        setDefaultStyles(key, value, tag)
    end
end


function EzSVG.Circle(cx, cy, r, style)
    local ret = createTagTable("circle", style)
    ret["cx"] = cx
    ret["cy"] = cy
    ret["r"] = r
    
    return ret
end

function EzSVG.Ellipse(cx, cy, rx, ry, style)
    local ret = createTagTable("ellipse", style)
    ret["cx"] = cx
    ret["cy"] = cy
    ret["rx"] = rx
    ret["ry"] = ry
    
    return ret
end

function EzSVG.Line(x1, y1, x2, y2, style)
    local ret = createTagTable("line", style)
    ret["x1"] = x1
    ret["y1"] = y1
    ret["x2"] = x2
    ret["y2"] = y2

    return ret
end

function EzSVG.Path(style)
    local ret = createTagTable("path", style)
    
    ret["__d"] = {}
    ret["__generate"] = function(tbl, run)
        local d = ""
        
        if not run.preflight then        
            local seperator = ""
            for k, v in pairs(tbl["__d"]) do
                if serializableValue(k, v) then
                    d = d .. seperator .. v
                    seperator = " "
                end
            end
        end
        
        tbl["d"] = d
        
        return defaultGenerateFunction(tbl, run)
    end
    
    ret["clear"] = function(tbl)
        tbl["__d"] = {}
        return tbl
    end
    
    -- Spagetti code ahead. Not sure if I'm gonna refactor.
    -- Beware: Order of arguments is not like in SVG.
    -- Destination x/y are always first argument.
    
    ret["moveTo"] = function(tbl, x, y)
        table.insert(tbl["__d"], "m"..x..","..y)
        return tbl
    end
    
    ret["moveToA"] = function(tbl, x, y)
        table.insert(tbl["__d"], "M"..x..","..y)
        return tbl
    end
    
    ret["lineTo"] = function(tbl, x, y)
        table.insert(tbl["__d"], "l"..x..","..y)
        return tbl
    end
    
    ret["lineToA"] = function(tbl, x, y)
        table.insert(tbl["__d"], "L"..x..","..y)
        return tbl
    end
    
    ret["hLineTo"] = function(tbl, x)
        table.insert(tbl["__d"], "h"..x)
        return tbl
    end
    
    ret["hLineToA"] = function(tbl, x)
        table.insert(tbl["__d"], "H"..x)
        return tbl
    end
    
    ret["vLineTo"] = function(tbl, y)
        table.insert(tbl["__d"], "v"..y)
        return tbl
    end
    
    ret["vLineToA"] = function(tbl, y)
        table.insert(tbl["__d"], "V"..y)
        return tbl
    end
    
    ret["curveTo"] = function(tbl, x, y, x1, y1, x2, y2)
        table.insert(tbl["__d"], "c"..x1..","..y1.." "..x2..","..y2.." "..x..","..y)
        return tbl
    end
    
    ret["curveToA"] = function(tbl, x, y, x1, y1, x2, y2)
        table.insert(tbl["__d"], "C"..x1..","..y1.." "..x2..","..y2.." "..x..","..y)
        return tbl
    end
    
    ret["sCurveTo"] = function(tbl, x, y, x2, y2)
        table.insert(tbl["__d"], "s"..x2..","..y2.." "..x..","..y)
        return tbl
    end
    
    ret["sCurveToA"] = function(tbl, x, y, x2, y2)
        table.insert(tbl["__d"], "S"..x2..","..y2.." "..x..","..y)
        return tbl
    end
    
    ret["qCurveTo"] = function(tbl, x, y, x1, y1)
        table.insert(tbl["__d"], "q"..x1..","..y1.." "..x..","..y)
        return tbl
    end
    
    ret["qCurveToA"] = function(tbl, x, y, x1, y1)
        table.insert(tbl["__d"], "Q"..x1..","..y1.." "..x..","..y)
        return tbl
    end
    
    ret["sqCurveTo"] = function(tbl, x, y)
        table.insert(tbl["__d"], "t"..x..","..y)
        return tbl
    end
    
    ret["sqCurveToA"] = function(tbl, x, y)
        table.insert(tbl["__d"], "T"..x..","..y)
        return tbl
    end
    
    ret["archTo"] = function(tbl, x, y, rx, ry, rotation, largeFlag, sweepFlag)
        largeFlag = largeFlag or 0
        sweepFlag = sweepFlag or 0 -- check if this makes sense
        table.insert(tbl["__d"],
            "a"..rx..","..ry.." "..rotation.." "..
            largeFlag..","..sweepFlag.." "..x..","..y
        )
        return tbl
    end
    
    ret["archToA"] = function(tbl, x, y, rx, ry, rotation, largeFlag, sweepFlag)
        largeFlag = largeFlag or 0
        sweepFlag = sweepFlag or 0 -- check if this makes sense
        table.insert(tbl["__d"],
            "A"..rx..","..ry.." "..rotation.." "..
            largeFlag..","..sweepFlag.." "..x..","..y
        )
        return tbl
    end
        
    ret["close"] = function(tbl)
        table.insert(tbl["__d"], "Z")
        return tbl
    end
    
    return ret
end

local function createPointsTagTable(tag, points, style)
    local ret = createTagTable(tag, style)
    
    points = points or {}
    
    ret["__points"] = mergeTable({}, points)
    ret["__generate"] = function(tbl, run)
        local points = ""
        local i = 0
        for _, v in pairs(tbl["__points"]) do
            if i ~= 0 then
                if i % 2 == 1 then points = points .. ","
                else points = points .. "  " end
            end
        
            points = points .. v
            i = i + 1 
        end
        tbl["points"] = points
        return defaultGenerateFunction(tbl, run)
    end
    
    ret["addPoint"] = function(tbl, x, y)
        table.insert(tbl["__points"], x)
        table.insert(tbl["__points"], y)
        return tbl
    end
    
    return ret    
end

function EzSVG.Polyline(points, style)
    return createPointsTagTable("polyline", points, style)
end

function EzSVG.Polygon(points, style)
    return createPointsTagTable("polygon", points, style)
end

function EzSVG.Rect(x, y, width, height, rx, ry, style)
    local ret = createTagTable("rect", style)
    
    ret["x"] = x
    ret["y"] = y
    ret["width"] = width
    ret["height"] = height
    ret["rx"] = rx
    ret["ry"] = ry
    
    return ret
end

function EzSVG.Image(href, x, y, width, height, style)
    local ret = createTagTable("image", style)
    
    ret["xlink:href"] = href
    ret["x"] = x
    ret["y"] = y
    ret["width"] = width
    ret["height"] = height
    
    return ret
end


local function createTextPathTable(href, text, style)
    local ret = createTagTable("textPath", style)
    
    ret["xlink:href"] = href
    ret["__content"] = text
    return ret
end

-- this somehow sucks!

function EzSVG.Text(text, x, y, style)
    local ret = createTagTable("text", style)
    
    local contentTable
    local contentContainer = ret
    
    ret["setText"] = function(tbl, text)
        if type(text) == "number" then text = tostring(text) end
        if type(text) == "string" then
            contentTable = createContentTable(text)
        else
            contentTable = text
        end
        contentContainer["__content"] = contentTable
        return tbl
    end
    
    ret:setText(text)
    
    ret["setPath"] = function(tbl, href, style)        
        contentContainer = createTextPathTable(href, contentTable, style)
        tbl["__content"] = contentContainer
        return tbl
    end
    
    ret["clearPath"] = function(tbl)
        tbl["__content"] = contentTable
        contentContainer = tbl
        return tbl
    end
    
    
    ret["x"] = x
    ret["y"] = y
        
    return ret
end

function EzSVG.TextRef(href, style)
    local ret = createTagTable("tref", style)    
    ret["xlink:href"] = href
    
    return ret
end

function EzSVG.Group(style)
    local ret = createGroupTable("g", style)
    return ret
end

local function numberToPercent(number)
    if type(number) == "number" then
        number = number.."%"
    end
    return number
end

local function validUnitsValue(value)
    if value == "userSpaceOnUse" or value == "objectBoundingBox" then
        return value
    end
    return false
end

local function createGradientTable(tag, userSpaceUnits, spread, style)
    local ret = createGroupTable(tag, style)
    
    ret["spreadMethod"] = spread
    
    ret["gradientUnits"] = validUnitsValue(userSpaceUnits) or "objectBoundingBox"

    
    ret["addStop"] = function(tbl, offset, color, opacity)
        local stop = createTagTable("stop")
        stop["offset"] = numberToPercent(offset)
        stop["stop-color"] = color
        stop["stop-opacity"] = opacity
        tbl:add(stop)
        return tbl
    end
    
    ret["__transformProperty"] = "gradientTransform"
    
    return ret
end

function EzSVG.LinearGradient(x1, y1, x2, y1, userSpaceUnits, spread,  style)
    local ret = createGradientTable("linearGradient", userSpaceUnits, spread, style)
    
    local process = numberToPercent
    if userSpaceUnits then process = function(arg) return arg end end
    
    ret["x1"] = process(x1)
    ret["y1"] = process(y1)
    ret["x2"] = process(x2)
    ret["y2"] = process(y2)
    
    return ret
end

function EzSVG.RadialGradient(cx, cy, r, fx, fy, userSpaceUnits, spread, style)
    local ret = createGradientTable("radialGradient", userSpaceUnits, spread, style)
    
    local process = numberToPercent
    if userSpaceUnits then process = function(arg) return arg end end
    
    ret["cx"] = process(cx)
    ret["cy"] = process(cy)
    ret["r"] =  process(r)
    ret["fx"] = process(fx)
    ret["fy"] = process(fy)
    
    return ret
end

function EzSVG.Use(href, x, y, width, height, style)
    local ret = createTagTable("use", style)
    
    ret["xlink:href"] = href
    ret["x"] = x
    ret["y"] = y
    ret["width"] = width
    ret["height"] = height
    
    return ret
end

function EzSVG.Symbol(preserveAspectRatio, viewBox, style)
    local ret createGroupTable("symbol", style)
    
    ret["preserveAspectRatio"] = preserveAspectRatio
    ret["viewBox"] = viewBox
    
    return ret
end

function EzSVG.Pattern(x, y, width, height, preserveAspectRatio, patternUnits, patternContentUnits, viewbox, style)
    local ret = createGroupTable("pattern", style)
    
    ret["x"] = x
    ret["y"] = y
    ret["width"] = width
    ret["height"] = height
    ret["preserveAspectRatio"] = preserveAspectRatio
    ret["patternUnits"] = validUnitsValue(patternUnits) or "objectBoundingBox"
    ret["patternContentUnits"] = validUnitsValue(patternContentUnits) or "userSpaceOnUse"
    ret["viewbox"] = viewbox
    
    ret["__transformProperty"] = "patternTransform"
    
    return ret
end

function EzSVG.Mask(x, y, width, height, maskUnits, maskContentUnits, style)
    local ret = createGroupTable("mask", style)
    
    ret["x"] = x
    ret["y"] = y
    ret["width"] = width
    ret["height"] = height
    ret["maskUnits"] = validUnitsValue(patternUnits) or "objectBoundingBox"
    ret["maskContentUnits"] = validUnitsValue(patternContentUnits) or "userSpaceOnUse"
    
    return ret
end

local function createDefs()
    local ret = createGroupTable("defs")
    return ret
end

local function attachDefsFunctions(tbl)
    local defs = createDefs()
    tbl:add(defs)
    
    tbl["addDef"] = function(tbl, def)
        defs:add(def)
    end
end

local currentRunID = 0
local function nextRunID()
    currentRunID = currentRunID + 1
    return currentRunID
end

function EzSVG.Document(width, height, bgcolor, style)
    local ret = createGroupTable("svg", style)
    
    ret["xmlns"] = "http://www.w3.org/2000/svg"
    ret["xmlns:xlink"] = "http://www.w3.org/1999/xlink"
    
    ret["width"] = width
    ret["height"] = height
    
    if bgcolor then
        ret:add(EzSVG.Rect(0, 0, width, height, 0, 0, {
            stroke=nil,
            fill=bgcolor
        }))
    end    
    
    ret.tostr = function(tbl)
    
        local createRun = function(pre)
            return {
                preflight= pre,
                referencedObjects= {},
                numObjects = 0,
                id= nextRunID()    
            }
        end
        
        preflightRun = createRun(true)
        finalRun     = createRun(false)
        
        tbl:__generate(preflightRun)
        
        -- sprint("Number of Objects: " .. preflightRun.numObjects)
        
        -- Put referenced objects not in the tree to <defs>
        for _, v in pairs(preflightRun["referencedObjects"]) do
            if v["lastRunID"] ~= preflightRun["id"] then
                tbl:addDef(v)
            end
        end
        
        return tbl:__generate(finalRun)
    end

    ret.writeTo = function(tbl, filename)
        local file = io.open(filename, "w")
        file:write(tbl:tostr())
        io.close(file)
    end
    
    attachDefsFunctions(ret)
    
    return ret
end

function EzSVG.SVG(x, y, width, height, style)
    local ret = createGroupTable("svg", style)
    
    ret["width"] = width
    ret["height"] = height
        
    ret["x"] = x
    ret["y"] = y
    
    attachDefsFunctions(ret)
    
    return ret
end

function EzSVG.rgb(r, g, b)
    return string.format("rgb(%d, %d, %d)", math.floor(r), math.floor(g), math.floor(b))
end

function EzSVG.gray(v)
    return EzSVG.rgb(v, v, v)
end

function EzSVG.hsv(h, s, v)

    h = h / 255
    s = s / 255
    v = v / 255

    h = h - math.floor(h)

    h = math.max(0, math.min(1, h))
    s = math.max(0, math.min(1, s))
    v = math.max(0, math.min(1, v))
    
    local hi = math.floor(h * 6.0)
    local f = (h * 6.0) - hi
    
    local p = v * (1.0 - s)
    local q = v * (1.0 - s * f)
    local t = v * (1.0 - s * (1.0 - f))
    
    local rgb = {v, t, p}
    
    if hi == 1 then
        rgb = {q, v, p}
    elseif hi == 2 then
        rgb = {p, v, t}
    elseif hi == 3 then
        rgb = {p, q, v}
    elseif hi == 4 then
        rgb = {t, p, v}
    elseif hi == 5 then
        rgb = {v, p, q}
    end
    
    return EzSVG.rgb(rgb[1] * 255, rgb[2] * 255, rgb[3] * 255)
end

-- init
EzSVG.clearStyle()

-- go!
return EzSVG
