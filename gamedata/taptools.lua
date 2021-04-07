--==============================
--== TAPrime HELPER FUNCTIONS ==
--==============================
--shard_include("luarules/gadgets/ai/ba/commonfunctions.lua") 	-- doesn' work here
VFS.Include("LuaRules/colors.h.lua")

local spFindUnitCmdDesc     = Spring.FindUnitCmdDesc
local spInsertUnitCmdDesc     = Spring.InsertUnitCmdDesc
local spEditUnitCmdDesc     = Spring.EditUnitCmdDesc
local spGetUnitPosition = Spring.GetUnitPosition
local spMarkerAddPoint = Spring.MarkerAddPoint
local spMarkerErasePosition = Spring.MarkerErasePosition

function isbool(x)   return (type(x) == 'boolean') end
function istable(x)  return (type(x) == 'table')   end
function isnumber(x) return (type(x) == 'number')  end
function isstring(x) return (type(x) == 'string')  end

function sqrDistance(x1,z1,x2,z2)
	local dx,dz = x1-x2,z1-z2
	return (dx*dx)+(dz*dz)
end

function tobool(val)
	local t = type(val)
	if (t == 'nil') then
		return false
	elseif (t == 'boolean') then
		return val
	elseif (t == 'number') then
		return (val ~= 0)
	elseif (t == 'string') then
		return ((val ~= '0') and (val ~= 'false'))
	end
	return false
end

