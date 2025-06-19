function widget:GetInfo()
    return {
      name      = "Influence_version_5",
      desc      = "An overlay that shows influence of each player on the battlefield",
      author    = "Mr_Chinny",
      date      = "July 2024",
      --handler   = true,
      enabled   = true,
      layer = 0
    }
end
--xxx collectgarbage("count") xxx
--xxx graphs need an allyteam line divider.
--xxx graphs ticker to be added back (real time populate graph?)
--xxx graphs to use a shader rather than .gl lists? probably is ok as it is?
--xxx replay should be able to change colours from team to allyteams instantly - currently it only overwrites. I will need to store a full list of both colours (not change) every 10 frames or so
--xxx interesting deaths to be added back in.
--xxx interface
--xxx move / resize mini map
--xxx determine the best settings for dps/range (base more on metal rather than range)
--xxx sanity limit on number of players? (will this even work in 40v40?)
--xxx high memory use, optimise, test on potato.
--xxx test on raptors etc.
--xxx companion gadget logarythmic slowing down of frames recording in longer games, need to look more at best rates and also slow down replay to match this.


local runExtract = false
local notMoveCounter = 0
local oldNotMove = 0
local frameCounter = 1

local antispammer = false
----Essential Variables--------
---
local replayFrame = 1 -- saved frame number for replay (not game frame)
local newUnitListStatic = {}
local newUnitListMobile = {}
local deadUnitListAll = {}
local existingUnitListMobile = {}
local transferedUnitListAll = {}
local transportedUnitListStatic = {}
local teamAllyTeamIDs = {} --cache of teams key=teamids, data=allyteamids
local teamColourCache = {} --cache of team colours, key = teamid, data = {r,g,b}
local allyTeamColourCache = {} --cache of allyteamid colours (ie the captin of each allyteam's colour)
local minRange = 128 --lowest range used.
-----------Settings-----------
local onlyAllyTeamColours = false --if true, only allyteam colours will be displayed (EG Red Vs Blue in an 8v8), as opposed to all team colours.
local gridResolution = 128 --measured in map pixels. each performance roughly n^2
local spamDisabled = false
local storedCellList = {}
local mapSizeX = Game.mapSizeX -- eg 12288
local mapSizeZ = Game.mapSizeZ --eg 10240
local numberOfSquaresInX = mapSizeX/gridResolution
local numberOfSquaresInZ = mapSizeZ/gridResolution
local mmposX, mmposY, mmSizeX, mmSizeY, mmminimized, mmmaximized = Spring.GetMiniMapGeometry()
local mmScaleX = (mmSizeX/numberOfSquaresInX)
local mmScaleY = (mmSizeY/numberOfSquaresInZ)


----------Speed Ups---------------
local min, max = math.min, math.max
local floor, ceil = math.floor, math.ceil
local insert = table.insert


local gl_CreateList             = gl.CreateList
local gl_DeleteList             = gl.DeleteList
local gl_CallList               = gl.CallList
local glVertex                  = gl.Vertex
local glBeginEnd                = gl.BeginEnd
local glColor                   = gl.Color
local spGetTeamColor            = Spring.GetTeamColor
local UiUnit
local UiElement
--local orgIconTypes = VFS.Include("gamedata/icontypes.lua")


----Essential Variables--------

local storedUnitInfoList = {} -- store the important variables for each unitid {x = cx, z = cz, dps = dps, range=range, squares= squares, teamid = teamID, allyteamid = allyTeamID, udid = udID}
local CoordUpdateList = {}       -- List of coords that have seen a change, to run through
local gridList = {} --Main Master Table that will hold the influence. Consider changing name!
local stackAreaTeamList = {}
local stackAreaAllyTeamList = {}
local drawActiveCellsList = {}
local drawChangedCellsList = {} --list for cells that changed colour.
local fractionStackAreaAllyTeamList = {}
local fractionStackAreaTeamList = {}

local drawMiniMap = {}          ---A list of GLDraws divided into frames for End game display
local drawMiniMapIcons = {}

local drawStackedAreaGraphTeam
local drawStackedAreaGraphAllyTeam
local drawStackedAreaGraphAxis
local drawGraphCurrentFrameLine = {}
local drawGraphType = "team" --team of allyteam
local quickRefList = {} --{[unitdefID] = {squares, dps, range}, where squares is based on 0,0 position for translation
local intensityLookup = { --xxx these values need tweaking to get required contrast
    [10]        = 0.1, 
    [20]        = 0.1,
    [30]        = 0.1,
    [40]        = 0.2,
    [50]        = 0.3,
    [60]        = 0.3,
    [70]        = 0.3,
    [80]        = 0.35,
    [90]        = 0.4,
    [100]       = 0.5,
 }

--------Calculated Variables------
---cells---
local mapSizeX = Game.mapSizeX -- eg 12288
local mapSizeZ = Game.mapSizeZ --eg 10240
local numberOfSquaresInX = mapSizeX/gridResolution
local numberOfSquaresInZ = mapSizeZ/gridResolution
local gaiaTeamId                = Spring.GetGaiaTeamID()
local gaiaAllyTeamID = select(6, Spring.GetTeamInfo(gaiaTeamId, false))
local defaultdamagetag = Game.armorTypes['default'] --position that default is in on the weapon lists (0)

---Counters---
local updateCounter = 9999
local deathTimer = 25  -- how long an interesting units death it displayed, unit is in replayframes

local drawFrame = 1
local drawUpdateCounter = 0
local gameOver = true
---Drawing---
---
local drawer
local drawInfluence

---updating exclusion lists---
local excludeRange = {} --manually inputted. all stockpiling units except thor, also rag and calm. xxx legion, automate to check for weapon stockpiling
for i, name in ipairs({ "armjuno","corjuno","armemp","corantiship","corcarry","armamd","armmercury","cortron","armantiship","armcarry","armseadragon",
"cormabm","corjuno","corfmd","cordesolator","armsilo","corscreamer","armscab","corsilo", "armvulc","armbrtha","corbuzz","corint"}) do
    excludeRange[UnitDefNames[name].id] = true
end 
--local excludeUnits = { --Units to ignore completly,currently. all flying, plus rez bots .YYY change all to unitDefID rather than name.
--     [UnitDefNames["armrectr"].id]   = true,
--     [UnitDefNames["cornecro"].id]   = true, 
--     [UnitDefNames["cordrag"].id]    = true, 
--     [UnitDefNames["armdrag"].id]    = true,

--     --[UnitDefNames["corcom"].id]    = true
-- }
local isMexList =   {}
-- local spamUnits = {
--     [UnitDefNames["armflea"].id]    =true,
--     [UnitDefNames["armpw"].id]      =true,
--     [UnitDefNames["corak"].id]      =true,
--     [UnitDefNames["armfav"].id]     =true,
--     [UnitDefNames["corfav"].id]     =true
-- }--should probably automate this + legion. Is there a custom spam tag?

local bombersList ={} --air units that go on bombing runs
local interestingDeathsTypes ={} -- commanders, fusion, afus, rags 
local interestingDeathsList ={}
local interestingBuildingList = {}
local weaponlessBuilding = {}  --list of all non combat buildings. These need to be treated differently to give influence.

--xxx nuke icons?
for unitDefID, unitDef in pairs(UnitDefs) do
    -- if unitDef.canFly then --isBuilding or unitDef.speed == 0)
    --     excludeUnits[unitDefID] = true
    --     --YYY if bombertype then
    -- end
    if #unitDef.weapons == 0 then
        weaponlessBuilding[unitDefID] = true
    end
    if unitDef.customParams.metal_extractor then -- this should find all extractors
        isMexList[unitDefID]     = {dps = 20,  range = 400}
    end
    -- if unitDef.customParams.iscommander then
    --     interestingDeathsTypes[unitDefID]   = true
    --     iconTypes[unitDef.name] = orgIconTypes['armcom'].bitmap
    -- end
    -- if unitDef.name =='armafus' or unitDef.name =='corafus' or unitDef.name =='legafus' or unitDef.isFactory == true then --can i not hardcode the afus? xxx
    --     interestingDeathsTypes[unitDefID]   = true
    --     iconTypes[unitDef.name]             = orgIconTypes[unitDef.name].bitmap
    -- end

end

local excludeUnits = {} --units that we never track
local spamUnits = {} -- t1 units that need to be ignored once a limit is reached, to avoid overhead.
    for unitDefID, unitDef in pairs(UnitDefs) do
        if unitDef.customParams.techlevel == "1" then --tech 1
            if unitDef.speed > 0  then --xxx still showing up armdecoms (decoy commanders that level up)
                if unitDef.customParams.subfolder == "other/critters" or unitDef.customParams.subfolder == "other/hats" or unitDef.customParams.subfolder == "other/lootboxes" or unitDef.customParams.iscommander or unitDef.customParams.nohealthbars then
                else
                    spamUnits[unitDefID] = true
                end
            end
        end  
        if unitDef.customParams.fighter then -- air fighters
            excludeUnits[unitDefID] = true
            spamUnits[unitDefID] = nil
        elseif unitDef.customParams.drone then --air drones
            excludeUnits[unitDefID] = true
            spamUnits[unitDefID] = nil
        elseif unitDef.customParams.mine then --mines
            excludeUnits[unitDefID] = true
            spamUnits[unitDefID] = nil
        elseif unitDef.customParams.objectify then --walls
            excludeUnits[unitDefID] = true
            spamUnits[unitDefID] = nil
        end
    end

isMexList[UnitDefNames["cormoho"].id]    = {dps = 100, range = 600} --xxx don't hardcode
isMexList[UnitDefNames["armmoho"].id]    = {dps = 100, range = 600}

local quadVBO = nil
local gridInstanceVBO = nil
local gridShader = nil
local mmposX, mmposY, mmSizeX, mmSizeY, mmminimized, mmmaximized = Spring.GetMiniMapGeometry()

-- local luaShaderDir = "LuaUI/Include/"
-- local LuaShader = VFS.Include(luaShaderDir.."LuaShader.lua")
-- VFS.Include(luaShaderDir.."instancevbotable.lua")
local LuaShader = gl.LuaShader
local InstanceVBOTable = gl.InstanceVBOTable


local getMiniMapFlipped = VFS.Include("luaui/Include/minimap_utils.lua").getMiniMapFlipped

  local vsSrc =
  [[
    #version 420
    #line 10000
    uniform sampler2D heightmapTexture;
    uniform float mmSizeX;
    uniform float mmSizeY;
    uniform int numberOfSquaresInX;
    uniform int numberOfSquaresInZ;
    uniform int isMinimapRendering;
    uniform int flipMinimap;

    layout (location = 0) in vec4 quadPos;
    layout (location = 1) in vec4 instancePos;
    layout (location = 2) in vec4 color;
  
    out DataVS {
        vec4 v_color;
    };

    //__ENGINEUNIFORMBUFFERDEFS__
    #line 10500
    void main()
    {
        vec2 pos = vec2(floor((instancePos.x) / numberOfSquaresInZ), floor(mod(instancePos.x ,numberOfSquaresInZ))); //create x,y eg [12,24]

        if (isMinimapRendering == 1) {
            float mmSquareSize = (mmSizeX + 1) / numberOfSquaresInX;
            vec2 mmPos = vec2((quadPos.x + 1) / numberOfSquaresInX - 1, (quadPos.y - 1)  / numberOfSquaresInZ- 1);
            mmPos.xy += vec2 (pos.x / mmSizeX * mmSquareSize * 2, pos.y / mmSizeY * mmSquareSize * 2);
            if (flipMinimap == 0) {
                mmPos.y = -1.0 * mmPos.y;
            }
            gl_Position = vec4(mmPos.x,mmPos.y,0,1);
        }
        else {
        float squareResolution = mapSize.x / numberOfSquaresInX;
            vec4 worldPosition = vec4((quadPos.x + 1 ) * squareResolution * 0.5, 0.0, (quadPos.y - 1) * squareResolution * 0.5, 1.0);
            worldPosition.xz += pos.xy * squareResolution;
            
            vec2 heightmapUV = heightmapUVatWorldPos(worldPosition.xz);
            float terrainHeight = textureLod(heightmapTexture, heightmapUV, 0.0).x;
            
            worldPosition.y = terrainHeight + 500; //xxx not wokring
            
            gl_Position = cameraViewProj * worldPosition;
        }
        v_color = color;
        }
    ]]
  
  local fsSrc =
    [[
    #version 420
    #line 20000
    
    #extension GL_ARB_uniform_buffer_object : require
    #extension GL_ARB_shading_language_420pack: require
    
    //__ENGINEUNIFORMBUFFERDEFS__
    
    in DataVS {
        vec4 v_color;
    };
    
    out vec4 fragColor;
    
    void main(void)
    {
        fragColor = vec4(0.7,1.0,0.7,1); //debug!
        fragColor = vec4(v_color); //debug!
    }
    ]]




local function InitGL4()
	local engineUniformBufferDefs = LuaShader.GetEngineUniformBufferDefs()
	gridShader =  LuaShader(
	{
        vertex = vsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs),
        fragment = fsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs),
        uniformInt = {
            heightmapTexture = 0,
            numberOfSquaresInX = numberOfSquaresInX,
            numberOfSquaresInZ = numberOfSquaresInZ,
            },
	    uniformFloat = {
            mmSizeX = mmSizeX,
            mmSizeY = mmSizeY,
	    },
	}
  )
    local shaderCompiled = gridShader:Initialize()
    if not shaderCompiled then Spring.Echo("Failed to compile gridShader") end

    local quadVBO, numVertices = InstanceVBOTable.makeRectVBO(-1,-1,1,1,0,0,0,0,"quadVBO")
    local gridInstanceVBOLayout = {
        {id = 1, name = 'square', size = 4}, -- grid index, not used, not used, not used
        {id = 2, name = 'color', size = 4}, --- color rgba
    }
    gridInstanceVBO = InstanceVBOTable.makeInstanceVBOTable(gridInstanceVBOLayout,nil, "rectInstanceVBO") --xxx 6 may be total square, hense 10000...
    gridInstanceVBO.numVertices = numVertices
    gridInstanceVBO.vertexVBO = quadVBO
    gridInstanceVBO.VAO = InstanceVBOTable.makeVAOandAttach(gridInstanceVBO.vertexVBO, gridInstanceVBO.instanceVBO)
    gridInstanceVBO.primitiveType = GL.TRIANGLES
    gridInstanceVBO.indexVBO = InstanceVBOTable.makeRectIndexVBO()
    gridInstanceVBO.VAO:AttachIndexBuffer(gridInstanceVBO.indexVBO)
    return shaderCompiled
