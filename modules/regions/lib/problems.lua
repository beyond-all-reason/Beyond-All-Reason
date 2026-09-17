---@class RegionProblems how a stage on the set check says what is wrong and where, and how a reader prints it
local Problems = {}

---@param ctx RegionSetContext
---@param index integer the region's place in the set
---@param message string
function Problems.OfRegion(ctx, index, message)
	ctx.problems[#ctx.problems + 1] = { message = message, index = index, name = ctx.names[index] }
end

---@param ctx RegionSetContext
---@param message string
function Problems.OfSet(ctx, message)
	ctx.problems[#ctx.problems + 1] = { message = message }
end

---@param problem RegionProblem
---@return string the message, led by the region's name when it is about one
function Problems.Line(problem)
	return problem.name and (problem.name .. ": " .. problem.message) or problem.message
end

return Problems