-- Counts how many fields (not elements, use # for that) are there in table T
function tablelength(T)
	local count = 0
	for _ in pairs(T) do count = count + 1 end
	return count
end

-- Fast/Concise Remove from ipairs: (http://lua-users.org/lists/lua-l/2013-11/msg00031.html)
function ipairs_remove(t, value)
	if not t or not value then
		return end
	local index = 1
	local size = #t
	while index <= size do
		if t[index] == value then   -- if found searched value
			t[index] = t[size]      -- replace it with last item
			t[size] = nil           -- then remove last item. #count still works properly.
			size = size - 1
		else
			index = index + 1 end
	end
end

function ipairs_removeIdx(t, index)
	local size = #t
	t[index] = t[size]      -- replace it with last item
	t[size] = nil           -- then remove last item. #count still works properly.
end

-- Used to remove an element from an itable where the inner param 'element' equals to a certain value
function ipairs_removeByElement(table, elementId, value)
	for _, v in ipairs(table) do
		if v[elementId] == value then
			ipairs_remove(table, v)
		end
	end
end

-- Returns the index (if found) or nil if not found
function ipairs_containsElement(table, elementId, value)
	for k, v in ipairs(table) do
		if v[elementId] == value then
			return k
		end
	end
	return nil
end

-- Returns the key (if found) or nil if not found
function pairs_containsElement(table, elementId, value)
	for k, v in pairs(table) do
		if v[elementId] == value then
			return k
		end
	end
	return nil
end

function ipairs_len(table)
	local numItems = 0
	for k, v in ipairs(table) do
		numItems = numItems + 1
	end
	return numItems
end

function pairs_len(table)
    -- Alert: Line below prevent errors, but it won't be obvious to the caller if the table is nil
    if table == nil or not istable(table) then
        return 0 end
	local numItems = 0
	for _, v in pairs(table) do
        if v then
            numItems = numItems + 1
        end
	end
	return numItems
end

-- Debug function to list all keys in a given table
function DebugTableKeys(table)
	local keys = ""
	for key, _ in pairs(table) do
		keys = keys .. key .. " "
	end
	Spring.Echo("Table keys: " .. keys)
end

-- Debug table keys and values, up to three nested levels
function DebugTable(tbl)
	--Spring.Echo(" Debug Table: ")
	for k, v in pairsByKeys(tbl) do
		local str
		if type(v) == "table" then
			str = "{"
			for k2, v2 in pairsByKeys(v) do
				str = str .. k2
				if type(v2) == "table" then
					str = str .. "{"
					for k3, v3 in pairsByKeys(v2) do
						if type(v3) == "table" then
							str = str .. k3 .. "={<table>}, "
						else
							str = str .. k3 .. "=" .. tostring(v3) .. ", "
						end
					end
					str = str .. "}"
				else
					str = str .. tostring(v2)
				end
			end
			str = str .. "}"
		else
			str = tostring(v)
		end
		Spring.Echo(tostring(k), str)
	end
end

-- Debug ipairs containing table keys and values, up to three nested levels
function DebugiTable(tbl)
	--Spring.Echo("Debugitable")
	if type(tbl) == 'table' then
		local s = '{ '
		for k,v in pairs(tbl) do
			if type(k) ~= 'number' then k = '"'..k..'"' end
			s = s .. '['..k..'] = ' .. DebugiTable(v) .. ','
		end
		return s .. '} '
	else
		return tostring(tbl)
	end
end

-- Returns true if a table (tab) contains a certain value (searchVal)
function ipairs_contains (tab, searchVal)
	for _,value in ipairs(tab) do
		if value == searchVal then
			return true
		end
	end
	return false
end

-- Returns a key-sorted iterator which may be traversed by, eg:
--     for name, line in pairsByKeys(lines) do  print(name, line)  end
-- takes: table, order function; returns: iterator
function pairsByKeys (t, f)
	local iter = function () end
	if not t then
		return iter end
	local a = {}
	for n in pairs(t) do
		table.insert(a, n) end
	table.sort(a, f)
	local i = 0      			-- iterator variable
	iter = function ()	-- iterator function
		i = i + 1
		if a[i] == nil then
			return nil
		else
			return a[i], t[a[i]] end
	end
	return iter
end

-- Returns a key-sorted iterator which may be traversed by, eg:
--     for name, line in pairsByKeys(lines) do  print(name, line)  end
-- takes: table, order function; returns: iterator
function ipairsByKeys (t, f)
	local iter = function () end
	if not t then
		return iter end
	local a = {}
	for n in ipairs(t) do
		table.insert(a, n) end
	table.sort(a, f)
	local i = 0      			-- iterator variable
	iter = function ()	-- iterator function
		i = i + 1
		if a[i] == nil then
			return nil
		else
			return a[i], t[a[i]] end
	end
	return iter
end

local newlineChar = "\b"	--was: \011 (FF) - "vertical tab" char, to allow proper parsing from spreadsheets
local tabChar = "\t" 		--This can be replaced by another tabulation char if desired

-- Returns a string from any value, including tables
-- takes: type (any), strings (separator, newline, original text, open sign, close sign), int (indentLevel);
-- returns: string
function tostringplus(t, indent, sep, nl, text, osign, csign)
	if t == nil then
		return ""
	end
	if indent == nil then
		indent = ""
	end
	if sep == nil then
		sep = "="
	end
	if nl == nil then
		nl = ","..newlineChar
	end
	if text == nil then
		text = ""
	end
	if osign == nil then
		osign = "{"..newlineChar
	end
	if csign == nil then
		csign = "}"	-- comma is added automatically by the overarching routine
	end

	if type(t) == "string" then
		text = '"'..t..'"'
	else
		if type(t) == "table" then
			local outerind = indent
			text = text..osign

			indent = indent .. tabChar
			for k,v in pairs(t) do
				if type(k) == "number" then
					--iPairs don't need the explicit index
					text = text..indent..tostringplus(v, indent) --, sep, nl, text, osign, csign, indent)
							.. nl
				else
					text = text..indent..tostring(k, indent) --, sep, nl, text, osign, csign, indent)
							-- TODO: the first 'sep' below shouldn't be added after a 'close sign'
							.. sep ..tostringplus(v, indent) --, sep, nl, text, osign, csign, indent)
							.. nl
				end
			end

			text = text..outerind..csign
		else
			text = text..tostring(t)
		end
	end

	return text
end

