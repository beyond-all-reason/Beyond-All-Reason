local function enum(...)
	local args = { ... }
	local result = {}
	for _, v in ipairs(args) do
		result[v] = v
	end
	return result
end

local TEST_RESULT = enum(
	"PASS",
	"FAIL",
	"SKIP",
	"ERROR"
)

local function clamp(min, max, num)
	if (num < min) then
		return min
	elseif (num > max) then
		return max
	end
	return num
end

local function rgbToColorCode(r, g, b)
	local rs = clamp(1, 255, math.round(255 * r))
	local gs = clamp(1, 255, math.round(255 * g))
	local bs = clamp(1, 255, math.round(255 * b))
	return "\255" .. string.char(rs) .. string.char(gs) .. string.char(bs)
end

local function rgbReset()
	return rgbToColorCode(0.85, 0.85, 0.85)
end

local function formatTestResult(testResult, noColor)
	local resultColor
	local resetColor
	if noColor then
		resultColor = ""
		resetColor = ""
	else
		if testResult.result == TEST_RESULT.PASS then
			resultColor = rgbToColorCode(0, 1, 0)
		elseif testResult.result == TEST_RESULT.FAIL then
			resultColor = rgbToColorCode(1, 0, 0)
		elseif testResult.result == TEST_RESULT.SKIP then
			resultColor = rgbToColorCode(1, 0.8, 0)
		elseif testResult.result == TEST_RESULT.ERROR then
			resultColor = rgbToColorCode(0.8, 0, 0.8)
		end
		resetColor = rgbReset()
	end

	local resultStr = resultColor .. testResult.result .. resetColor
	local s = string.format("%s: %s", resultStr, testResult.label)
	if testResult.frames ~= nil then
		s = s .. " [" .. testResult.frames .. " frames]"
	end
	if testResult.milliseconds ~= nil then
		s = s .. " [" .. testResult.milliseconds .. " ms]"
	end
	if testResult.error ~= nil then
		s = s .. " | " .. testResult.error
	end
	return s
end

return {
	TEST_RESULT = TEST_RESULT,
	formatTestResult = formatTestResult,
}
