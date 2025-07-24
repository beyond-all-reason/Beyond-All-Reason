if not math.isInRect then
	function math.isInRect(x, y, BLcornerX, BLcornerY, TRcornerX, TRcornerY)
		return x >= BLcornerX and x <= TRcornerX and y >= BLcornerY and y <= TRcornerY
	end
end

if not math.cross_product then
		function math.cross_product (px, pz, ax, az, bx, bz)
		return ((px - bx) * (az - bz) - (ax - bx) * (pz - bz))
	end
end

if not math.triangulate then
	-- accepts an array of polygons (where a polygon is an array of {x, z} vertices), and returns an array of counterclockwise triangles
	function math.triangulate(polies)
		local triangles = {}
		local trianglesCount = 0
		local poliesCount = #polies
		for j = 1, #polies do
			local polygon = polies[j]

			-- find out clockwisdom
			poliesCount = poliesCount + 1
			polygon[poliesCount] = polygon[1]
			local clockwise = 0
			for i = 2, #polygon do
				clockwise = clockwise + (polygon[i - 1][1] * polygon[i][2]) - (polygon[i - 1][2] * polygon[i][1])
			end
			polygon[#polygon] = nil
			clockwise = (clockwise < 0)

			-- the van gogh concave polygon triangulation algorithm: cuts off ears
			-- is pretty shitty at O(V^3) but was easy to code and it's typically only done once anyway
			while #polygon > 2 do

				-- get a candidate ear
				local triangle
				local c0, c1, c2 = 0
				local candidate_ok = false
				while not candidate_ok do

					c0 = c0 + 1
					c1, c2 = c0 + 1, c0 + 2
					if c1 > #polygon then
						c1 = c1 - #polygon
					end
					if c2 > #polygon then
						c2 = c2 - #polygon
					end
					triangle = {
						polygon[c0][1], polygon[c0][2],
						polygon[c1][1], polygon[c1][2],
						polygon[c2][1], polygon[c2][2],
					}

					-- make sure the ear is of proper rotation but then make it counter-clockwise
					local dir = math.cross_product(triangle[5], triangle[6], triangle[1], triangle[2], triangle[3], triangle[4])
					if (dir < 0) == clockwise then
						if dir > 0 then
							local temp = triangle[5]
							triangle[5] = triangle[3]
							triangle[3] = temp
							temp = triangle[6]
							triangle[6] = triangle[4]
							triangle[4] = temp
						end

						-- check if no point lies inside the triangle
						candidate_ok = true
						for i = 1, #polygon do
							if i ~= c0 and i ~= c1 and i ~= c2 then
								local current_pt = polygon[i]
								if (math.cross_product(current_pt[1], current_pt[2], triangle[1], triangle[2], triangle[3], triangle[4]) < 0)
									and (math.cross_product(current_pt[1], current_pt[2], triangle[3], triangle[4], triangle[5], triangle[6]) < 0)
									and (math.cross_product(current_pt[1], current_pt[2], triangle[5], triangle[6], triangle[1], triangle[2]) < 0)
								then
									candidate_ok = false
								end
							end
						end
					end
				end

				-- cut off ear
				trianglesCount = trianglesCount + 1
				triangles[trianglesCount] = triangle
				table.remove(polygon, c1)
			end
		end

		return triangles
	end
end

if not math.closestPointOnCircle then
	function math.closestPointOnCircle(centerX, centerZ, radius, targetX, targetZ)
        local dx = targetX - centerX
        local dz = targetZ - centerZ
        local dist = math.diag(dx, dz)
        if dist == 0 then
            -- Target is exactly at center; choose arbitrary point on circle
            return centerX + radius, centerZ
        end
        local scale = radius / dist
        local closestX = centerX + dx * scale
        local closestZ = centerZ + dz * scale
        return closestX, closestZ
    end
end

if not math.HSLtoRGB then
	function math.HSLtoRGB(ch, cs, cl)
		if cs == 0 then
			return cl, cl, cl
		end

		local cr, cg, cb
		local temp2
		if cl < 0.5 then
			temp2 = cl * (cl + cs)
		else
			temp2 = (cl + cs) - (cl * cs)
		end

		local temp1 = 2 * cl - temp2
		local tempr = ch + 1 / 3

		if tempr > 1 then
			tempr = tempr - 1
		end
		local tempg = ch
		local tempb = ch - 1 / 3
		if tempb < 0 then
			tempb = tempb + 1
		end

		if tempr < 1 / 6 then
			cr = temp1 + (temp2 - temp1) * 6 * tempr
		elseif tempr < 0.5 then
			cr = temp2
		elseif tempr < 2 / 3 then
			cr = temp1 + (temp2 - temp1) * ((2 / 3) - tempr) * 6
		else
			cr = temp1
		end

		if tempg < 1 / 6 then
			cg = temp1 + (temp2 - temp1) * 6 * tempg
		elseif tempg < 0.5 then
			cg = temp2
		elseif tempg < 2 / 3 then
			cg = temp1 + (temp2 - temp1) * ((2 / 3) - tempg) * 6
		else
			cg = temp1
		end

		if tempb < 1 / 6 then
			cb = temp1 + (temp2 - temp1) * 6 * tempb
		elseif tempb < 0.5 then
			cb = temp2
		elseif tempb < 2 / 3 then
			cb = temp1 + (temp2 - temp1) * ((2 / 3) - tempb) * 6
		else
			cb = temp1
		end

		return cr, cg, cb
	end


	if not math.distance2dSquared then
		function math.distance2dSquared(x1, z1, x2, z2)
			local x = x1 - x2
			local z = z1 - z2
			return x * x + z * z
		end
	end

	if not math.distance2d then
		function math.distance2d(x1, z1, x2, z2)
			return math.diag(x1 - x2, z1 - z2)
		end
	end

	if not math.distance3dSquared then
		function math.distance3dSquared(x1, y1, z1, x2, y2, z2)
			local x = x1 - x2
			local y = y1 - y2
			local z = z1 - z2
			return x * x + y * y + z * z
		end
	end

	if not math.distance3d then
		function math.distance3d(x1, y1, z1, x2, y2, z2)
			return math.diag(x1 - x2, y1 - y2, z1 - z2)
		end
	end

	if not math.getClosestPosition then
		---Gets the closest position out of a list to given coordinates. 2d.
		---@param x table
		---@param z table
		---@param positions table must have fields .x and .z
		function math.getClosestPosition(x, z, positions)
			if not positions or #positions <= 0 then
				return
			end
			local bestPos
			local bestDist = math.huge
			for i = 1, #positions do
				local pos = positions[i]
				local dx, dz = x - pos.x, z - pos.z
				local dist = dx * dx + dz * dz
				if dist < bestDist then
					bestPos = pos
					bestDist = dist
				end
			end
			return bestPos
		end
	end
end