end

local function CacheTeams()
    for _, allyTeamID in ipairs(Spring.GetAllyTeamList()) do
        local lowest_teamID = 9999
        for _, teamID in ipairs(Spring.GetTeamList(allyTeamID)) do
            if teamID < lowest_teamID then
                lowest_teamID = teamID
            end
            teamAllyTeamIDs[teamID] = allyTeamID
        end
        allyTeamColourCache[allyTeamID] = {spGetTeamColor(lowest_teamID)}
    end

    teamColourCache = {}
    for teamID,allyTeamID in pairs(teamAllyTeamIDs) do
        teamColourCache[teamID] = {spGetTeamColor(teamID)}
    end
    

end

local function CheckForSkippables(allyTeamID, udID)
    local skippable = false
    if allyTeamID == gaiaAllyTeamID then
        skippable = true
    elseif excludeUnits[udID] then
        skippable = true
    elseif spamDisabled then
            if spamUnits[udID] then
                skippable = true
            end
    end 
    return skippable
end


local function CoordToGridXZ(n)
    return math.floor((n - 1) / numberOfSquaresInZ), (n - 1) % numberOfSquaresInZ
end

local function GridXYtoCoord(x,z) --[0,0] = 1 [0,1] = 2, [0,95] = 96, [1,0] = 97
        return (x * numberOfSquaresInZ) + z + 1
