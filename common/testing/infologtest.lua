-- 'hidden' test checking infolog.txt for errors, used by headless runs.

local maxErrors = 10

local function skipErrors(line)
	if string.find(line, 'Could not finalize projectile-texture atlas', nil, true) then
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
