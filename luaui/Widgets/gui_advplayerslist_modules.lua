--- Defines AdvPlayersList column modules and related metadata
---@param pics table
---@param drawAllyButton boolean
---@return table modules
---@return table moduleRefs
---@return table m_point
---@return table m_take
return function(pics, drawAllyButton)
	local moduleRefs = {}
	local position = 1

	local function defineModule(key, data)
		data.position = position
		position = position + 1
		moduleRefs[key] = data
		return data
	end

	local indent = defineModule("indent", {
		name = "indent",
		spec = true,
		play = true,
		active = true,
		default = true,
		width = 9,
		posX = 0,
		pic = pics["indentPic"],
		noPic = true,
	})

	defineModule("allyID", {
		name = "allyid",
		spec = true,
		play = true,
		active = false,
		width = 17,
		posX = 0,
		pic = pics["idPic"],
	})

	defineModule("ID", {
		name = "id",
		spec = true,
		play = true,
		active = false,
		width = 17,
		posX = 0,
		pic = pics["idPic"],
	})

	defineModule("playerID", {
		name = "playerid",
		spec = true,
		play = true,
		active = false,
		width = 17,
		posX = 0,
		pic = pics["idPic"],
	})

	defineModule("rank", {
		name = "rank",
		spec = true,
		play = true,
		active = true,
		default = false,
		width = 18,
		posX = 0,
		pic = pics["rank6"],
	})

	defineModule("country", {
		name = "country",
		spec = true,
		play = true,
		active = true,
		default = true,
		width = 20,
		posX = 0,
		pic = pics["countryPic"],
	})

	defineModule("side", {
		name = "side",
		spec = true,
		play = true,
		active = false,
		width = 18,
		posX = 0,
		pic = pics["sidePic"],
	})

	defineModule("skill", {
		name = "skill",
		spec = true,
		play = true,
		active = false,
		width = 18,
		posX = 0,
		pic = pics["tsPic"],
	})

	defineModule("name", {
		name = "name",
		spec = true,
		play = true,
		active = true,
		alwaysActive = true,
		width = 10,
		posX = 0,
		noPic = true,
		picGap = 7,
	})

	defineModule("cpuping", {
		name = "cpuping",
		spec = true,
		play = true,
		active = true,
		width = 24,
		posX = 0,
		pic = pics["cpuPic"],
	})

	defineModule("resources", {
		name = "resources",
		spec = true,
		play = true,
		active = true,
		width = 28,
		posX = 0,
		pic = pics["resourcesPic"],
		picGap = 7,
	})

	defineModule("income", {
		name = "income",
		spec = true,
		play = true,
		active = false,
		width = 28,
		posX = 0,
		pic = pics["incomePic"],
		picGap = 7,
	})

	defineModule("share", {
		name = "share",
		spec = false,
		play = true,
		active = true,
		width = 50,
		posX = 0,
		pic = pics["sharePic"],
	})

	defineModule("chat", {
		name = "chat",
		spec = false,
		play = true,
		active = false,
		width = 18,
		posX = 0,
		pic = pics["chatPic"],
	})

	local alliance = defineModule("alliance", {
		name = "ally",
		spec = false,
		play = true,
		active = true,
		width = 16,
		posX = 0,
		pic = pics["allyPic"],
		noPic = false,
	})

	if not drawAllyButton then
		alliance.width = 0
	end

	local modules = {
		indent,
		moduleRefs.rank,
		moduleRefs.country,
		moduleRefs.allyID,
		moduleRefs.ID,
		moduleRefs.playerID,
		-- moduleRefs.side,
		moduleRefs.name,
		moduleRefs.skill,
		moduleRefs.resources,
		moduleRefs.income,
		moduleRefs.cpuping,
		moduleRefs.alliance,
		moduleRefs.share,
		moduleRefs.chat,
	}

	local m_point = {
		active = true,
		default = true,
	}

	local m_take = {
		active = true,
		default = true,
		pic = pics["takePic"],
	}

	return modules, moduleRefs, m_point, m_take
end