end

local function PopulateGridNew() ---Primes the gridList with: [coords]. Also populates team color for 2 colour games. Ran once only at game start
    local coord = 1 --starting at one because lua
    local vertexCount = 0
    for x=0, numberOfSquaresInX - 1 do
        for z = 0, numberOfSquaresInZ - 1 do
            --gridList[coord] = {}
            --vertexList[coord] = MakeWorldVertexList(coord,x,z)
            coord = coord + 1
            vertexCount = vertexCount + 1
            local instanceData = {
                vertexCount,0,0,0, --n,unused,unused,unused
                0,  0,  0,  0 --rgba
            }
            InstanceVBOTable.pushElementInstance(gridInstanceVBO, instanceData, vertexCount , true, false)
        end
    end
end

---squares within range---

local function TranslateSquares(squares,transX,transZ)
    local translatedSquareTable = {}
    local gridX, gridZ
    for i,coord in pairs(squares) do
        gridX, gridZ = coord.x + transX, coord.z + transZ
        if gridX < 0 or gridZ < 0 or gridX > numberOfSquaresInX-1 or gridZ > numberOfSquaresInZ-1 then  
        else
            translatedSquareTable[i] = {gridX,gridZ}
        end
    end
    return translatedSquareTable
end

local function SquaresInCircleForTranslating(cx, cz, r, grid_size)
    local squares = {}
    if not cx then
        Spring.Echo("Error 002, cx is nil",cx,cz,r,grid_size)
    end
    local squareIAmInX = floor(cx / grid_size)
    local squareIAmInZ = floor(cz / grid_size)
    local minX = floor((cx - r) / grid_size)
    local maxX = ceil ((cx + r) / grid_size)
    local minZ = floor((cz - r) / grid_size)
    local maxZ = ceil((cz + r) / grid_size)
    for x = minX, maxX do
        local square_center_x = x * grid_size + grid_size / 2
        for z = minZ, maxZ do
            local square_center_z = z * grid_size + grid_size / 2
            local dx = square_center_x - cx
            local dy = square_center_z - cz
            if dx * dx + dy * dy <= r * r then
                squares[#squares+1] = {x = x, z = z}
            end
            if squares == {} then --adds square we are in if not already done.
                squares = {{x = squareIAmInX, z = squareIAmInZ}}
                --insert(squares, {x = squareIAmInX, z = squareIAmInY})
            end
        end
    end
    return squares
end

local function TableDifferences(a,b) --Returns a list of of values. true means in a not b, false means in b not a.
    local a_inverse, b_inverse, differences = {},{},{}
    for k,v in pairs(a) do
        a_inverse[v] = k
    end
    for k,v in pairs(b) do
        if a_inverse[v] == nil then
            differences[v] =false
        end
        b_inverse[v] = k
    end
    for k,v in pairs(a) do
        if b_inverse[v] == nil then
            differences[v] = true
        end
    end
    return differences
end


------------------------

local function MakePolygonMap(x1,y1,x2,y2) --note i need to start in topleft corner and go round.
    glVertex(x1,y1)
	glVertex(x2,y1)
    glVertex(x2,y2)
	glVertex(x1,y2)
end

local function GetUnitStrengthWithUdID(udID) --run first time a UdID is encountered, and updates strength list
    --Spring.Echo("udID in GetUnitStrengthWithUdID:", udID, UnitDefs[udID].name)
    local unitDef = UnitDefs[udID]
    local range = minRange --min range xxx make variable?
    local dps = 5
    local translatableSquares = {}
    local normalUnit = true --normal unit is a static or mobile unit with a combat capabilities
    if excludeRange[udID] then
        normalUnit =  false
    elseif weaponlessBuilding[udID] then
        normalUnit = false
    end
    --this will determine influence value based on dps and weapon range 
    if unitDef.weapons and normalUnit == true then
        for _, weapon in ipairs(unitDef.weapons) do
            if weapon.weaponDef then
                local weaponDef = WeaponDefs[weapon.weaponDef]
                if weaponDef then
                    if weaponDef.canAttackGround and not (weaponDef.type == "Shield") then --maybe add more types to avoid?
                        local damage = weaponDef.damages[defaultdamagetag]
                        local reload = weaponDef.reload
                        if weaponDef.type == "BeamLaser" then
                            damage = damage/2
                        elseif weaponDef.type == "StarburstLauncher" then --expection for thor missles
                            damage = 100
                            range = minRange
                        end
                        local temp_dps = min(floor(damage / (reload or 1)),2000)--limit dgun power
                        if weaponDef.range > range and weaponDef.type ~= "StarburstLauncher" then --only update to biggest dps/range. may cause some funny behvaior for some units.
                            range = weaponDef.range
                        end
                        if temp_dps > dps then
                            dps = temp_dps
                        end
                    elseif weaponDef.canattackground == false then --This is all AA?
                        local metal =  UnitDefs[udID].metalCost + floor((UnitDefs[udID].energyCost / 70))
                        range = min(max(floor((metal / 10) + 0.5),minRange),1000) --this factor may need to be variable. xxx could simple add square and next squares rather than calculate
                        dps =  max(floor ((metal / 10) + 0.5),5)
                    end
                end
            end
        end
    elseif not normalUnit then --for units that need to be treated with separate dps
        if isMexList[udID] then  --treat mex differently to allow more map infulence
            dps = isMexList[udID].dps
            range = isMexList[udID].range
        else
            local metal =  UnitDefs[udID].metalCost + floor((UnitDefs[udID].energyCost / 70)) --everything without a weapon is based on metal cost
            range = min(max(floor((metal / 10) + 0.5),minRange),1000)
            dps =  max(floor ((metal / 10) + 0.5),5)
        end
    end
    if unitDef.speed > 0 then
        range = max(floor(range/1.41),minRange) --half area for mobile units!
    end
    translatableSquares = SquaresInCircleForTranslating(0 + (gridResolution/2), 0 + (gridResolution/2), range, gridResolution) --squares when at centre of position of 0,0
    quickRefList[udID] = {name = UnitDefs[udID].name, range = range, dps = dps, translatablesquares = translatableSquares, mobile = unitDef.speed}
end

local function PrimeGraphicalLists()
    if replayFrame == 1 then
        stackAreaAllyTeamList[replayFrame] = {cumStrength = 0} 
        stackAreaTeamList[replayFrame] = {cumStrength = 0}
        for teamID, allyTeamID in pairs(teamAllyTeamIDs) do --team+1 to make easily iterable ipairs.
            stackAreaTeamList[replayFrame][teamID] = 0
            if not stackAreaAllyTeamList[replayFrame][allyTeamID] then
                stackAreaAllyTeamList[replayFrame][allyTeamID] = 0
            end
        end 
    else
        stackAreaAllyTeamList[replayFrame] = stackAreaAllyTeamList[replayFrame-1]
        stackAreaTeamList[replayFrame] = stackAreaTeamList[replayFrame-1]
    end
    drawChangedCellsList[replayFrame] = {}
    --prime fraction lists (these are renewed every frame and updated from the non fraction list)
    fractionStackAreaTeamList[replayFrame] = {}
    fractionStackAreaAllyTeamList[replayFrame] = {}
    for teamID, allyTeamID in pairs(teamAllyTeamIDs) do --team+1 to make easily iterable ipairs.
        fractionStackAreaTeamList[replayFrame][teamID+1] = 0
        if not fractionStackAreaAllyTeamList[replayFrame][allyTeamID+1] then
        fractionStackAreaAllyTeamList[replayFrame][allyTeamID+1] = 0
        end
    end 
end

local function StackAreaListsNew(teamID,allyTeamID, strength, increase) --creates lists for stacked area graphs.
    if not increase then
        strength = strength * -1
    end

    stackAreaTeamList[replayFrame][teamID] = stackAreaTeamList[replayFrame][teamID] + strength
    stackAreaTeamList[replayFrame].cumStrength  = stackAreaTeamList[replayFrame].cumStrength + strength

    stackAreaAllyTeamList[replayFrame][allyTeamID] = stackAreaAllyTeamList[replayFrame][allyTeamID] + strength 
    stackAreaAllyTeamList[replayFrame].cumStrength = stackAreaAllyTeamList[replayFrame].cumStrength + strength
end

local function DrawMiniMapFrameNewNewNew(frameNumber)
    drawMiniMap[frameNumber] = gl_CreateList(function()
        for coord, colourData in pairs(drawActiveCellsList) do
            glColor(colourData[1],colourData[2],colourData[3],colourData[7])
            --local x,z = coordToGridXZ[coord][1],coordToGridXZ[coord][2]
            local x,z  = CoordToGridXZ(coord)

            local x1,x2 = x*mmScaleX, (x+1)*mmScaleX--can get these all once and read from table.
            local y1,y2 = z*mmScaleY*-1+mmSizeY, (z+1)*mmScaleY*-1+mmSizeY--can get these all once and read from table in vbo
            glBeginEnd(GL.POLYGON,MakePolygonMap, x1,y1,x2,y2)
        end
    end)
end

local function StoreReplayListNew(updateNumber)
    --DrawMiniMapFrameNewNewNew(updateNumber)
    if stackAreaTeamList[updateNumber].cumStrength >0 then
        for teamID, strength in pairs (stackAreaTeamList[updateNumber]) do
            if teamID ~= "cumStrength" then
                fractionStackAreaTeamList[updateNumber][teamID+1] = strength / stackAreaTeamList[updateNumber].cumStrength
            end
        end
        for allyTeamID, strength in pairs (stackAreaAllyTeamList[updateNumber]) do
            if allyTeamID ~= "cumStrength" then
                fractionStackAreaAllyTeamList[updateNumber][allyTeamID+1] = strength / stackAreaAllyTeamList[updateNumber].cumStrength
            end
        end
    end

end

--percentOwned,maxAllyTeamInfluenceValue,maxAllyTeamInfluenceID,allyTeamInfluenceList[maxAllyTeamInfluenceID].maxTeamInfluenceID
local function GetColourAndIntensityNew(percentOwned, strength, maxAllyTeamInfluenceID, maxTeamInfluenceID)
    -- if antispammer == false then
    --     Spring.Echo("teamColourCache[maxTeamInfluenceID]",teamColourCache[maxTeamInfluenceID])
    --     Spring.Echo("unpack(teamColourCache[maxTeamInfluenceID],1,3)",unpack(teamColourCache[maxTeamInfluenceID],1,3))
    -- antispammer = true
    -- end
    if percentOwned == 0 then
        return {0,0,0,0,0,0,0}
    end
    local teamR,teamG,teamB, allyTeamR, allyTeamG, allyTeamB, intensity = 0, 0, 0, 0, 0 ,0 ,0.6 --no man land colours
    if percentOwned > 60 then

        teamR,teamG,teamB = unpack(teamColourCache[maxTeamInfluenceID],1,3)
        allyTeamR, allyTeamG, allyTeamB = unpack(allyTeamColourCache[maxAllyTeamInfluenceID],1,3)   
        intensity = intensityLookup[percentOwned] + ((strength -1) / 10) --higher values will have slightly 
    end

    return {teamR,teamG,teamB, allyTeamR, allyTeamG, allyTeamB, intensity}
end

local function DrawStackedAreaGraph()
    local offsetX, offsetY, sizeX, sizeY = 300,400,600,600
    local boarderWidth = 20
    local posX = offsetX - boarderWidth
    local posXr = offsetX + sizeX + boarderWidth
    local posY = offsetY - boarderWidth
    local posYt = offsetY + sizeY + boarderWidth
    local screenRatio = 1
    local scaleX = sizeX / screenRatio
    local scaleY = sizeY / screenRatio
    local frameStreachFactor = 1
    frameStreachFactor =  ceil(replayFrame / sizeX)
    

    if replayFrame > 0 then
        scaleX = frameStreachFactor * sizeX / replayFrame
        --scaleX = floor(sizeX / (screenRatio * replayFrame * (frameStreachFactor) )) --replayframe needs to be the last frame, this is not dynamic.
    end
    
    drawStackedAreaGraphTeam = gl_CreateList(function()
        
        UiElement(posX ,posY,posXr,posYt,1,1,1,1, 1,1,1,1, .5, {0,0,0,0.5},{1,1,1,0.05},boarderWidth) --widget outline / Create background

        local counter = 0
        for frameNumber,data in pairs (fractionStackAreaTeamList) do
            local cumY = 0

            for teamID, fraction in ipairs(data) do
                if counter % frameStreachFactor == 0 then
                    local x1 = offsetX + ((frameNumber * scaleX))
                    local x2 = offsetX + ((frameNumber + 1) * scaleX)
                    local y1 = offsetY + sizeY - ((cumY * scaleY))
                    cumY =  cumY + fraction
                    local y2 = offsetY +sizeY - ((cumY * scaleY))
                    glColor(teamColourCache[teamID-1][1],teamColourCache[teamID-1][2],teamColourCache[teamID-1][3],1)
                    glBeginEnd(GL.POLYGON,MakePolygonMap, x1,y1,x2,y2)
                end
            end
            counter = counter + 1
        end
    end)

    drawStackedAreaGraphAllyTeam = gl_CreateList(function()
        
        UiElement(posX ,posY,posXr,posYt,1,1,1,1, 1,1,1,1, .5, {0,0,0,0.5},{1,1,1,0.05},boarderWidth) --widget outline / Create background

        local counter = 0
        for frameNumber,data in pairs (fractionStackAreaAllyTeamList) do
            local cumY = 0

            for allyTeamID, fraction in ipairs(data) do
                if counter % frameStreachFactor == 0 then
                    local x1 = offsetX + ((frameNumber * scaleX))
                    local x2 = offsetX + ((frameNumber + 1) * scaleX)
                    local y1 = offsetY + sizeY - ((cumY * scaleY))
                    cumY =  cumY + fraction
                    local y2 = offsetY +sizeY - ((cumY * scaleY))
                    glColor(allyTeamColourCache[allyTeamID-1][1],allyTeamColourCache[allyTeamID-1][2],allyTeamColourCache[allyTeamID-1][3],1)
                    glBeginEnd(GL.POLYGON,MakePolygonMap, x1,y1,x2,y2)
                end
            end
            counter = counter + 1
        end
    end)
    
    drawStackedAreaGraphAxis = gl_CreateList(function()
        local x1 = offsetX
        local x2 = offsetX + sizeX
        local y1 = (offsetY + (0.5 *sizeY)) - 1
        local y2 = (offsetY + (0.5 *sizeY)) + 1
        glColor(1,1,1,0.75)
        glBeginEnd(GL.POLYGON,MakePolygonMap, x1,y1,x2,y2)

    end)

    for frameNumber, _ in pairs (fractionStackAreaTeamList) do
        drawGraphCurrentFrameLine[frameNumber] = gl_CreateList(function()
            glColor(0.67,0.67,0.67,1)
            local x1 = offsetX + ((frameNumber * scaleX))
            local x2 = offsetX + ((frameNumber * scaleX) + 2)
            local y1 = offsetY
            local y2 = offsetY + sizeY
            glBeginEnd(GL.POLYGON,MakePolygonMap, x1,y1,x2,y2)
        end)
    end
end

--on calcinflu--
--if a gridcell changes, find colour, intensity and record change in a table[frame]. I don't actually need to store previous values anywhere as these are in gridlist.
--if a gridcell changes, need old owner/level and new owner level. add - subtract corresponding values to the stackareagraph data frame.
--the stackareagraphlist will need to be primed each frame with values from previous frame.
--will need a second table for allyteamstackedarea.
local function CalculateCellInfluenceNew(coord)

    CoordUpdateList[coord] = nil

    local maxTeamInfluenceID = nil
    local cumInfPerAllyTeamIDList = {}
    local maxInfTeamIDList = {}
    local maxInfTeamValueList = {}
    local cumAllInfluence = 0

    for teamID, influence in pairs(gridList[coord]) do --add up all influence of teams and sum to allyteams.
        local allyTeamID = teamAllyTeamIDs[teamID]
        if cumInfPerAllyTeamIDList[allyTeamID] then
            cumInfPerAllyTeamIDList[allyTeamID] = cumInfPerAllyTeamIDList[allyTeamID] + influence
            if influence > maxInfTeamValueList[allyTeamID] then
                maxInfTeamValueList[allyTeamID] = influence
                maxInfTeamIDList[allyTeamID] = teamID
            end
        else
            cumInfPerAllyTeamIDList[allyTeamID] = influence
            maxInfTeamValueList[allyTeamID] = influence
            maxInfTeamIDList[allyTeamID] = teamID
        end
        cumAllInfluence = cumAllInfluence + influence
    end

    --determine highest allyteam influence
    local maxAllyTeamInfluenceValue = 0
    local maxAllyTeamInfluenceID = nil
    
    for allyteamID, cumAllyTeamInfluence in pairs(cumInfPerAllyTeamIDList) do
        if cumAllyTeamInfluence > maxAllyTeamInfluenceValue then
            maxAllyTeamInfluenceValue = cumAllyTeamInfluence
            maxAllyTeamInfluenceID = allyteamID
        end
    end
    --lookup highest contributer teamID on the top allyTeamID
    maxTeamInfluenceID = maxInfTeamIDList[maxAllyTeamInfluenceID]

    --determine who is strongest, and by how much, by allyTeamInfluence. Relative difference is important here for colour and intensity.
    local percentOwned = 0

    if cumAllInfluence == 0 then --noone influences the cell, however it would have been owned previously so still need to run some functions.
        if storedCellList[coord] then
            drawChangedCellsList[replayFrame][coord] = {0,0,0,0,0,0,0} 
            --drawActiveCellsList[coord] = {0,0,0,0,0,0,0} 
            StackAreaListsNew(storedCellList[coord].maxTeamInfluenceID,storedCellList[coord].maxAllyTeamInfluenceID,storedCellList[coord].strength,false)
            storedCellList[coord] = nil
            gridList[coord] = nil
        else
            storedCellList[coord] = nil
        end

    else --add and remove
        local strength = 1
        if maxAllyTeamInfluenceValue >= 4000 then
            strength = 4
        elseif maxAllyTeamInfluenceValue >=2000 then
            strength = 3
        elseif maxAllyTeamInfluenceValue >=1000 then
            strength = 2
        end
    
        percentOwned = floor(((maxAllyTeamInfluenceValue/cumAllInfluence)*10)+0.5)*10 
        if percentOwned  < 10 then 
            percentOwned = 10 -- catches case where a square is so contested that no allyTeam has above 10% ownership (FFA only i guess)
        end
        local colours
        if storedCellList[coord] then --square is already owned by someone.
            if strength ~= storedCellList[coord].strength or maxTeamInfluenceID ~= storedCellList[coord].maxTeamInfluenceID or maxAllyTeamInfluenceID ~=  storedCellList[coord].maxAllyTeamInfluenceID then
                colours = GetColourAndIntensityNew(percentOwned,strength,maxAllyTeamInfluenceID, maxTeamInfluenceID)
                --drawChangedCellsList[replayFrame][coord] = GetColourAndIntensityNew(percentOwned,strength,maxAllyTeamInfluenceID, maxTeamInfluenceID)
                drawChangedCellsList[replayFrame][coord] = colours
                --drawActiveCellsList[coord] = colours
                StackAreaListsNew(maxTeamInfluenceID,maxAllyTeamInfluenceID,strength,true)
                StackAreaListsNew(storedCellList[coord].maxTeamInfluenceID,storedCellList[coord].maxAllyTeamInfluenceID,storedCellList[coord].strength,false)
                storedCellList[coord] = {maxAllyTeamInfluenceID = maxAllyTeamInfluenceID, maxTeamInfluenceID = maxTeamInfluenceID, strength = strength}
            end
        else
            colours = GetColourAndIntensityNew(percentOwned,strength,maxAllyTeamInfluenceID, maxTeamInfluenceID)
            drawChangedCellsList[replayFrame][coord] = colours
            --drawActiveCellsList[coord] = colours
            --drawChangedCellsList[replayFrame][coord] = GetColourAndIntensityNew(percentOwned,strength,maxAllyTeamInfluenceID, maxTeamInfluenceID)
            StackAreaListsNew(maxTeamInfluenceID,maxAllyTeamInfluenceID,strength,true)
            storedCellList[coord] = {maxAllyTeamInfluenceID = maxAllyTeamInfluenceID, maxTeamInfluenceID = maxTeamInfluenceID, strength = strength}
        end
    end
end


local function AddInfluence(coord,teamID,value) ---Adds a single unit's influence to single cell
    local dataCheck = gridList[coord]
    if not dataCheck then
        gridList[coord]= {[teamID] = value}
        --gridList[coord] = {}
        --gridList[coord][teamID] = value
        if antispammer ==false then
            Spring.Echo("antispammer:", gridList[coord], gridList[coord][teamID])
            
            antispammer =true
        end
        CoordUpdateList[coord] = true
        return
    end
    local data = gridList[coord][teamID]

    --local data = gridList[coord][teamID]
    if not data then
        gridList[coord][teamID] = value
        CoordUpdateList[coord] = true
    else
        gridList[coord][teamID] = data + value
        CoordUpdateList[coord] = true
    end
end

local function ReduceInfluence(coord,teamID,value) ---Reduces a single unit influence to single cell
    --Spring.Echo("coordData RI",coordData)
    --local coord = gridXYtoCoordCache[coordData[1]][coordData[2]]
    if not gridList[coord] then
        Spring.Echo("error302",coord,teamID,value)
    end
    if not gridList[coord][teamID] then
        Spring.Echo("error303",coord,teamID,value)
    end
    gridList[coord][teamID] = gridList[coord][teamID] - value
    CoordUpdateList[coord] = true
    --CoordUpdateList[coord] = false

    if gridList[coord][teamID] <-0.1 then --to allow for missing rounding? xxx
        Spring.Echo("reduced influence to below 0, shouldn't be possible",coord,"teamID",teamID,"value",value, "original value in Gridlist",gridList[coord][teamID]+ value)
        gridList[coord][teamID] = nil
        return "error"
    end
    -- remove from coordlist in the next step.
end

local function ProcessUnitAddOrRemove(unitID,udID,teamID,allyTeamID,posX,posZ,destroyed,calledFrom)
--{x = cx, z = cz, dps = dps, range=range, squares= squares, teamid = teamID, allyteamid = allyTeamID, udid = udID
    if not storedUnitInfoList[unitID] then
        local dps = quickRefList[udID].dps
        local gridCoordX = floor(posX/ gridResolution)
        local gridCoordZ = floor(posZ/ gridResolution)
        local squares = TranslateSquares(quickRefList[udID].translatablesquares,gridCoordX,gridCoordZ)
        local mobile = quickRefList[udID].mobile
        storedUnitInfoList[unitID] = {udID = udID, teamID = teamID, allyTeamID = allyTeamID, dps = dps, squares = squares, mobile = mobile, gridCoordX = gridCoordX, gridCoordZ = gridCoordZ, posX = posX, posZ = posZ, transporting = false }
    else
    end
    for i,coordData in pairs(storedUnitInfoList[unitID].squares) do
        
        if coordData[1] < 0 or coordData[1] >= numberOfSquaresInX or coordData[2] < 0 or coordData[2] >= numberOfSquaresInZ then --ignore if out of bounds
            --Spring.Echo("out of bounds",coordData[1],coordData[2])
        else
            --local coord = gridXYtoCoordCache[coordData[1]][coordData[2]]
            local coord = GridXYtoCoord(coordData[1],coordData[2])
            if not destroyed then
                if not coord then
                    Spring.Echo("coord",coord,coordData,GridXYtoCoord(coordData[1],coordData[2]))
                end
                AddInfluence(coord, storedUnitInfoList[unitID].teamID, storedUnitInfoList[unitID].dps)
            else
                if ReduceInfluence(coord, storedUnitInfoList[unitID].teamID, storedUnitInfoList[unitID].dps) == 'error' then
                    Spring.Echo("Error in reduce influence from Process:",calledFrom,unitID,UnitDefs[udID].name,storedUnitInfoList[unitID].squares )
                end   
            end
        end
    end 
end

local function ProcessUnitChangePositionNew(unitID,posX,posZ)
    -- if unitID == 23089 then
    --     Spring.Echo("23089 in changed position:",unitID,posX,posZ,storedUnitInfoList[unitID])
    -- end
    local unitData = storedUnitInfoList[unitID]
    if unitData then
        local gridCoordX = floor(posX/ gridResolution) --First check it has moved into a new Grid X or Grid Z, exit if it hasn't actually moved grid
        local gridCoordZ = floor(posZ/ gridResolution)
        if gridCoordX == unitData.gridCoordX and gridCoordZ == unitData.gridCoordZ then
            --Spring.Echo("unit had not moved grid.unitID/name:", unitID, UnitDefs[storedUnitInfoList[unitID].udID].name)
            return false
        end
        storedUnitInfoList[unitID].posX = posX
        storedUnitInfoList[unitID].posZ = posZ

        local dps = unitData.dps
        --local udID = unitData.udID
        --local teamID = unitData.teamID
        --local allyTeamID = unitData.allyTeamID
        --local oldSquares = unitData.squares
        local newSquares = TranslateSquares(quickRefList[unitData.udID].translatablesquares,gridCoordX,gridCoordZ)--xxx compare lists, reduce the amount of influence calls
        local changedSquares = TableDifferences(newSquares,unitData.squares)
        -- if unitID == 23089 then
        --     Spring.Echo("23089 in changedsquare:",changedSquares)
        --     Spring.Echo("23089 in new square:",newSquares)
        -- end
        for coordData,bool in pairs(changedSquares) do
            if coordData[1] < 0 or coordData[1] >= numberOfSquaresInX or coordData[2] < 0 or coordData[2] >= numberOfSquaresInZ then --ignore if out of bounds
                --Spring.Echo("out of bounds",coordData[1],coordData[2])
            else
                --local coord = gridXYtoCoordCache[coordData[1]][coordData[2]]
                local coord = GridXYtoCoord(coordData[1],coordData[2])
                notMoveCounter = notMoveCounter + 1
                
                if bool == true then
                    AddInfluence(coord, unitData.teamID, unitData.dps)
                else
                    if ReduceInfluence(coord, unitData.teamID, unitData.dps) == 'error' then
                        Spring.Echo("Error 020: in reduce influnene from Moved Unit Moving:",unitID,UnitDefs[unitData.udID].name,squares)
                    end
                end
            end
        end
        storedUnitInfoList[unitID].squares = newSquares
        storedUnitInfoList[unitID].gridCoordX = gridCoordX
        storedUnitInfoList[unitID].gridCoordZ = gridCoordZ
        return true
    else
        --Spring.Echo("Error 019: cannot find unit in storedUnitInfoList[unitID] ProcessUnitChangePosition()")    
    end
end

local function ProcessUnitTeamTransfer(unitID,oldTeamID,newTeamID)
    
    if oldTeamID ~= storedUnitInfoList[unitID].teamID then
        Spring.Echo("error 013: OLD TeamID does not match records")    
    end

    local oldTeamID = storedUnitInfoList[unitID].teamID
    local oldAllyTeamID = storedUnitInfoList[unitID].allyTeamID
    local newAllyTeamID = teamAllyTeamIDs[newTeamID]
    local dps = storedUnitInfoList[unitID].dps
    local squares = storedUnitInfoList[unitID].squares
    --Spring.Echo("Log 002: unitID, oldTeamID,newTeamID",unitID, oldTeamID,newTeamID)
    
    for i,coordData in pairs(squares) do
        --local coord = gridXYtoCoordCache[coordData[1]][coordData[2]]
        local coord = GridXYtoCoord(coordData[1],coordData[2])
        if ReduceInfluence(coord, oldTeamID, dps) == 'error' then
            Spring.Echo("Error 014: in reduce influence from ProcessUnitTeamTransfer:",unitID,UnitDefs[storedUnitInfoList[unitID].udID].name, coord)
        else
            --Spring.Echo("unit reduced success in ProcessUnitChangePosition",unitID, UnitDefs[storedUnitInfoList[unitID].udID].name, coord)
        end   
        --ReduceInfluence(coord, oldAllyTeamID, oldTeamID, dps)
        AddInfluence(coord, newTeamID, dps)
    end
    storedUnitInfoList[unitID].teamID = newTeamID
    storedUnitInfoList[unitID].allyTeamID = newAllyTeamID
end



local function ExtractFrame(frame) --Each new unit is processed (added inf). Each destroyed unit is processed (reduce inf). Any mobileunit that has not moved is ignored. Any mobile unit that has moved is (reduced) then (increased)
    local extractList = newUnitListStatic[frame]
    for unitID, data in pairs(extractList) do
        local udID = data[1]
        local teamID = data[2]
        local posX = data[3]
        local posZ = data[4]
        local allyTeamID = teamAllyTeamIDs[teamID]
        if CheckForSkippables(allyTeamID,udID) == true then
        else  
            if not quickRefList[udID] then
                GetUnitStrengthWithUdID(udID)
            end
            --Spring.Echo("UnitID going to ProcessUnitAddOrRemove from static", unitID, UnitDefs[udID].name)
            ProcessUnitAddOrRemove(unitID,udID,teamID,allyTeamID,posX,posZ, false,"newstatic")
        end
    end

    extractList = newUnitListMobile[frame]
    for unitID, data in pairs(extractList) do
        local udID = data[1]
        local teamID = data[2]
        local posX = data[3]
        if posX == nil or posX == "X" then
            --Spring.Echo("posX is nil or X",data, udID, teamID)
        else
            local posZ = data[4]
            local allyTeamID = teamAllyTeamIDs[teamID]
            if CheckForSkippables(allyTeamID,udID) == true then
            else      
                if not quickRefList[udID] then
                    GetUnitStrengthWithUdID(udID)
                end
                --Spring.Echo("UnitID going to ProcessUnitAddOrRemove from mobile", unitID, UnitDefs[udID].name)
                ProcessUnitAddOrRemove(unitID,udID,teamID,allyTeamID,posX,posZ, false,"newmobile")
            end
        end
    end

    extractList = transportedUnitListStatic[frame] --[udid,loaded,posX,posZ]
        for unitID, data in pairs(extractList) do
            if data[2] then
                --zzz need to make a function to remove the influecne.
                --remove original influence spot
                --add to tracking list
            else
                --add new influence at position
                --remove from tracking list
            end
        end

    extractList = transferedUnitListAll[frame]
    for unitID, data in pairs(extractList) do
            if storedUnitInfoList[unitID] then
                local newTeamID =  data[1]
                local oldTeamID = data[2]
                ProcessUnitTeamTransfer(unitID,oldTeamID,newTeamID)
            else --unit removed on deadlist
                --Spring.Echo("Error 012: Stored unitList for transfered unit does not exist:",frame,unitID, deadUnitListAll[frame] )
            end
    end

    extractList = existingUnitListMobile[frame]
    for unitID,data in pairs(extractList) do
        -- if unitID == 24694 then
        --     Spring.Echo("unitid 24694 moving on frame:",frame, data, storedUnitInfoList[unitID])
        -- end
        if data[1] == "X" or not data[1] then 
            Spring.Echo("Error 006: No X value",frame, unitID, data[1],data[2],data[3])
            data[1] = 1 --XXX remove, only for debugging this error
            data[2] = 1
        end
            ProcessUnitChangePositionNew(unitID,data[1],data[2])
    end

    extractList = deadUnitListAll[frame]
    for unitID, data in pairs(extractList) do --deadunitlistall only contains the unitid (key) and unitdefid and teamid. therefore i need to look up other details from when the unit was first created.
        if storedUnitInfoList[unitID] then
            local udID = data[1]
            --local teamID = data[2]
            local teamID = storedUnitInfoList[unitID]
            local posX = storedUnitInfoList[unitID].posX
            local posZ = storedUnitInfoList[unitID].posZ
            local allyTeamID = teamAllyTeamIDs[teamID]
            if CheckForSkippables(allyTeamID,udID) == true then
            else
                if not quickRefList[udID] then
                    GetUnitStrengthWithUdID(udID)
                end
                ProcessUnitAddOrRemove(unitID,udID,teamID,allyTeamID,posX,posZ, true,"deadall")
                storedUnitInfoList[unitID] = nil
            end
        else
            --Spring.Echo("Error 008: Stored unitList for dead unit does not exist:",frame,unitID, deadUnitListAll[frame] )
        end
    end




    PrimeGraphicalLists()
    for coord, bool in pairs(CoordUpdateList) do
        if bool == true then
            CalculateCellInfluenceNew(coord)
        end
    end
    StoreReplayListNew(frame)
end

local function Influence(masterNewUnitListStatic,masterNewUnitListMobile,masterDeadUnitListAll,masterExistingUnitListMobile,masterTransferedUnitListAll,masterTransportedUnitListStatic)
    newUnitListStatic = masterNewUnitListStatic
    newUnitListMobile = masterNewUnitListMobile
    deadUnitListAll = masterDeadUnitListAll
    existingUnitListMobile = masterExistingUnitListMobile
    transferedUnitListAll = masterTransferedUnitListAll
    transportedUnitListStatic = masterTransportedUnitListStatic
    if newUnitListMobile[1] then
        Spring.Echo("WG log Success,")
    else
        Spring.Echo("Cannot Find newUnitListMobile")
    end
end

function widget:Initialize()
    if not gl.CreateShader then
        widgetHandler:RemoveWidget()
        return
    end
    if not InitGL4() then
        widgetHandler:RemoveWidget()
        return
    end
    widgetHandler:RegisterGlobal('Influence', Influence)
    UiElement = WG.FlowUI.Draw.Element
    CacheTeams()
    ----Reset all lists------used for debuging
    CoordUpdateList = {}
    gridList = {} --table that holds all values
    -------------------------------
    PopulateGridNew()
    Spring.Echo("end Initialize")
    drawer = true
end



function widget:TextCommand(command)

    if string.find(command, "inf extractsmall", nil, true) then
        --for i=1,#newUnitListMobile -1 do
        for i=1,79 do
            replayFrame = i
            ExtractFrame(i)
        end
        Spring.Echo("Extracted small: to replayFrame",replayFrame)
    end

    if string.find(command, "inf extractall", nil, true) then
        runExtract = true
        Spring.Echo("#newUnitListMobile",#newUnitListMobile)
        replayFrame = 1
        Spring.Echo("#replayFrame",replayFrame,runExtract)
        
        -- for i = 0, #newUnitListMobile -1 do
        -- ExtractFrame(replayFrame)  
        -- --Spring.Echo('Extracted Replay Frame:', replayFrame)
        -- replayFrame = replayFrame + 1    
        -- end
    end

    if string.find(command, "inf play", nil, true) then
        for i = 1 , replayFrame-1 do
            --RunReplayList(i)
        end
        drawFrame = 1
        Spring.Echo("Removed unit icons from minimap, type '/minimap unitsize 5 to bring them back'")
        Spring.SendCommands("minimap unitsize " .. 0)
        Spring.Echo("playbackFrame to #:",replayFrame-1)
    end

    if string.find(command, "inf graph", nil, true) then
        DrawStackedAreaGraph()
        --drawGraphType = "allyTeam"
        if drawGraphType == "team" then
            drawGraphType = "allyTeam"
        else
            drawGraphType = "team"
        end
        Spring.Echo("Ran graph")
    end
    if string.find(command, "inf colours", nil, true) or string.find(command, "inf colors", nil, true)  then
        if onlyAllyTeamColours then
            onlyAllyTeamColours = false
            Spring.Echo("Individual colours enabled")
        else
            onlyAllyTeamColours = true
            Spring.Echo("Captain colours enabled")
        end
    end
    if string.find(command, "inf bug", nil, true) then
        Spring.Echo("Widget Bug Excluded:")
        for i, _ in pairs(excludeUnits) do
            Spring.Echo(UnitDefs[i].translatedHumanName, UnitDefs[i].name)
        end
        Spring.Echo("Widget Bug spamUnits:")
        for i, _ in pairs(spamUnits) do
            Spring.Echo(UnitDefs[i].translatedHumanName, UnitDefs[i].name)
        end

    end
end

local update = 0
function widget:Update()
    update = update + 1
    if update % 10 == 0 then
        if runExtract == true then
            --if replayFrame <  80 then --xxx bug checking, remove
            if replayFrame < #newUnitListMobile -2 then
            ExtractFrame(replayFrame)
            Spring.Echo('Extracted Replay Frame:', replayFrame, notMoveCounter, oldNotMove-notMoveCounter)
            oldNotMove = notMoveCounter
            replayFrame = replayFrame + 1
            end
            if frameCounter < replayFrame and update % 30 ==0 then
                if onlyAllyTeamColours then
                    for coord, colourData in pairs(drawChangedCellsList[frameCounter]) do
                        InstanceVBOTable.pushElementInstance(gridInstanceVBO, {coord,0,0,0,colourData[4],colourData[5],colourData[6],colourData[7]}, coord , true, false)
                    end
                else
                    for coord, colourData in pairs(drawChangedCellsList[frameCounter]) do
                        InstanceVBOTable.pushElementInstance(gridInstanceVBO, {coord,0,0,0,colourData[1],colourData[2],colourData[3],colourData[7]}, coord , true, false)
                    end
                end
                frameCounter = frameCounter + 1
            elseif frameCounter == replayFrame and update % 30 ==0 then
                frameCounter = 1
                PopulateGridNew()
            end
        end
    end
end

-- function widget:DrawWorld()
--     gridShader:Activate()
--     gridShader:SetUniformInt("isMinimapRendering", 0)
-- 	gridShader:SetUniformInt("flipMinimap", getMiniMapFlipped() and 1 or 0)
--     drawInstanceVBO(gridInstanceVBO)
-- 	gridShader:Deactivate()
-- end

-- function widget:DrawInMiniMap(sx,sy)
--     -- if drawer == true then
--     --     if drawMiniMap[replayFrame] then
--     --         gl_CallList(drawMiniMap[replayFrame])
--     --     end
--     -- end
--     if drawer and gameOver then
--         if drawMiniMap[drawFrame] then
--             gl_CallList(drawMiniMap[drawFrame])
--         end
--         -- if drawMiniMapIcons[drawFrame] then
--         --     gl_CallList(drawMiniMapIcons[drawFrame])
--         -- end
--     end
--     if updateCounter % 2 == 0 and gameOver then
--         drawFrame = drawFrame +1
--         if drawFrame >= replayFrame then
--             drawFrame = 1
--         end
--     end
--     drawUpdateCounter = drawUpdateCounter + 1
-- end


function widget:DrawInMiniMap()
    gridShader:Activate()
    gridShader:SetUniformInt("isMinimapRendering", 1)
	gridShader:SetUniformInt("flipMinimap", getMiniMapFlipped() and 1 or 0)
    InstanceVBOTable.drawInstanceVBO(gridInstanceVBO)
	gridShader:Deactivate()
end

function widget:DrawScreen()
    if drawer and gameOver then
        if drawStackedAreaGraphTeam and drawGraphType == "team" then
            gl_CallList(drawStackedAreaGraphTeam)  
        end

        if drawStackedAreaGraphTeam and drawGraphType == "allyTeam" then
            gl_CallList(drawStackedAreaGraphAllyTeam)  
        end
        if drawGraphCurrentFrameLine[drawFrame] then
            gl_CallList(drawGraphCurrentFrameLine[drawFrame])
        end   
        if drawStackedAreaGraphAxis then
            gl_CallList(drawStackedAreaGraphAxis)
        end
    end
end

function widget:Shutdown()
    widgetHandler:DeregisterGlobal('Influence')
	if quadVBO then
		quadVBO:Delete()
	end
	if gridInstanceVBO and gridInstanceVBO.instanceVBO then
		gridInstanceVBO.instanceVBO:Delete()
	end
	if gridShader then
		gridShader:Finalize()
	end
end