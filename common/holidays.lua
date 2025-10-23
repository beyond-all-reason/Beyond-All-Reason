if not Spring.GetModOptions then
    return
end

local currentDay = Spring.GetModOptions().date_day
local currentMonth = Spring.GetModOptions().date_month
local currentYear = Spring.GetModOptions().date_year

-- Function to calculate Easter Sunday for a given year. Magic.
local function EasterDate(year)
    local a = year % 19
    local b = math.floor(year / 100)
    local c = year % 100
    local d = math.floor(b / 4)
    local e = b % 4
    local f = math.floor((b + 8) / 25)
    local g = math.floor((b - f + 1) / 3)
    local h = (19 * a + b - d - g + 15) % 30
    local i = math.floor(c / 4)
    local k = c % 4
    local l = (32 + 2 * e + 2 * i - h - k) % 7
    local m = math.floor((a + 11 * h + 22 * l) / 451)
    local month = math.floor((h + l - 7 * m + 114) / 31)
    local day = ((h + l - 7 * m + 114) % 31) + 1

    return year, month, day
end

local function GetEasterStartEnd()
    local easterYear, easterMonth, easterDay = EasterDate(currentYear)
    local firstDay = easterDay - 6 -- We start at Monday before Easter
    local firstMonth = easterMonth
    local lastDay = easterDay + 1 -- We end at Monday after Easter
    local lastMonth = easterMonth

    if easterMonth%2 == 0 then -- Easter is in April - 30 days month
        if firstDay < 1 then
            firstDay = firstDay + 31
            firstMonth = firstMonth - 1
        end
        if lastDay > 30 then
            lastDay = lastDay - 30
            lastMonth = lastMonth + 1
        end

    else -- Easter is in March or May - 31 days month
        if firstDay < 1 then
            firstDay = firstDay + 30
            firstMonth = firstMonth - 1
        end
        if lastDay > 31 then
            lastDay = lastDay - 31
            lastMonth = lastMonth + 1
        end
    end

    return {
        firstDay = firstDay,
        firstMonth = firstMonth,
        lastDay = lastDay,
        lastMonth = lastMonth,
        easterDay = easterDay,
        easterMonth = easterMonth,
    }
end

-- FIXME: This doesn't support events that start and end in different years. Don't do that for now. Split it into two events if you have to do that.
local holidaysList = {
	-- Static
	["aprilfools"] = {
		firstDay = { day = 1, month = 4},
		lastDay = { day = 7, month = 4},
        specialDay = { day = 1, month = 4}
	},
	["spooktober"] = {
		firstDay = { day = 17, month = 10},
		lastDay = { day = 31, month = 10},
        specialDay = { day = 31, month = 10}
	},
	["xmas"] = {
		firstDay = { day = 12, month = 12},
		lastDay = { day = 31, month = 12},
        specialDay = { day = 24, month = 12}
	},

    -- We split these into two events because yes
    ["newyearbefore"] = {
		firstDay = { day = 31, month = 12},
		lastDay = { day = 31, month = 12},
        specialDay = { day = 31, month = 12}
	},
    ["newyearafter"] = {
		firstDay = { day = 1, month = 1},
		lastDay = { day = 1, month = 1},
        specialDay = { day = 1, month = 1}
	},


	-- Dynamic
    ["easter"] = {
		firstDay = { day = GetEasterStartEnd().firstDay, month = GetEasterStartEnd().firstMonth},
		lastDay = { day = GetEasterStartEnd().lastDay, month = GetEasterStartEnd().lastMonth},
        specialDay = { day = GetEasterStartEnd().easterDay, month = GetEasterStartEnd().easterMonth}
	},
}

return holidaysList