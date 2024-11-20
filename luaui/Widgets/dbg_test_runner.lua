function widget:GetInfo()
	return {
		name = "Test Runner",
		desc = "Run tests with: /runtests <pattern1> <pattern2> ...",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
		handler = true,
	}
end

if not Spring.Utilities.IsDevMode() or not Spring.Utilities.Gametype.IsSinglePlayer() then
	return
end

local Proxy = VFS.Include('common/testing/synced_proxy.lua')
local MochaJSONReporter = VFS.Include('common/testing/mocha_json_reporter.lua')
local Assertions = VFS.Include('common/testing/assertions.lua')
local TestResults = VFS.Include('common/testing/results.lua')
local Util = VFS.Include('common/testing/util.lua')
local Mock = VFS.Include('common/testing/mock.lua')

local rpc = VFS.Include('common/testing/rpc.lua'):new()

local LOG_LEVEL = LOG.INFO

local initialWidgetActive = {}

local config = {
	returnTimeout = 30,
	waitTimeout = 5 * 30,
	showAllResults = true,
	noColorOutput = false,
	quitWhenDone = false,
	gameStartTestPatterns = nil,
	testResultsFilePath = nil,
	testRoots = {
		"LuaUI/Widgets/tests",
		"LuaUI/Tests",
	},
}

local testReporter = nil

-- utils
-- =====
local function log(level, str, ...)
	if level < LOG_LEVEL then
		return
	end
	Spring.Log(
		widget:GetInfo().name,
		LOG.NOTICE,
		str
	)
end

local function logStartTests()
	if config.testResultsFilePath == nil then
		return
	end

	testReporter = MochaJSONReporter:new()
	testReporter:startTests()
end

local function logEndTests(duration)
	if config.testResultsFilePath == nil then
		return
	end
	testReporter:endTests(duration)

	testReporter:report(config.testResultsFilePath)
end

local function logTestResult(testResult)
	if config.testResultsFilePath == nil then
		return
	end

	testReporter:testResult(
		testResult.label,
		testResult.filename,
		(testResult.result == TestResults.TEST_RESULT.PASS),
		testResult.milliseconds,
		testResult.error
	)
end

local function registerCallins(target, callback, callins)
	local callinNames = {
		'UnitCreated',
		'UnitFinished',
		'UnitFromFactory',
		'UnitReverseBuilt',
		'UnitDestroyed',
		'RenderUnitDestroyed',
		'UnitTaken',
		'UnitGiven',
		'UnitIdle',
		'UnitCommand',
		'UnitCmdDone',
		'UnitDamaged',
		--'UnitStunned',
		'UnitEnteredRadar',
		'UnitEnteredLos',
		'UnitLeftRadar',
		'UnitLeftLos',
		'UnitEnteredUnderwater',
		'UnitEnteredWater',
		'UnitEnteredAir',
		'UnitLeftUnderwater',
		'UnitLeftWater',
		'UnitLeftAir',
		'UnitSeismicPing',
		'UnitLoaded',
		'UnitUnloaded',
		'UnitCloaked',
		'UnitDecloaked',
		'UnitMoveFailed',
		'UnitHarvestStorageFull',
	}

	for _, callinName in ipairs(callinNames) do
		if callins == nil or table.contains(callins, callinName) then
			target[callinName] = function(...)
				local args = { ... }
				table.remove(args, 1)
				callback(callinName, args)
			end
		end
	end
end

local function matchesPatterns(str, patterns)
	for _, p in ipairs(patterns) do
		if string.match(str, p) then
			return true
		end
	end
	return false
end

-- main code
-- =========

local function findTestFiles(directory, patterns, rootDirectory, result)
	if rootDirectory == nil then
		if directory:sub(-1) ~= '/' then
			directory = directory .. '/'
		end
		rootDirectory = directory
	end

	if result == nil then
		result = {}
	end

	for _, filename in ipairs(VFS.DirList(directory, "*", VFS.RAW_FIRST)) do
		local relativePath = string.sub(filename, string.len(rootDirectory) + 1)
		local withoutExtension = Util.removeFileExtension(relativePath)
		if patterns == nil or #patterns == 0 or matchesPatterns(withoutExtension, patterns) then
			log(LOG.INFO, "Found test file: " .. relativePath)
			result[#result + 1] = {
				filename = filename,
				label = relativePath,
			}
		end
	end

	for _, subDir in ipairs(VFS.SubDirs(directory, "*", VFS.RAW_FIRST)) do
		findTestFiles(subDir, patterns, rootDirectory, result)
	end

	return result