--// Converters a quotes-enclosed table into a lua table. Used for customParams encoded tables
--function str2table(s)
--    local exps, res = {}, {}
--    local function save(v)
--        exps[#exps + 1] = v
--        return ('\0'):rep(#exps)
--    end
--    s = s:gsub('%b{}', function(s) return save{str2table(s:sub(2, -2))} end)    -- arrays
--    s = s:gsub('"(.-)"', save)                                                  -- strings
--    s = s:gsub('%-?%d+', function(s) return save(tonumber(s)) end)              -- integer numbers
--    for k in s:gmatch'%z+' do
--        res[#res + 1] = exps[#k]
--    end
--    return (table.unpack or unpack)(res)
--end

-- [WIP], doesn't work with backspace chars properly
function str2table(input)
    local function is_digit(c)
        return c >= '0' and c <= '9'
    end
    --input = tostring(input)
    if not input then
        return end
    if isstring(input) then
        input = string.gsub(input, "%[%[", "'")
        input = string.gsub(input, "%]%]", "'")
        input = string.gsub(input, "\"", "'")
        input = string.gsub(input, "\b", "")    --backspace char, used in the data spreadsheet
        --Spring.Echo("Formatted string: "..input)
    end
    if type(input) == 'string' then
        local data = input
        local pos = 0
        function input(undo)
            if undo then
                pos = pos - 1
            else
                pos = pos + 1
                return string.sub(data, pos, pos)
            end
        end
    end
    local c
    repeat
        c = input()
    until c ~= ' ' and c ~= ','
    if c == "'" then
        local s = ''
        repeat
            c = input()
            if c == "'" then
                return s
            end
            s = s..c
        until c == ''
    elseif c == '-' or is_digit(c) then
        local s = c
        repeat
            c = input()
            local d = is_digit(c)
            if d then
                s = s..c
            end
        until not d
        input(true)
        return tonumber(s)
    elseif c == '{' then
        local arr = {}
        local elem
        repeat
            elem = str2table(input)
            table.insert(arr, elem)
        until not elem
        return arr
    end
end

--////////////////////////
--// MATH FUNCTIONS
--////////////////////////

function inverselerp(a, b, t)
	--return t / (a + b) || deprecated, was used by los scaler

	return (t - a) / (b - a)
end

function lerp(a, b, t)
	return a + (b - a) * t
end

function minmax(n, min, max)
	if n > max then
		n = max end
	if n < min then
		n = min end
	return n
end

--////////////////////////
--// UPGRADE FUNCTIONS
--////////////////////////

function HasTech(prereq, teamID)
	if prereq == "" or prereq == nil then
		return true end
	return GG.TechCheck(prereq, teamID)
end

--////////////////////////
--// LUA UI FUNCTIONS
--////////////////////////

--Adds or updates the command-button
function AddUpdateCommand(unitID, cmdDesc, block)
    local CurrentCmdDescId = spFindUnitCmdDesc(unitID, cmdDesc.id)
    cmdDesc.disabled = block or false

    if not CurrentCmdDescId then
        spInsertUnitCmdDesc(unitID, cmdDesc.id, cmdDesc)
    else
        spEditUnitCmdDesc(unitID, cmdDesc.id, cmdDesc)
    end
end

-- BlockCmdID(.., ..) or BlockCmdID(.., .., false)
function SetCmdIDEnable(unitID, cmdID, block, orgTooltip, suffix)
	if not isnumber(cmdID) then
		return
	end
	local cmdDescId = spFindUnitCmdDesc(unitID, cmdID)
	if not cmdDescId then
		return end

    local disable = (block == true or block == nil) -- default: disabled (blocked)
    local cmdArray = { disabled = disable }

    if disable and suffix then
        cmdArray.tooltip = orgTooltip.."\n\n"..RedStr..suffix
    else
        cmdArray.tooltip = orgTooltip
    end

	--Spring.Echo(cmdID.." Disabled: "..tostring(disable))
	spEditUnitCmdDesc(unitID, cmdDescId, cmdArray)
end

function BlockCmdID(unitID, cmdID, orgTooltip, suffix)
    SetCmdIDEnable(unitID, cmdID, true, orgTooltip, suffix)
end

function UnblockCmdID(unitID, cmdID, orgTooltip, suffix)
    SetCmdIDEnable(unitID, cmdID, false, orgTooltip)
end


function LocalAlert(unitID, msg)
    local x, y, z = spGetUnitPosition(unitID)  --x and z on map floor, y is height
    spMarkerAddPoint(x,y,z,msg,true)
    spMarkerErasePosition(x,y,z)
end

function IsValidUnit(unitID)
	local unitDefID = Spring.GetUnitDefID(unitID)
	if unitDefID and Spring.ValidUnitID(unitID) then
		return true
	end
	return false
end

function DistanceToPoint(unitID, px,py,pz)
	if not Spring.ValidUnitID(unitID) then return end
	if not px or not pz then return end

	local ux, uy, uz = spGetUnitPosition(unitID)
	local dx, dy ,dz = ux - px, uy - py, uz - pz
	local dist = dx * dx + dy * dy + dz * dz
	return dist
end


function Distance2D(unitID, px, pz)
	if not Spring.ValidUnitID(unitID) then
		return end
	if not px or not pz then
		Spring.Echo(" Invalid px or pz")
		return end

	local ux, _, uz = spGetUnitPosition(unitID)
	local dx, dz = ux - px, uz - pz
	local dist = dx * dx + dz * dz
	return dist
end

--function indent(i, str)
--	local result = ""
--	if str == nil then
--		str = "\t"
--	end
--	if i == 0 then
--		result = ""
--	else
--		for i = 1, i do
--			result = result .. str
--		end
--	end
--	return result
--end

-------------------------------------------------------------------------------------
--- ZeroK Utilities
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

--local buildTimes = {}
--local variableCostUnit = {
--	[UnitDefNames["terraunit"].id] = true
--}
--local isCommander = {}
--
--for i = 1, #UnitDefs do
--	local ud = UnitDefs[i]
--	buildTimes[i] = ud.buildTime
--	if ud.customParams.level or ud.customParams.dynamic_comm then
--		variableCostUnit[i] = true
--		isCommander[i] = true
--	end
--end
--
---------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------
--local function GetGridTooltip(unitID)
--	local gridCurrent = Spring.GetUnitRulesParam(unitID, "OD_gridCurrent")
--	if not gridCurrent then return end
--
--	local windStr = ""
--	local minWind = Spring.GetUnitRulesParam(unitID, "minWind")
--	if minWind then
--		windStr = "\n" ..  WG.Translate("interface", "wind_range") .. " " .. math.round(minWind, 1) .. " - " .. math.round(Spring.GetGameRulesParam("WindMax") or 2.5, 1)
--	end
--
--	if gridCurrent < 0 then
--		return WG.Translate("interface", "disabled_no_grid") .. windStr
--	end
--	local gridMaximum = Spring.GetUnitRulesParam(unitID, "OD_gridMaximum") or 0
--	local gridMetal = Spring.GetUnitRulesParam(unitID, "OD_gridMetal") or 0
--
--	return WG.Translate("interface", "grid") .. ": " .. math.round(gridCurrent,2) .. "/" .. math.round(gridMaximum,2) .. " E => " .. math.round(gridMetal,2) .. " M " .. windStr
--end
--
--local function GetMexTooltip(unitID)
--	local metalMult = Spring.GetUnitRulesParam(unitID, "overdrive_proportion")
--	if not metalMult then return end
--
--	local currentIncome = Spring.GetUnitRulesParam(unitID, "current_metalIncome")
--	local mexIncome = Spring.GetUnitRulesParam(unitID, "mexIncome") or 0
--	local baseFactor = Spring.GetUnitRulesParam(unitID, "resourceGenerationFactor") or 1
--
--	if currentIncome == 0 then
--		return WG.Translate("interface", "disabled_base_metal") .. ": " .. math.round(mexIncome,2)
--	end
--
--	return WG.Translate("interface", "income") .. ": " .. math.round(mexIncome*baseFactor,2) .. " + " .. math.round(metalMult*100) .. "% " .. WG.Translate("interface", "overdrive")
--end
--
--local function GetTerraformTooltip(unitID)
--	local spent = Spring.GetUnitRulesParam(unitID, "terraform_spent")
--	if not spent then return end
--
--	return WG.Translate("interface", "terraform") .. " - " .. WG.Translate("interface", "estimated_cost") .. ": " .. math.floor(spent) .. " / " .. math.floor(Spring.GetUnitRulesParam(unitID, "terraform_estimate") or 0)
--end
--
--local function GetZenithTooltip (unitID)
--	local meteorsControlled = Spring.GetUnitRulesParam(unitID, "meteorsControlled")
--	if not meteorsControlled then return end
--
--	return (WG.Translate("units", "zenith.description") or "Meteor Controller") .. " - " .. (WG.Translate("interface", "meteors_controlled") or "Meteors controlled") .. " " .. (meteorsControlled or "0") .. "/500"
--end
--
--local function GetAvatarTooltip(unitID)
--	local commOwner = Spring.GetUnitRulesParam(unitID, "commander_owner")
--	if not commOwner then return end
--	return commOwner or ""
--end
--
--local function GetCustomTooltip (unitID)
--	return GetGridTooltip(unitID)
--			or GetMexTooltip(unitID)
--			or GetTerraformTooltip(unitID)
--			or GetZenithTooltip(unitID)
--			or GetAvatarTooltip(unitID)
--end
--
--function Spring.Utilities.GetHumanName(ud, unitID)
--	if not ud then
--		return ""
--	end
--
--	if unitID then
--		local name = Spring.GetUnitRulesParam(unitID, "comm_name")
--		if name then
--			local level = Spring.GetUnitRulesParam(unitID, "comm_level")
--			if level then
--				return name .. " " .. WG.Translate("interface", "lvl") .. " " .. (level + 1)
--			else
--				return name
--			end
--		end
--	end
--
--	local name_override = ud.customParams.statsname or ud.name
--	return WG.Translate ("units", name_override .. ".name") or ud.humanName
--end
--
--function Spring.Utilities.GetDescription(ud, unitID)
--	if not ud then
--		return ""
--	end
--
--	local name_override = ud.customParams.statsname or ud.name
--	local desc = WG.Translate ("units", name_override .. ".description") or ud.tooltip
--	if Spring.ValidUnitID(unitID) then
--		local customTooltip = GetCustomTooltip(unitID)
--		if customTooltip then
--			return customTooltip
--		end
--
--		local buildPower = Spring.GetUnitRulesParam(unitID, "buildpower_mult")
--		if buildPower then
--			buildPower = buildPower*10
--			desc = desc .. ", " .. WG.Translate("interface", "builds_at") .. " " .. buildPower .. " m/s"
--		end
--	end
--	return desc
--end
--
--function Spring.Utilities.GetHelptext(ud, unitID)
--	local name_override = ud.customParams.statsname or ud.name
--	return WG.Translate ("units", name_override .. ".helptext") or WG.Translate("interface", "no_helptext")
--end
--
--function Spring.Utilities.GetUnitHeight(ud)
--	local customHeight = ud.customParams.custom_height
--	return (customHeight and tonumber(customHeight)) or ud.height
--end
--
---------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------
--
--function Spring.Utilities.GetUnitCost(unitID, unitDefID)
--	unitDefID = unitDefID or Spring.GetUnitDefID(unitID)
--	if unitID and variableCostUnit[unitDefID] then
--		local realCost = Spring.GetUnitRulesParam(unitID, "comm_cost") or Spring.GetUnitRulesParam(unitID, "terraform_estimate")
--		if realCost then
--			return realCost
--		end
--	end
--	if unitDefID and buildTimes[unitDefID] then
--		return buildTimes[unitDefID]
--	end
--	return 50
--end
--
--function Spring.Utilities.GetUnitCanBuild(unitID, unitDefID)
--	unitDefID = unitDefID or Spring.GetUnitDefID(unitID)
--	if not unitDefID then
--		return 0
--	end
--	local ud = UnitDefs[unitDefID]
--	local buildPower = (ud and ((ud.customParams.nobuildpower and 0) or ud.buildSpeed)) or 0
--	return buildPower > 0
--end
--
--function Spring.Utilities.GetUnitBuildSpeed(unitID, unitDefID)
--	unitDefID = unitDefID or Spring.GetUnitDefID(unitID)
--	if not unitDefID then
--		return 0
--	end
--	local ud = UnitDefs[unitDefID]
--	local buildPower = (ud and ((ud.customParams.nobuildpower and 0) or ud.buildSpeed)) or 0
--	if unitID then
--		local mult = Spring.GetUnitRulesParam(unitID, "buildpower_mult")
--		if mult then
--			return mult * buildPower
--		end
--	end
--	return buildPower
--end
--
--function Spring.Utilities.UnitEcho(unitID, st)
--	st = st or unitID
--	if Spring.ValidUnitID(unitID) then
--		local x,y,z = Spring.GetUnitPosition(unitID)
--		Spring.MarkerAddPoint(x,y,z, st)
--	else
--		Spring.Echo("Invalid unitID")
--		Spring.Echo(unitID)
--		Spring.Echo(st)
--	end
--end

--local a = { "armflash", { name = "Flash", side = "Arm", description = "Fast Assault Tank", acceleration = 0.06, activatewhenbuilt = false, airsightdistance = 0, airstrafe = false, autoheal = 0, bankscale = 0, blocking = false, bmcode = 0, brakerate = 0.1, buildangle = 0, buildcostmetal = 250, buildcostenergy = 5000, builddistance = 0, builder = false, buildinggrounddecaldecayspeed = 0, buildinggrounddecalsizex = 0, buildinggrounddecalsizey = 0, buildoptions = {}, buildpic = "ARMFLASH.DDS", buildtime = 7500, canassist = false, canattack = false, canbeassisted = true, cancapture = false, cancloak = false, candgun = false, canfly = false, canguard = false, canmanualfire = false, canmove = true, canpatrol = false, canreclaim = false, canrepair = false, canrepeat = false, canrestore = false, canresurrect = false, canstop = 0, cansubmerge = false, cantbetransported = false, capturable = true, capturespeed = 0, category = "ALL TANK MOBILE WEAPON NOTSUB NOTSHIP NOTAIR SURFACE", cloakcost = 0, cloakcostmoving = 0, collide = false, collision = false, collisionvolumeoffsets = "0 0 -1", collisionvolumescales = "24 9 31", collisionvolumetype = "Box", commander = false, corpse = "armflash_dead", cruisealt = 0, crushresistance = 300, damagemodifier = 0, energymake = 0, energypershot = 0, energystorage = 0, energyuse = 0, explodeas = "BIG_UNITEX", extractsmetal = 0, featuredefs = { heap = { footprintx = 2, description = "Flash Heap", resurrectable = 0, hitdensity = 100, blocking = false, collisionvolumescales = "35.0 4.0 6.0", damage = 193, featurereclamate = "SMUDGE01", seqnamereclamate = "TREE1RECLAMATE", collisionvolumetype = "cylY", reclaimable = true, world = "All Worlds", footprintz = 2, object = "2X2C", height = 4, category = "heaps", energy = 0, metal = 28, }, dead = { footprintx = 2, description = "Flash Wreckage", featuredead = "armflash_heap", hitdensity = 100, blocking = true, collisionvolumescales = "20.3918304443 9.5 30.2260284424", damage = 396, featurereclamate = "SMUDGE01", seqnamereclamate = "TREE1RECLAMATE", collisionvolumetype = "Box", world = "All Worlds", reclaimable = true, object = "ARMFLASH_DEAD", footprintz = 2, collisionvolumeoffsets = "0.0750198364258 0.20984 -0.70206451416", height = 20, category = "corpses", energy = 0, metal = 71, }, }, floater = false, footprintx = 3, footprintz = 3, hidedamage = false, hightrajectory = 0, hoverattack = false, idleautoheal = 5, idletime = 1800, initcloaked = false, isairbase = false, isfeature = false, istargetingupgrade = false, leavetracks = true, levelground = false, loadingradius = 0, mass = 1500, maxdamage = 598, maxpitch = 0, maxrepairspeed = 0, maxslope = 10, maxvelocity = 5.8, maxwaterdepth = 12, metalmake = 0, metalstorage = 0, mincloakdistance = 0, minwaterdepth = 0, movementclass = "TANK3", mygravity = 0, noautofire = 0, nochasecategory = "VTOL", norestrict = 0, objectname = "ARMFLASH", onoffable = false, pushresistant = false, radardistance = 0, radardistancejam = 0, radius = 0, reclaimable = false, releaseheld = false, repairable = false, seismicdistance = 0, seismicsignature = 0, selfdestructas = "BIG_UNIT", sfxtypes = {}, showplayername = false, sightdistance = 508, smoothanim = 0, sonardistance = 0, sonarstealth = false, sounds = { ok = { "tarmmove", }, count = { "count6", "count5", "count4", "count3", "count2", "count1", }, canceldestruct = "cancel2", cant = { "cantdo4", }, select = { "tarmsel", }, underattack = "warning1", }, stealth = false, terraformspeed = 0, tidalgenerator = 0, trackoffset = 5, trackstrength = 4, trackstretch = 0, tracktype = "StdTank", trackwidth = 22, transportbyenemy = false, transportcapacity = 0, transportmass = 0, transportsize = 0, transportunloadmethod = 0, turninplace = 0, turninplaceanglelimit = 140, turninplacespeedlimit = 2.37599993, turnrate = 592, unloadspread = 0, upright = false, usebuildinggrounddecal = false, usepiececollisionvolumes = 0, waterline = 0, weapondefs = { emgx = { rgbcolor = "1 1 1", impulsefactor = 0.123, areaofeffect = 8, explosiongenerator = "custom:EMG_HIT", avoidfeature = false, intensity = 0.8, thickness = 1.5, corethickness = 0.7, duration = 0.03, size = 2.25, weaponvelocity = 1000, cratermult = 0, craterareaofeffect = 0, craterboost = 0, soundhitwetvolume = 0.5, soundstart = "flashemg", turret = true, tolerance = 5000, weapontype = "LaserCannon", name = "flash", sprayangle = 10, accuracy = 0, burst = 3, burstrate = 0.1, range = 430, damage = { default = 20, }, reloadtime = 0.4, predictboost = 3, weapontimer = 0.1, soundhitwet = "splshbig", noselfdamage = true, impulseboost = 0.123, }, emgxaa = { rgbcolor = "1 1 1", impulsefactor = 0.123, areaofeffect = 8, explosiongenerator = "custom:EMG_HIT", avoidfeature = false, intensity = 0.8, thickness = 1.5, corethickness = 0.7, duration = 0.03, size = 2.25, weaponvelocity = 1000, cratermult = 0, craterareaofeffect = 0, craterboost = 0, soundhitwetvolume = 0.5, soundstart = "flashemg", turret = true, tolerance = 5000, weapontype = "LaserCannon", name = "flashaa", sprayangle = 10, accuracy = 0, burst = 3, burstrate = 0.1, range = 480, damage = { default = 12, }, reloadtime = 0.4, predictboost = 3, weapontimer = 0.1, soundhitwet = "splshbig", noselfdamage = true, impulseboost = 0.123, cylindertargeting = 0.5, targetMoveError = 0.1,}, }, weapons ={        {                onlytargetcategory = "SURFACE", badtargetcategory = "TANK", name ="armflash_emgx",        },{                onlytargetcategory = "VTOL", badtargetcategory = "SCOUT", name ="armflash_emgxaa",        },}, windgenerator = 0, workertime = 0, reclaimspeed= 0, customparams ={tier = 0, tedclass = "vehicle", func ="aiv", requiretech = "KbotLab", morphdef ={            into = 'armyork', cmdname = [[Panther]], text = 'Morph to Phalanx', require = 'Tech2',}, maxrange = 420, }, }}

