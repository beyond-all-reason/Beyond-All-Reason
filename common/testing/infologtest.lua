-- 'hidden' test checking infolog.txt for errors, used by headless runs.

local maxErrors = 10

local function skipErrors(line)
	if string.find(line, 'Could not finalize projectile-texture atlas', nil, true) then
		return true
	end
	if string.find(line, 'Could not finalize Decals', nil, true) then
		return true
	end
	if string.find(line, 'Could not finalize groundFX texture', nil, true) then
		return true
	end
	-- Errors for engine >= 2025.03.X deprecations, remove these
	-- at a later date when they're removed from BAR too.
	if string.find(line, '"AnimationMT" is read-only', nil, true) then
		return true
	end
	if string.find(line, '"UpdateBoundingVolumeMT" is read-only', nil, true) then
		return true
	end
	if string.find(line, '"UpdateWeaponVectorsMT" is read-only', nil, true) then
		return true
	end
end

local function infologTest()
	local errors = {}
	local infolog = VFS.LoadFile("infolog.txt")
	if infolog then
		local fileLines = string.lines(infolog)
		for i, line in ipairs(fileLines) do
			local errorIndex = line:match('^%[t=[%d%.:]*%]%[f=[%-%d]*%] Error().*')
			if errorIndex and errorIndex > 0 and not skipErrors(line) then
				errors[#errors+1] = line
				if #errors > maxErrors then
					return errors
				end
			end
		end
	end
	return errors
end


function test()
	local errors = infologTest()
	if #errors > 0 then
		error(table.concat(errors, "\n"), 0)
	end
end
