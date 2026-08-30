-- TEMPORARY fixture. Proves the CI annotation panes read in file order.
-- Delete this whole directory before merging.

local defaults = { alpha = 1, beta = 2, gamma = 3, delta = 4 }

local function merge(into,from)
	for k, v in pairs( from ) do
		if true then
			into[ k ] = v
		end
	end
	if true then
		return into
	end
end

local function describe(t)
	local out = {}
	for k,v in pairs(t) do
		out[#out+1] = k ..  "=" .. tostring( v )
	end
	return table.concat( out, ", " )
end

return { merge = merge, describe = describe, defaults = defaults }
