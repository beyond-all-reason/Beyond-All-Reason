local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Build Icons Slowy (/luarules buildiconslow or buildiconanim or buildiconanimslow)",
		desc = "builds them all slow-like",
		author = "Beherith, Floris",
		date = "2015",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true
	}
end

-- when using /luarules buildiconanim unitname:
-- to convert the resulting png sequence into 30 fps gif: install imagemagick.
-- use cmd: magick convert -dispose background -colors 32 -mattecolor #222222 -delay 3.33 -loop 0 *.png result.gif

-- to batch convert: create a .bat file in folder above the result folders:
--for /f %%f in ('dir /ad /b') do (
--cd %%f
--magick convert -dispose background -colors 32 -mattecolor #222222 -delay 3.33 -loop 0 *.png ..\%%f.gif
--cd..
--)


if (not gadgetHandler:IsSyncedCode()) then
	return
end

local skipUnits = {
	meteor = true,
	raptor_hive = true,
}

local index = 1
local counter = 1
local unitnames = {}

local timedelay = 9 * 30 -- delay to let garbage collector do its work, increase this if UI crashes (this crap takes hours for 400+ units)
local timedelayFirstFrame = 5 * 30 -- delay to let garbage collector do its work, increase this if UI crashes (this crap takes hours for 400+ units)
local timedelayFrame = 80 -- delay only needs to be long for the 1st frame due to its centering function mem usage
local animationFrames = 120

local nextFrame, unitnumber

function buildslowly(_, _, params)
	nextFrame = Spring.GetGameFrame()
	if #params == 1 then
		if type(tonumber(params[1])) == "number" then
			index = tonumber(params[1])
		end
	end
	Spring.Echo('building icons all slow-like, starting from ' .. index)

	local counter = 1
	for unitName, unitdefname in pairs(UnitDefNames) do
		counter = counter + 1
		--Spring.Echo('unitdefname',i,unitdefname)
		local filepath = '../buildicons/__256x256/' .. unitName .. '.png'
		if VFS.FileExists(filepath, VFS.RAW) then
			--Spring.Echo("File exists for: "..i.. ' '..filepath)
		else
			--Spring.Echo("Building filepath: "..filepath)
			if not index or counter >= index then
				if not skipUnits[unitName] then
					unitnames[#unitnames + 1] = unitName
				end
			end
		end
	end
end

local framenumLength = string.len(tostring(animationFrames))
function addZeros(number)
	for length = string.len(tostring(number)), framenumLength - 1 do
		number = '0' .. number
	end
	return number
end

function buildUnitAnim(unitName)
	local angleStep = 360 / animationFrames
	for frame = 0, animationFrames - 1 do
		unitnames[#unitnames + 1] = unitName .. ' ' .. (angleStep * frame) .. ' ' .. addZeros(frame)
	end
end

function buildanim(_, _, params)
	nextFrame = Spring.GetGameFrame()
	if #params == 1 then
		local unitName = params[1]
		if type(tonumber(params[1])) == "number" then
			local i = tonumber(params[1])
			local counter = 1
			for name, _ in pairs(UnitDefNames) do
				counter = counter + 1
				if counter == i then
					unitName = name
					break
				end
			end
		end
		Spring.Echo('building icon with animation frames all slow-like, starting from ' .. index)

		local filepath = '../buildicons/__256x256/' .. unitName .. '.png'
		if VFS.FileExists(filepath, VFS.RAW) then
			--Spring.Echo("File exists for: "..unitName.. ' '..filepath)
		else
			--Spring.Echo("Building filepath: "..filepath)
			buildUnitAnim(unitName)
		end
	end
end

function buildanimslowly(_, _, params)
	nextFrame = Spring.GetGameFrame()
	if #params == 1 then
		if type(tonumber(params[1])) == "number" then
			unitnumber = tonumber(params[1])
		end
	end
	Spring.Echo('building icons with animation frames all slow-like, starting from ' .. index)

	local counter = 1
	for unitName, _ in pairs(UnitDefNames) do
		counter = counter + 1
		if not unitnumber or counter >= unitnumber then
			local filepath = '../buildicons/256x256/' .. unitName .. '.png'
			if VFS.FileExists(filepath, VFS.RAW) then
				Spring.Echo("File exists for: " .. unitName .. ' ' .. filepath)
			else
				if not skipUnits[unitName] then
					Spring.Echo("Building filepath: " .. filepath)
					buildUnitAnim(unitName)
				end
			end
		end
	end
end

function gadget:Initialize()
	gadgetHandler:AddChatAction('buildiconslow', buildslowly, "")
	gadgetHandler:AddChatAction('buildiconanim', buildanim, "")
	gadgetHandler:AddChatAction('buildiconanimslow', buildanimslowly, "")
end

local unitConfigs = {   -- copy from configs/icon_generator.lua, included.. because else it will miss frames when animating
	[UnitDefNames.cormex.id] = {
		wait = 60,
	},
	[UnitDefNames.corsolar.id] = {
		wait = 80,
	},
	[UnitDefNames.armrad.id] = {
		wait = 360,
	},
	[UnitDefNames.corgant.id] = {
		wait = 90,
	},
	[UnitDefNames.corgantuw.id] = {
		wait = 90,
	},
	[UnitDefNames.cortoast.id] = {
		wait = 1,
	},
	[UnitDefNames.armplat.id] = {
		wait = 65,
	},

}
function gadget:GameFrame(n)
	if (nextFrame and n > nextFrame and index <= #unitnames) then
		Spring.SendCommands("luarules buildicon " .. unitnames[index])
		index = index + 1
		counter = counter + 1

		if not string.find(unitnames[index], ' ') then
			-- single buildpic
			nextFrame = n + timedelay
		else
			-- animation
			if not string.find(unitnames[index], ' ') or string.match(unitnames[index], ' 1$') then
				nextFrame = n + timedelayFirstFrame
			else
				nextFrame = n + timedelayFrame
			end
			-- added custom wait period on top, because else it will miss frames
			local unitName = string.match(unitnames[index], '[a-zA-Z0-9]*')
			if unitName then
				if unitConfigs and unitConfigs[UnitDefNames[unitName].id] and unitConfigs[UnitDefNames[unitName].id].wait then
					nextFrame = nextFrame + unitConfigs[UnitDefNames[unitName].id].wait
				end
			end
		end
	end
end

function gadget:Shutdown()
	gadgetHandler:RemoveChatAction('buildiconslow')
	gadgetHandler:RemoveChatAction('buildiconanim')
	gadgetHandler:RemoveChatAction('buildiconanimslow')
end
