---@class RegionProblems
local Problems = {}

---@param ctx RegionSetContext<Region>
---@param index integer
---@param message string
---@param at { x: number, z: number }|nil where on the region, when that says more than the region itself
function Problems.OfRegion(ctx, index, message, at)
	ctx.problems[#ctx.problems + 1] =
		{ message = message, region = ctx.regions[index], name = ctx.names[index], at = at }
end

---@param ctx RegionSetContext<Region>
---@param message string
---@param at { x: number, z: number }|nil
function Problems.OfSet(ctx, message, at)
	ctx.problems[#ctx.problems + 1] = { message = message, at = at }
end

---@param problem RegionProblem
---@return string
function Problems.Line(problem)
	return problem.name and (problem.name .. ": " .. problem.message) or problem.message
end

return Problems
