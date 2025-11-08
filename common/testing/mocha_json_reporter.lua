local function formatTimestamp(ts)
	return os.date("%Y-%m-%dT%H:%M:%S", ts)
end

local MochaJSONReporter = {}

function MochaJSONReporter:new()
	local obj = {
		totalTests = 0,
		totalPasses = 0,
		totalSkipped = 0,
		totalFailures = 0,
		startTime = nil,
		endTime = nil,
		duration = nil,
		tests = {},
		skipped = {}
	}
	setmetatable(obj, self)
	self.__index = self
	return obj
end

function MochaJSONReporter:startTests()
	self.startTime = os.time()
end

function MochaJSONReporter:endTests(duration)
	self.endTime = os.time()
	self.duration = duration
end

function MochaJSONReporter:extractError(text)
	local errorIndex = text:match('^%[string "[%p%a%s]*%"]:[%d]+:().*')
	if errorIndex and errorIndex > 0 then
		text = text:sub(errorIndex + 1)
		return text
	end
	errorIndex = text:match('^%[t=[%d%.:]*%]%[f=[%-%d]*%] ().*')
	if errorIndex and errorIndex > 0 then
		text = text:sub(errorIndex)
	end
	return text
end

function MochaJSONReporter:testResult(label, filePath, success, skipped, duration, errorMessage)
	local result = {
		title = label,
		fullTitle = label,
		file = filePath,
		duration = duration,
	}
	if skipped then
		self.totalSkipped = self.totalSkipped + 1
		result.err = {}
	elseif success then
		self.totalPasses = self.totalPasses + 1
		result.err = {}
	else
		self.totalFailures = self.totalFailures + 1
		if errorMessage ~= nil then
			result.err = {
				message = self:extractError(errorMessage),
				stack = errorMessage
			}
		else
			result.err = {
				message = "<unknown error>",
			}
		end
	end

	self.totalTests = self.totalTests + 1
	self.tests[#(self.tests) + 1] = result
	if skipped then
		self.skipped[#(self.skipped) + 1] = {fullTitle = label}
	end
end

function MochaJSONReporter:report(filePath)
	local output = {
		["stats"] = {
			["suites"] = 1,
			["tests"] = self.totalTests,
			["passes"] = self.totalPasses,
			["pending"] = 0,
			["skipped"] = self.totalSkipped,
			["failures"] = self.totalFailures,
			["start"] = formatTimestamp(self.startTime),
			["end"] = formatTimestamp(self.endTime),
			["duration"] = self.duration
		},
		["tests"] = self.tests,
		["pending"] = self.skipped
	}

	local encoded = Json.encode(output)

	local file = io.open(filePath, "w")
	file:write(encoded)
	file:close()
end

return MochaJSONReporter
