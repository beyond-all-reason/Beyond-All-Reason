local Contract = VFS.Include("modules/start/contract.lua") ---@type StartContract

---@param cx number
---@param cz number
---@return string
local function compassName(cx, cz)
	local fx, fz = cx / Game.mapSizeX, cz / Game.mapSizeZ
	local ns = (fz < 0.33) and "N" or (fz > 0.66) and "S" or ""
	local ew = (fx < 0.33) and "W" or (fx > 0.66) and "E" or ""
	local short = ns .. ew
	return short ~= "" and short or "Center"
end

Policies.On(Contract.Facts)
	.Default(Contract.Facts.Areas, function(ctx)
		local boxes = ctx.resolveBoxes()
		local areas = {} ---@type StartArea[]
		if boxes.explicit and boxes.byAllyTeam then
			local ids = {}
			for allyTeamID in pairs(boxes.byAllyTeam) do
				ids[#ids + 1] = allyTeamID
			end
			table.sort(ids)
			for _, allyTeamID in ipairs(ids) do
				local entry = boxes.byAllyTeam[allyTeamID]
				local ring = entry and not entry.wholeMap and entry.boxes and entry.boxes[1]
				if ring and #ring >= 3 then
					local anchors = {}
					for i, pt in ipairs(ring) do
						anchors[i] = { x = pt[1], z = pt[2], strength = pt[3] }
					end
					areas[#areas + 1] = {
						allyTeam = allyTeamID + 1 --[[@as integer]],
						name = entry.nameShort,
						anchors = anchors,
						source = boxes.source or "modoption",
					}
				end
			end
			return areas
		end
		local spring = ctx.springRepo
		local gaia = spring.GetGaiaTeamID and spring.GetGaiaTeamID() or nil
		local gaiaAlly = gaia and spring.GetTeamAllyTeamID and spring.GetTeamAllyTeamID(gaia) or nil
		local mapX, mapZ = Game.mapSizeX, Game.mapSizeZ
		for _, allyTeamID in ipairs(spring.GetAllyTeamList() or {}) do
			if allyTeamID ~= gaiaAlly then
				local xmin, zmin, xmax, zmax = spring.GetAllyTeamStartBox(allyTeamID)
				if xmin and xmax and zmin and zmax and xmax > xmin and zmax > zmin then
					local wholeMap = xmin <= 0 and zmin <= 0 and xmax >= mapX and zmax >= mapZ
					if not wholeMap then
						areas[#areas + 1] = {
							allyTeam = allyTeamID + 1 --[[@as integer]],
							name = compassName((xmin + xmax) * 0.5, (zmin + zmax) * 0.5),
							anchors = {
								{ x = xmin, z = zmin },
								{ x = xmax, z = zmin },
								{ x = xmax, z = zmax },
								{ x = xmin, z = zmax },
							},
							source = "engine",
						}
					end
				end
			end
		end
		return areas
	end)
	.Default(Contract.Facts.Positions, function(ctx)
		local spring = ctx.springRepo
		local out = {} ---@type StartPosition[]
		local gaia = spring.GetGaiaTeamID and spring.GetGaiaTeamID() or nil
		for _, teamID in ipairs(spring.GetTeamList() or {}) do
			if teamID ~= gaia then
				local x, _, z = spring.GetTeamStartPosition(teamID)
				if x and z and (x > 0 or z > 0) then
					local allyTeamID = spring.GetTeamAllyTeamID(teamID) or 0
					out[#out + 1] = { allyTeam = allyTeamID + 1, teamID = teamID, x = x, z = z }
				end
			end
		end
		return out
	end)
