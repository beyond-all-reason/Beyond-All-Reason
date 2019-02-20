function gadget:GetInfo()
  return {
    name      = "Build Icons Slowy (/luarules buildiconslow)",
    desc      = "builds them all slow-like, 1 per minute for hours on end",
    author    = "Beherith",
    date      = "2015",
    license   = "Horses",
    layer     = 0,
    enabled   = true  --  loaded by default?
  }
end

if (not gadgetHandler:IsSyncedCode()) then
	return
end

local index=1
local counter = 1
local unitnames={}

local timedelay=9*30 -- delay to let garbage collector do its work, increase this if UI crashes (this crap takes hours for 400+ units)
local timedelayFirstFrame=5*30 -- delay to let garbage collector do its work, increase this if UI crashes (this crap takes hours for 400+ units)
local timedelayFrame=75 -- delay only needs to be long for the 1st frame due to its centering function mem usage
local animationFrames = 120

function buildslowly(_,_,params)
    nextFrame = Spring.GetGameFrame()
    if #params == 1 then
        if type(tonumber(params[1])) == "number" then
            index = tonumber(params[1])
        end
    end
    Spring.Echo('building icons all slow-like, starting from '..index)

    local counter = 1
    for i,unitdefname in pairs(UnitDefNames) do
        counter = counter + 1
        --Spring.Echo('unitdefname',i,unitdefname)
        local filepath = '../buildicons/__256x256/'..i..'.png'
        if VFS.FileExists( filepath, VFS.RAW) then
            --Spring.Echo("File exists for: "..i.. ' '..filepath)
        else
            --Spring.Echo("Building filepath: "..filepath)
            if not index or counter >= index then
                unitnames[#unitnames+1]=i
            end
        end
    end
end

local framenumLength = string.len(tostring(animationFrames))
function addZeros(number)
    for length=string.len(tostring(number)), framenumLength-1 do
        number = '0'..number
    end
    return number
end

function buildUnitAnim(unitName)
    local angleStep = 360/animationFrames
    for frame=0,animationFrames-1 do
        unitnames[#unitnames+1]=unitName..' '..(angleStep*frame)..' '..addZeros(frame)
    end
end

function buildanim(_,_,params)
    nextFrame = Spring.GetGameFrame()
    if #params == 1 then
        local unitName = params[1]
        if type(tonumber(params[1])) == "number" then
            local i = tonumber(params[1])
            local counter = 1
            for name,_ in pairs(UnitDefNames) do
                counter = counter + 1
                if counter == i then
                    unitName = name
                    break
                end
            end
        end
        Spring.Echo('building icon with animation frames all slow-like, starting from '..index)


        local filepath = '../buildicons/__256x256/'..unitName..'.png'
        if VFS.FileExists( filepath, VFS.RAW) then
            --Spring.Echo("File exists for: "..unitName.. ' '..filepath)
        else
            --Spring.Echo("Building filepath: "..filepath)
            buildUnitAnim(unitName)
        end
    end
end


function buildanimslowly(_,_,params)
    nextFrame = Spring.GetGameFrame()
    if #params == 1 then
        if type(tonumber(params[1])) == "number" then
            unitnumber = tonumber(params[1])
        end
    end
    Spring.Echo('building icons with animation frames all slow-like, starting from '..index)

    local counter = 1
    for unitName,_ in pairs(UnitDefNames) do
        counter = counter + 1
        if not unitnumber or counter >= unitnumber then
            local filepath = '../buildicons/256x256/'..unitName..'.png'
            if VFS.FileExists( filepath, VFS.RAW) then
                Spring.Echo("File exists for: "..unitName.. ' '..filepath)
            else
                Spring.Echo("Building filepath: "..filepath)
                buildUnitAnim(unitName)
            end
        end
    end
end

function gadget:Initialize()
    gadgetHandler:AddChatAction('buildiconslow', buildslowly, "")
    gadgetHandler:AddChatAction('buildiconanim', buildanim, "")
    gadgetHandler:AddChatAction('buildiconanimslow', buildanimslowly, "")
end

function gadget:GameFrame(n)
    if (nextFrame and n>nextFrame and index <=#unitnames) then
        -- Spring.Echo(" Drawing unit ",index,UnitDefNames[index]["name"])
        Spring.Echo(" Drawing:  ",index,unitnames[index],"   out of ", #unitnames)
        Spring.SendCommands("luarules buildicon "..unitnames[index])
        index=index+1
        counter=counter+1

        if not string.find(unitnames[index], ' ') then
            nextFrame = n + timedelay
        else
            if not string.find(unitnames[index], ' ') or string.match(unitnames[index], ' 1$') then
                nextFrame = n + timedelayFirstFrame
            else
                nextFrame = n + timedelayFrame
            end
        end
        --local unitName = string.match(unitnames[index], '[a-zA-Z0-9]*')
        --if unitName then
        --    if unitConfigs and unitConfigs[UnitDefNames[unitName].id] and unitConfigs[UnitDefNames[unitName].id].wait then
        --        Spring.Echo(nextFrame + unitConfigs[UnitDefNames[unitName].id].wait)
        --        nextFrame = nextFrame + unitConfigs[UnitDefNames[unitName].id].wait
        --    end
        --end
    end
end

function gadget:Shutdown()
    gadgetHandler:RemoveChatAction('buildiconslow')
    gadgetHandler:RemoveChatAction('buildiconanim')
    gadgetHandler:RemoveChatAction('buildiconanimslow')
end
