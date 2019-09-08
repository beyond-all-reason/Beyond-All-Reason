
function widget:GetInfo()
	return {
		name = "Cursors",
		desc = "auto sets a scale for the cursor based on screen resolution" ,
		author = "Floris",
		date = "",
		license = "",
		layer = 1,
		enabled = true
	}
end

local sizeMult = 1
local Settings = {}
Settings['cursorSet'] = 'bar'
Settings['cursorSize'] = 100
Settings['version'] = 2		-- just so it wont restore configdata on load if it differs format

local force = true

function split(inputstr, sep)
	sep = sep or '%s'
	local t = {}
	for field, s in string.gmatch(inputstr, "([^"..sep.."]*)("..sep.."?)") do
		table.insert(t,field)
		if s == "" then
			return t
		end
	end
end

-- note: first entry should be icons inside base /anims folder
local cursorSets = {}
for k, subdir in pairs(VFS.SubDirs('anims')) do
	local cursorNameSplit = split(string.gsub(string.sub(subdir, 1, #subdir-1), 'anims/', ''), '_')
	--cursorSets[#cursorSets + 1] = string.gsub(string.sub(subdir, 1, #subdir-1), 'anims/', '')	-- game anims folder
	--cursorSets[#cursorSets] = string.gsub(string.sub(cursorSets[#cursorSets], 1, #subdir), 'anims\\', '')	-- spring anims folder
	if cursorSets[cursorNameSplit[1]] == nil then
		cursorSets[cursorNameSplit[1]] = {}
	end
	cursorSets[cursorNameSplit[1]][#cursorSets[cursorNameSplit[1]]+1] = cursorNameSplit[2]
end

function NearestValue(table, number)
	local smallestSoFar, smallestIndex
	for i, y in ipairs(table) do
		if not smallestSoFar or (math.abs(number-y) < smallestSoFar) then
			smallestSoFar = math.abs(number-y)
			smallestIndex = i
		end
	end
	return smallestIndex, table[smallestIndex]
end

function widget:ViewResize()
	local ssx,ssy = Spring.GetScreenGeometry()
	autoCursorSize = 100 * (0.6 + (ssx*ssy / 7000000)) * sizeMult
	SetCursor(Settings['cursorSet'])
end

function widget:Initialize()
	widget:ViewResize()

	WG['cursors'] = {}
	WG['cursors'].getcursor = function()
		return Settings['cursorSet']
	end
	WG['cursors'].getcursorsets = function()
		local sets = {}
		for i, y in pairs(cursorSets) do
			sets[#sets+1] = i
		end
		return sets
	end
	WG['cursors'].setcursor = function(value)
		SetCursor(value)
	end
	WG['cursors'].getsizemult = function()
		return sizeMult
	end
	WG['cursors'].setsizemult = function(value)
		sizeMult = value
		widget:ViewResize()
	end
end

function widget:Shutdown()
	WG['cursors'] = nil
end

----------------------------
-- load cursors
function SetCursor(cursorSet)
	local oldSetName = Settings['cursorSet']..'_'..Settings['cursorSize']
	Settings['cursorSet'] = cursorSet
	Settings['cursorSize'] = cursorSets[cursorSet][NearestValue(cursorSets[cursorSet], autoCursorSize)]
	cursorSet = cursorSet..'_'..Settings['cursorSize']
	if cursorSet ~= oldSetName or force then
		force = false
		local cursorNames = {
			'cursornormal','cursorareaattack','cursorattack','cursorattack',
			'cursorbuildbad','cursorbuildgood','cursorcapture','cursorcentroid',
			'cursorwait','cursortime','cursorwait','cursorunload','cursorwait',
			'cursordwatch','cursorwait','cursordgun','cursorattack','cursorfight',
			'cursorattack','cursorgather','cursorwait','cursordefend','cursorpickup',
			'cursorrepair','cursorrevive','cursorrepair','cursorrestore','cursorrepair',
			'cursormove','cursorpatrol','cursorreclamate','cursorselfd','cursornumber',
			'cursorsettarget','cursorupgmex',
		}
		for i=1, #cursorNames do
			local topLeft = (cursorNames[i] == 'cursornormal')
			Spring.ReplaceMouseCursor(cursorNames[i], cursorSet..'/'..cursorNames[i], topLeft)
		end
	end
end

function widget:GetConfigData()
    return Settings
end

function widget:SetConfigData(data)
    if data and type(data) == 'table' and data.version and data.version == Settings['version'] then
        Settings = data
    end
end