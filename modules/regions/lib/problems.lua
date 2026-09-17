---@class RegionProblems helpers for set-check stages to record a problem and its location, and for callers to print one
local Problems = {}

---@param ctx RegionSetContext
---@param index integer the region's place in the set
---@param message string
function Problems.OfRegion(ctx, index, message)
	ctx.problems[#ctx.problems + 1] = { message = message, region = ctx.regions[index], name = ctx.names[index] }
end

---@param ctx RegionSetContext
---@param message string
---@param at { x: number, z: number }|nil where on the map to look: the first place the set falls short
function Problems.OfSet(ctx, message, at)
	ctx.problems[#ctx.problems + 1] = { message = message, at = at }
end

---@param problem RegionProblem
---@return string the message, led by the region's name when it is about one
function Problems.Line(problem)
	return problem.name and (problem.name .. ": " .. problem.message) or problem.message
end

return Problems
