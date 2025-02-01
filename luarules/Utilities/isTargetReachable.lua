--This function process result of Spring.PathRequest() to say whether target is reachable or not
function Spring.Utilities.IsTargetReachable (moveID, ox,oy,oz,tx,ty,tz,radius)
	local result,lastcoordinate, waypoints
	local path = Spring.RequestPath( moveID,ox,oy,oz,tx,ty,tz, radius)
	if path then
		local waypoint = path:GetPathWayPoints() --get crude waypoint (low chance to hit a 10x10 box). NOTE; if waypoint don't hit the 'dot' is make reachable build queue look like really far away to the GetWorkFor() function.
		local finalCoord = waypoint[#waypoint]
		if finalCoord then --unknown why sometimes NIL
			local dx, dz = finalCoord[1]-tx, finalCoord[3]-tz
			local dist = math.sqrt(dx*dx + dz*dz)
			if dist <= radius+20 then --is within radius?
				result = "reach"
				lastcoordinate = finalCoord
				waypoints = waypoint
			else
				result = "outofreach"
				lastcoordinate = finalCoord
				waypoints = waypoint
			end
		end
	else
		result = "noreturn"
		lastcoordinate = nil
		waypoints = nil
	end
	return result, lastcoordinate, waypoints
end