end

local function findAllTestFiles(patterns)
	log(LOG.DEBUG, "[findAllTestFiles] " .. table.toString({
		patterns = patterns,
	}))
	local result = {}
	for _, path in ipairs(config.testRoots) do
		for _, testFileInfo in ipairs(findTestFiles(path, patterns)) do
			result[#result + 1] = testFileInfo
		end
	end
	return result
end

local function displayTestResults(results)
	log(LOG.INFO, "=====TEST RESULTS=====")
	for _, testResult in ipairs(results) do
		log(LOG.INFO, TestResults.formatTestResult(testResult, config.noColorOutput))
	end
end

local gameTimer
local runTestsTimer
local testTimer

local function getGameTime()
	if gameTimer ~= nil then
		return Spring.DiffTimers(Spring.GetTimer(), gameTimer, true)
	end
end

local function getRunTestsTime()
	if runTestsTimer ~= nil then
		return Spring.DiffTimers(Spring.GetTimer(), runTestsTimer, true)
	end
end

local function getTestTime()
	if testTimer ~= nil then
		return Spring.DiffTimers(Spring.GetTimer(), testTimer, true)
	end
end

local testRunState
local activeTestState
local resumeState
local returnState
local callinState
local spyControls

local function resetTestRunState()
	log(LOG.DEBUG, "[resetTestRunState]")
	testRunState = {
		runningTests = false,
		files = {},
		filesIndex = nil,
		results = {},
	}
end

local function resetActiveTestState()
	log(LOG.DEBUG, "[resetActiveTestState]")
	activeTestState = {
		coroutine = nil,
		environment = nil,
		startFrame = nil,
		filename = nil,
		label = nil,
	}
end

local function resetResumeState()
	log(LOG.DEBUG, "[resetResumeState]")
	resumeState = {
		predicate = nil,
		timeoutExpireFrame = nil,
	}
end

local function resetReturnState()
	log(LOG.DEBUG, "[resetReturnState]")
	returnState = {
		waitingForReturnID = nil,
		success = nil,
		pendingValueOrError = nil,
		timeoutExpireFrame = nil,
	}
end

local function resetCallinState()
	log(LOG.DEBUG, "[resetCallinState]")
	callinState = {
		buffer = {},
	}
end

local function resetSpyCtrls()
	log(LOG.DEBUG, "[resetSpyCtrls]")
	spyControls = {}
end

local function resetState()
	log(LOG.DEBUG, "[resetState]")
	resetTestRunState()
	resetActiveTestState()
	resetResumeState()
	resetReturnState()
	resetCallinState()
	resetSpyCtrls()
end

resetState()

registerCallins(widget, function(name, args)
	if not testRunState.runningTests then
		return
	end

	if callinState.buffer[name] == nil then
		callinState.buffer[name] = {}
	end
	callinState.buffer[name][#(callinState.buffer[name]) + 1] = args
end)

local MAX_START_TESTS_ATTEMPTS = 10
local queuedStartTests = false
local queuedStartTestsPatterns = nil
local startTestsAttempts = 0
local function queueStartTests(patterns)
	queuedStartTests = true
	queuedStartTestsPatterns = patterns
	startTestsAttempts = 0
end

local function startTests(patterns)
	log(LOG.DEBUG, "[startTests] " .. table.toString({
		patterns = patterns,
	}))

	if testRunState.runningTests then
		log(LOG.WARNING, "Tests are already running!")
		return
	end

	if not Spring.GetGameRulesParam("isSyncedProxyEnabled") then
		log(
			LOG.ERROR,
			"The Synced Proxy gadget is required in order to run tests. It requires single player, dev mode, " ..
				"and cheating  to be enabled."
		)
		return
	end

	if Spring.GetModOptions().deathmode ~= 'neverend' then
		log(
			LOG.ERROR,
			"deathmode='neverend' game end mode is required in order to run tests, so that the game stays " ..
				"active between tests"
		)
		return
	end

	if not Spring.IsCheatingEnabled() then
		if not queuedStartTests then
			-- enable cheats, then wait for it to go through
			log(LOG.INFO, "Cheats are disabled; attempting to enable them...")
			Spring.SendCommands("cheat")
			queueStartTests(patterns)
			return
		elseif startTestsAttempts < MAX_START_TESTS_ATTEMPTS then
			-- return and try again next step
			startTestsAttempts = startTestsAttempts + 1
			return
		else
			-- ran out of retries, so fail
			log(LOG.ERROR, "Could not enable cheats; tests cannot be run.")
			queuedStartTests = false
			return
		end
	end

	queuedStartTests = false

	logStartTests()

	resetState()

	log(LOG.NOTICE, "=====FINDING TESTS=====")

	if type(patterns) == "string" then
		patterns = { patterns }
	end

	testRunState.files = findAllTestFiles(patterns)

	if testRunState.files == nil or #(testRunState.files) == 0 then
		log(LOG.INFO, "no test files found")
		return
	end

	testRunState.runningTests = true
	testRunState.index = 1

	log(LOG.NOTICE, "=====RUNNING TESTS=====")

	runTestsTimer = Spring.GetTimer()
end

local function finishTest(result)
	for _, control in ipairs(spyControls) do
		control.remove()
	end

	result.index = result.index or testRunState.index
	result.label = result.label or activeTestState.label
	result.filename = result.filename or activeTestState.filename
	if activeTestState and activeTestState.startFrame and result.frames == nil then
		result.frames = Spring.GetGameFrame() - activeTestState.startFrame
	end
	result.milliseconds = getTestTime()

	log(LOG.NOTICE, TestResults.formatTestResult(result, config.noColorOutput))

	logTestResult(result)

	testRunState.results[#(testRunState.results) + 1] = result

	resetActiveTestState()
	resetResumeState()
	resetReturnState()
	resetCallinState()

	if testRunState.index < #(testRunState.files) then
		testRunState.index = testRunState.index + 1
	else
		-- done
		testRunState.index = nil
		testRunState.runningTests = false
		if config.showAllResults then
			displayTestResults(testRunState.results)
		end

		logEndTests(getRunTestsTime())

		if config.quitWhenDone then
			Spring.SendCommands("quitforce")
		end
	end
end

local function createNestedProxy(prefix, path)
	return setmetatable({}, {
		__index = function(_, key)
			local newPath = path and (path .. "." .. key) or key
			return createNestedProxy(prefix, newPath)
		end,
		__call = function(_, ...)
			local args = { ... }
			local serializedFn, returnID = rpc:serializeFunctionCall(path, args)

			returnState = {
				waitingForReturnID = returnID,
				success = nil,
				pendingValueOrError = nil,
				timeoutExpireFrame = Spring.GetGameFrame() + config.returnTimeout,
			}

			log(LOG.DEBUG, "[createNestedProxy." .. prefix .. ".send]")
			Spring.SendLuaRulesMsg(prefix .. serializedFn)

			local resumeOk, resumeResult = coroutine.yield()

			log(LOG.DEBUG, "[createNestedProxy." .. prefix .. ".return] " .. table.toString({
				resumeOk = resumeOk,
				resumeResult = resumeResult,
			}))

			if not resumeOk then
				error(resumeResult, 2)
			end

			return unpack(resumeResult)
		end,
	})
end

SyncedProxy = createNestedProxy(Proxy.PREFIX.CALL)

SyncedRun = function(fn)
	local serializedFn, returnID = rpc:serializeFunctionRun(fn, 3)

	returnState = {
		waitingForReturnID = returnID,
		success = nil,
		pendingValueOrError = nil,
		timeoutExpireFrame = Spring.GetGameFrame() + config.returnTimeout,
	}

	log(LOG.DEBUG, "[SyncedRun.send]")
	Spring.SendLuaRulesMsg(Proxy.PREFIX.RUN .. serializedFn)

	local resumeOk, resumeResult = coroutine.yield()

	log(LOG.DEBUG, "[SyncedRun.return] " .. table.toString({
		resumeOk = resumeOk,
		resumeResult = resumeResult,
	}))

	if not resumeOk then
		error(resumeResult, 3)
	end

	return unpack(resumeResult)
end

Test = {
	waitUntil = function(f, timeout, errorOffset)
		timeout = timeout or config.waitTimeout

		resumeState = {
			predicate = f,
			timeoutExpireFrame = Spring.GetGameFrame() + timeout,
		}

		local resumeOk, resumeResult = coroutine.yield()

		log(LOG.DEBUG, "[waitUntil.return] " .. table.toString({
			resumeOk = resumeOk,
			resumeResult = resumeResult,
		}))

		resetResumeState()

		if not resumeOk then
			error(resumeResult, 2 + (errorOffset or 0))
		end
	end,
	waitFrames = function(frames)
		log(LOG.DEBUG, "[waitFrames] " .. frames)
		local startFrame = Spring.GetGameFrame()
		Test.waitUntil(
			function()
				return Spring.GetGameFrame() >= (startFrame + frames)
			end,
			frames + 5,
			1
		)
		log(LOG.DEBUG, "[waitFrames.done]")
	end,
	waitTime = function(milliseconds, timeout)
		log(LOG.DEBUG, "[waitTime] " .. milliseconds)
		local startTimer = Spring.GetTimer()
		Test.waitUntil(
			function()
				return Spring.DiffTimers(Spring.GetTimer(), startTimer, true) >= milliseconds
			end,
			timeout or (milliseconds * 30 / 1000 + 5),
			1
		)
		log(LOG.DEBUG, "[waitTime.done]")
	end,
	waitUntilCallin = function(name, predicate, timeout)
		log(LOG.DEBUG, "[waitUntilCallin] " .. name)
		Test.waitUntil(
			function()
				for _, args in ipairs(callinState.buffer[name] or {}) do
					if predicate == nil or predicate(unpack(args)) then
						return true
					end
				end
				return false
			end,
			timeout,
			1
		)
		callinState.buffer[name] = {}
		log(LOG.DEBUG, "[waitUntilCallin.done]")
	end,
	waitUntilCallinArgs = function(name, expectedArgs)
		Test.waitUntilCallin(name, function(...)
			local currentArgs = { ... }
			for k, v in pairs(expectedArgs) do
				if currentArgs[k] == nil or currentArgs[k] ~= v then
					return false
				end
			end
			return true
		end)
	end,
	spy = function(...)
		local spyCtrl = Mock.spy(...)
		spyControls[#spyControls + 1] = spyCtrl
		return spyCtrl
	end,
	mock = function(...)
		local mockCtrl = Mock.mock(...)
		spyControls[#spyControls + 1] = mockCtrl
		return mockCtrl
	end,
	clearMap = function()
		SyncedRun(function()
			for _, unitID in ipairs(Spring.GetAllUnits()) do
				Spring.DestroyUnit(unitID, false, true, nil, true)
			end
			for _, featureID in ipairs(Spring.GetAllFeatures()) do
				Spring.DestroyFeature(featureID)
			end
		end)
	end,
	clearCallinBuffer = function(name)
		if name ~= nil then
			callinState.buffer[name] = {}
		else
			callinState.buffer = {}
		end
	end,
	prepareWidget = function(widgetName)
		-- Enable widget with locals access and store state for later restoring
		-- through restoreWidget(s).
		assert(widgetHandler.knownWidgets[widgetName] ~= nil)

		initialWidgetActive[widgetName] = widgetHandler.knownWidgets[widgetName].active or false
		if initialWidgetActive[widgetName] then
			widgetHandler:DisableWidgetRaw(widgetName)
		end
		widgetHandler:EnableWidgetRaw(widgetName, true)

		local widget = widgetHandler:FindWidget(widgetName)
		assert(widget)
		return widget
	end,
	restoreWidget = function(widgetName)
		-- Restore a widget enabled status, can be run manually inside test.
		-- Otherwise testrunner will run it automatically through restoreWidgets.
		local wasActive = initialWidgetActive[widgetName]
		initialWidgetActive[widgetName] = nil
		assert(wasActive ~= nil)

		widgetHandler:DisableWidgetRaw(widgetName)
		if wasActive then
			widgetHandler:EnableWidgetRaw(widgetName, false)
		end
	end,
	restoreWidgets = function()
		-- Restore all widgets enabled through prepareWidget.
		-- Can be run manually or just let testrunner call it automatically.
		local allOk = true
		local failed = {}
		for widgetName, _ in pairs(initialWidgetActive) do
			local restoreOk, restoreResult = pcall(Test.restoreWidget, widgetName)
			if not restoreOk then
				allOk = false
				failed[#failed+1] = widgetName
				log(LOG.DEBUG, "[restoreWidgets.error] " .. widgetName .. " " .. tostring(restoreResult))
			end
		end
		if not allOk then
			error("Some widgets failed restoring: " .. table.concat(failed, ", "), 3)
		end
	end,
}

function widget:RecvLuaMsg(msg)
	if not returnState.waitingForReturnID then
		return
	end

	if msg:sub(1, #(Proxy.PREFIX.RETURN)) == Proxy.PREFIX.RETURN then
		local serializedReturn = msg:sub(#Proxy.PREFIX.RETURN + 1)
		local returnOk, returnValueOrError, returnID = rpc:deserializeFunctionReturn(serializedReturn)

		log(LOG.DEBUG, "[RecvLuaMsg] " .. table.toString({
			serializedReturn = serializedReturn,
			returnOk = returnOk,
			returnValue = returnValueOrError,
			returnID = returnID,
		}))

		if returnID == returnState.waitingForReturnID then
			-- this is the return we were waiting for (otherwise we ignore it)
			returnState = {
				waitingForReturnID = nil,
				success = returnOk,
				pendingValueOrError = returnValueOrError,
				timeoutExpireFrame = nil,
			}
		end
	end
end

local function runTestInternal()
	log(LOG.DEBUG, "[runTestInternal]")

	local skipOk, skipResult
	if skip ~= nil then
		log(LOG.DEBUG, "[runTestInternal.skip]")
		skipOk, skipResult = Util.yieldable_pcall(skip)
		log(LOG.DEBUG, "[runTestInternal.skip.done] " .. table.toString({
			skipOk, skipResult
		}))

		if not skipOk then
			log(LOG.DEBUG, "[runTestInternal.skip.error]")
			error(skipResult, 2)
		end

		if skipResult then
			return TestResults.TEST_RESULT.SKIP
		end
	end

	local setupOk, setupResult
	if setup ~= nil then
		log(LOG.DEBUG, "[runTestInternal.setup]")
		setupOk, setupResult = Util.yieldable_pcall(setup)
		log(LOG.DEBUG, "[runTestInternal.setup.done] " .. table.toString({
			setupOk, setupResult
		}))
	else
		log(LOG.DEBUG, "[runTestInternal.setup.skipped]")
		setupOk = true
	end

	local testOk, testResult
	if setupOk then
		log(LOG.DEBUG, "[runTestInternal.test]")
		testOk, testResult = Util.yieldable_pcall(test)
		log(LOG.DEBUG, "[runTestInternal.test.done] " .. table.toString({
			testOk, testResult
		}))
	end

	-- always try to run cleanup
	local cleanupOk, cleanupResult
	if cleanup ~= nil then
		log(LOG.DEBUG, "[runTestInternal.cleanup]")
		cleanupOk, cleanupResult = Util.yieldable_pcall(cleanup)
		log(LOG.DEBUG, "[runTestInternal.cleanup.done] " .. table.toString({
			cleanupOk, cleanupResult
		}))
	else
		log(LOG.DEBUG, "[runTestInternal.cleanup.skipped]")
		cleanupOk = true
	end

	if #initialWidgetActive > 0 then
		log(LOG.DEBUG, "[runTestInternal.restoreWidgets]")
		local restoreOk, restoreResult = pcall(Test.restoreWidgets)
		if not restoreOk then
			log(LOG.DEBUG, "[runTestInternal.restoreWidgets.error]")
			error(restoreResult, 2)
		end
	end

	if not cleanupOk then
		log(LOG.DEBUG, "[runTestInternal.cleanup.error]")
		error(cleanupResult, 2)
	end

	if not setupOk then
		log(LOG.DEBUG, "[runTestInternal.setup.error]")
		error(setupResult, 2)
	end

	if not testOk then
		log(LOG.DEBUG, "[runTestInternal.test.error]")
		error(testResult, 2)
	end

	return TestResults.TEST_RESULT.PASS
end

local function initializeTestEnvironment()
	local env = {
		-- test framework
		Test = Test,
		SyncedProxy = SyncedProxy,
		SyncedRun = SyncedRun,
		__runTestInternal = runTestInternal,
		yieldable_pcall = Util.yieldable_pcall,
		TEST_RESULT = TestResults.TEST_RESULT,

		-- widgets
		widgetHandler = widgetHandler,
		WG = WG,

		-- game
		VFS = VFS,
		Script = Script,
		Spring = Spring,
		Engine = Engine,
		Platform = Platform,
		Game = Game,
		gl = gl,
		GL = GL,
		CMD = CMD,
		CMDTYPE = CMDTYPE,
		LOG = LOG,

		UnitDefs = UnitDefs,
		UnitDefNames = UnitDefNames,
		FeatureDefs = FeatureDefs,
		FeatureDefNames = FeatureDefNames,
		WeaponDefs = WeaponDefs,
		WeaponDefNames = WeaponDefNames,

		pack = Util.pack,
		pcall = pcall,
		io = io,
		os = os,
		math = math,
		debug = debug,
		tracy = tracy,
		table = table,
		string = string,
		package = package,
		--coroutine = coroutine,
		assert = assert,
		error = error,
		print = print,
		next = next,
		pairs = pairs,
		ipairs = ipairs,
		tonumber = tonumber,
		tostring = tostring,
		type = type,
		unpack = unpack,
		select = select,

		Json = Json,
	}

	for k, v in pairs(Assertions) do
		env[k] = v
	end

	return env
end

local function loadTestFromFile(filename)
	if not VFS.FileExists(filename) then
		return false, "missing file: " .. filename
	end

	local text = VFS.LoadFile(filename, VFS.RAW_FIRST)

	if text == nil or text == "" then
		return false, "missing file content: " .. filename
	end

	local chunk, err = loadstring(text, filename)
	if chunk == nil then
		return false, err
	end

	local testEnvironment = initializeTestEnvironment()

	setfenv(chunk, testEnvironment)

	local success, err = pcall(chunk)
	if not success then
		return false, err
	end

	if testEnvironment.test == nil then
		return false, "no test() function"
	end

	setfenv(testEnvironment.__runTestInternal, testEnvironment)

	return true, testEnvironment
end

local function handleReturn()
	if returnState.success == nil and returnState.waitingForReturnID == nil then
		-- no return to handle, so just continue
		return {
			status = "continue",
		}
	end

	if returnState.timeoutExpireFrame ~= nil then
		if Spring.GetGameFrame() >= returnState.timeoutExpireFrame then
			-- resume took too long, result is error
			log(LOG.DEBUG, "[handleReturn] timeout -> error")
			return {
				status = "error",
				error = "waiting for synced return timed out"
			}
		end
	end

	if returnState.waitingForReturnID then
		log(LOG.DEBUG, string.format(
			"[handleReturn] waiting for return ID: %s", returnState.waitingForReturnID
		))
		return {
			status = "wait"
		}
	end

	local tempReturnValue = returnState.pendingValueOrError
	returnState.pendingValueOrError = nil

	if returnState.success then
		-- we're ok to resume
		log(LOG.DEBUG, "[handleReturn] success -> continue")
		resetReturnState()
		return {
			status = "continue",
			returnValue = tempReturnValue
		}
	else
		-- remote function errored
		log(LOG.DEBUG, "[handleReturn] remote error -> error")
		return {
			status = "error",
			error = tempReturnValue,
		}
	end
end

local function handleWait()
	if resumeState.predicate == nil then
		return {
			status = "continue",
		}
	end

	if Spring.GetGameFrame() >= resumeState.timeoutExpireFrame then
		-- resume took too long, result is error
		log(LOG.DEBUG, "[handleWait] timeout -> error")
		return {
			status = "error",
			error = "resume predicate timed out",
		}
	end

	local success, returnOrError = pcall(resumeState.predicate)
	if success then
		-- predicate ran successfully
		if returnOrError then
			-- succeeded, we can resume
			log(LOG.DEBUG, "[handleWait] predicate success + true -> continue")
			resetResumeState()
			return {
				status = "continue"
			}
		else
			-- failed, wait and try again next frame
			return {
				status = "wait"
			}
		end
	else
		-- error during predicate
		log(LOG.DEBUG, "[handleWait] predicate error -> error")
		return {
			status = "error",
			error = returnOrError
		}
	end
end

local function step()
	if queuedStartTests then
		startTests(queuedStartTestsPatterns)
		return
	end

	if not testRunState.runningTests then
		return
	end

	--*result = {
	--	status =
	--		| "continue" (ok to continue to other checks and resuming test)
	--		| "error" (an error occurred, skip directly to resuming test and pass the error for it to be handled)
	--		| "wait" (waiting on something, return immediately)
	--	error = (status="error" only)
	--	returnValue = (status="continue" only, optional)
	--}
	local returnResult = handleReturn()

	if returnResult.status == "wait" then
		log(LOG.DEBUG, "[step] waiting for return")
		return
	end

	local waitResult = handleWait()

	if waitResult.status == "wait" then
		log(LOG.DEBUG, "[step] waiting for explicit wait")
		return
	end

	-- is there a test set up? if not, create one
	if activeTestState.coroutine == nil then
		activeTestState.label = testRunState.files[testRunState.index].label
		activeTestState.filename = testRunState.files[testRunState.index].filename

		local success, envOrError = loadTestFromFile(activeTestState.filename)

		if success then
			log(LOG.DEBUG, "Initializing test: " .. activeTestState.label)
			activeTestState.environment = envOrError
			activeTestState.coroutine = coroutine.create(activeTestState.environment.__runTestInternal)
			activeTestState.startFrame = Spring.GetGameFrame()

			testTimer = Spring.GetTimer()
		else
			finishTest({
				result = TestResults.TEST_RESULT.ERROR,
				error = envOrError
			})
			return
		end
	end

	-- resume the test
	local resumeOk, resumeResult
	if coroutine.status(activeTestState.coroutine) == "suspended" then
		local coroutineOk, coroutineArgs
		if returnResult.returnValue ~= nil then
			coroutineOk = true
			coroutineArgs = { returnResult.returnValue }
		elseif returnResult.status == "error" then
			coroutineOk = false
			coroutineArgs = { returnResult.error }
		elseif waitResult.status == "error" then
			coroutineOk = false
			coroutineArgs = { waitResult.error }
		else
			coroutineOk = true
			coroutineArgs = nil
		end

		log(
			LOG.DEBUG,
			"Resuming test: " .. activeTestState.label .. " with value: " .. table.toString({
				coroutineOk = coroutineOk,
				coroutineArgs = coroutineArgs,
			})
		)

		resumeOk, resumeResult = coroutine.resume(
			activeTestState.coroutine,
			coroutineOk,
			coroutineArgs and unpack(coroutineArgs) or nil
		)
		log(LOG.DEBUG, "Unresuming test: " .. table.toString({
			result = resumeOk,
			error = resumeResult,
		}))
		if not resumeOk then
			-- test fail
			finishTest({
				result = TestResults.TEST_RESULT.FAIL,
				error = resumeResult,
			})
			return
		end
	end

	if coroutine.status(activeTestState.coroutine) == "dead" then
		-- test did not fail or error, so may have been pass or skip
		finishTest({
			result = resumeResult or TestResults.TEST_RESULT.PASS,
		})
	end
end

function widget:GameFrame(frame)
	if config.gameStartTestPatterns ~= nil and frame >= 0 then
		startTests(config.gameStartTestPatterns)
		config.gameStartTestPatterns = nil
	end

	step()
end

function widget:Update(dt)
	if Spring.GetGameFrame() <= 0 then
		step()
	end
end

function widget:Initialize()
	widgetHandler:DisableWidget("Test Runner Watchdog")

	if not Spring.Utilities.IsDevMode() then
		widgetHandler:RemoveWidget(self)
	end

	widgetHandler.actionHandler:AddAction(
		self,
		"runtests",
		function(cmd, optLine, optWords, data, isRepeat, release, actions)
			startTests(Util.splitPhrases(optLine))
		end,
		nil,
		"t"
	)
	widgetHandler.actionHandler:AddAction(
		self,
		"runtestsheadless",
		function(cmd, optLine, optWords, data, isRepeat, release, actions)
			config.noColorOutput = true
			config.quitWhenDone = true
			config.gameStartTestPatterns = Util.splitPhrases(optLine)
			config.testResultsFilePath = "testlog/results.json"

			widgetHandler:EnableWidget("Test Runner Watchdog")
		end,
		nil,
		"t"
	)

	gameTimer = Spring.GetTimer()
end

function widget:Shutdown()
	widgetHandler.actionHandler:RemoveAction("runtests", "t")
	widgetHandler.actionHandler:RemoveAction("runtestsheadless", "t")
end
