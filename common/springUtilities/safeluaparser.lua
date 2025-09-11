--[[
    File: safeluaparser.lua
    Description: This file contains the implementation of a safe Lua table parser.
                 The `safeLuaTableParser` function parses Lua table-like strings into Lua tables,
                 while handling potential errors and ensuring safety by avoiding execution of arbitrary code.

    License: GPLv2 
    Usage: 
        local parsedTable, err = safeLuaTableParser("{key = 'value', nested = {subkey = 123}}")
        if parsedTable then
            print("Parsed successfully!")
        else
            print("Error: " .. err)
        end
]]


-- TODO:
-- [x] Handle the case where a single table is returned from the input string, e.g:
    -- return {key = "value" }
-- [x] Handle function definitions, by returning them as a string,
    -- func = function() return true end
    -- Should become:
    -- func = "function() return true end"
-- [x] Handle in-place function executions, by also returning them as a string:
    -- func = (function() return true end)()
    -- Should become:
    -- func = "(function() return true end)()"
-- [x] wrap the whole safeLuaTableParser in a pcall and return an empty table on failure
-- 



-- Internal parser function that does the actual parsing
local function _safeLuaTableParserInternal(text)
    if not text or type(text) ~= 'string' then
        return nil, "Invalid input: expected string"
    end
    
    local pos = 1
    local len = #text
    
    -- Skip whitespace and comments
    local function skipWhitespaceAndComments()
        while pos <= len do
            local char = text:sub(pos, pos)
            if char:match('%s') then
                pos = pos + 1
            elseif text:sub(pos, pos + 1) == '--' then
                -- Skip line comment
                while pos <= len and text:sub(pos, pos) ~= '\n' do
                    pos = pos + 1
                end
            elseif text:sub(pos, pos + 1) == '/*' then
                -- Skip block comment (C-style, if needed)
                pos = pos + 2
                while pos < len do
                    if text:sub(pos, pos + 1) == '*/' then
                        pos = pos + 2
                        break
                    end
                    pos = pos + 1
                end
            else
                break
            end
        end
    end
    
    -- Parse a string literal
    local function parseString()
        local quote = text:sub(pos, pos)
        if quote ~= '"' and quote ~= "'" then
            return nil, "Expected string"
        end
        
        pos = pos + 1
        local result = ""
        
        while pos <= len do
            local char = text:sub(pos, pos)
            if char == quote then
                pos = pos + 1
                return result
            elseif char == '\\' then
                pos = pos + 1
                if pos <= len then
                    local escaped = text:sub(pos, pos)
                    if escaped == 'n' then
                        result = result .. '\n'
                    elseif escaped == 't' then
                        result = result .. '\t'
                    elseif escaped == 'r' then
                        result = result .. '\r'
                    elseif escaped == '\\' then
                        result = result .. '\\'
                    elseif escaped == quote then
                        result = result .. quote
                    else
                        result = result .. escaped
                    end
                    pos = pos + 1
                end
            else
                result = result .. char
                pos = pos + 1
            end
        end
        
        return nil, "Unterminated string"
    end
    
    -- Parse a number
    local function parseNumber()
        local start = pos
        local hasDecimal = false
        
        if text:sub(pos, pos) == '-' then
            pos = pos + 1
        end
        
        while pos <= len do
            local char = text:sub(pos, pos)
            if char:match('%d') then
                pos = pos + 1
            elseif char == '.' and not hasDecimal then
                hasDecimal = true
                pos = pos + 1
            else
                break
            end
        end
        
        local numStr = text:sub(start, pos - 1)
        local num = tonumber(numStr)
        if num then
            return num
        else
            return nil, "Invalid number: " .. numStr
        end
    end
    
    -- Parse an identifier/key
    local function parseIdentifier()
        local start = pos
        local char = text:sub(pos, pos)
        
        if not (char:match('%a') or char == '_') then
            return nil, "Invalid identifier start"
        end
        
        while pos <= len do
            char = text:sub(pos, pos)
            if char:match('%w') or char == '_' then
                pos = pos + 1
            else
                break
            end
        end
        
        return text:sub(start, pos - 1)
    end
    
    -- Forward declaration
    local parseValue
    
    -- Parse a function definition and return it as a string
    local function parseFunction()
        local start = pos
        
        -- We expect to be at the beginning of "function"
        if pos + 7 > len or text:sub(pos, pos + 7) ~= "function" then
            return nil, "Expected 'function'"
        end
        
        pos = pos + 8 -- Skip "function"
        
        -- Count all 'end' keywords we need to match
        local depth = 1 -- We're already inside one function (need 1 'end')
        local inString = false
        local stringChar = nil
        local endFound = false
        local expectingDo = false -- Track if we're expecting a 'do' after for/while
        
        while pos <= len and not endFound do
            local char = text:sub(pos, pos)
            
            if inString then
                if char == stringChar then
                    -- Check if it's escaped
                    local backslashes = 0
                    local checkPos = pos - 1
                    while checkPos >= 1 and text:sub(checkPos, checkPos) == '\\' do
                        backslashes = backslashes + 1
                        checkPos = checkPos - 1
                    end
                    if backslashes % 2 == 0 then
                        inString = false
                        stringChar = nil
                    end
                end
            else
                if char == '"' or char == "'" then
                    inString = true
                    stringChar = char
                elseif char:match('%a') then
                    -- Check for keywords that start/end blocks
                    local wordStart = pos
                    while pos <= len and (text:sub(pos, pos):match('%w') or text:sub(pos, pos) == '_') do
                        pos = pos + 1
                    end
                    local word = text:sub(wordStart, pos - 1)
                    
                    if word == "function" or word == "if" then
                        -- These always need an 'end'
                        depth = depth + 1
                        expectingDo = false
                    elseif word == "for" or word == "while" then
                        -- These need an 'end' and will have a 'do'
                        depth = depth + 1
                        expectingDo = true
                    elseif word == "do" then
                        -- If we were expecting 'do' from for/while, don't count it as a separate block
                        if not expectingDo then
                            depth = depth + 1
                        end
                        expectingDo = false
                    elseif word == "repeat" then
                        -- repeat...until doesn't use 'end'
                        expectingDo = false
                    elseif word == "end" then
                        depth = depth - 1
                        if depth == 0 then
                            endFound = true
                        end
                        expectingDo = false
                    elseif word == "until" then
                        -- until ends a repeat block (no 'end' needed for repeat)
                        expectingDo = false
                    else
                        -- Other keywords don't affect our block counting
                        -- But some keywords reset the expectingDo flag
                        if not word:match("^(local|return|break|and|or|not|in|then|else|elseif|pairs|type|v)$") then
                            expectingDo = false
                        end
                    end
                    pos = pos - 1 -- Adjust for the increment at the end of the loop
                end
            end
            
            pos = pos + 1
        end
        
        if not endFound then
            return nil, "Unterminated function (depth=" .. depth .. ")"
        end
        
        local functionStr = text:sub(start, pos - 1)
        return functionStr
    end
    
    -- Parse an in-place function execution: (function() ... end)()
    local function parseInPlaceFunctionExecution()
        local start = pos
        
        -- We expect to be at the beginning of "("
        if text:sub(pos, pos) ~= "(" then
            return nil, "Expected '('"
        end
        
        pos = pos + 1 -- Skip "("
        skipWhitespaceAndComments()
        
        -- Check if this is a function
        if text:sub(pos, pos + 7) ~= "function" then
            return nil, "Expected 'function' after '('"
        end
        
        -- Parse the function
        local functionStr, err = parseFunction()
        if not functionStr then
            return nil, err
        end
        
        skipWhitespaceAndComments()
        
        -- Expect closing parenthesis
        if pos > len or text:sub(pos, pos) ~= ")" then
            return nil, "Expected ')' after function"
        end
        pos = pos + 1
        
        skipWhitespaceAndComments()
        
        -- Expect opening parenthesis for function call
        if pos > len or text:sub(pos, pos) ~= "(" then
            return nil, "Expected '(' for function call"
        end
        
        -- Find the matching closing parenthesis for the function call
        local parenDepth = 1
        local callStart = pos
        pos = pos + 1
        local inString = false
        local stringChar = nil
        
        while pos <= len and parenDepth > 0 do
            local char = text:sub(pos, pos)
            
            if inString then
                if char == stringChar then
                    -- Check if it's escaped
                    local backslashes = 0
                    local checkPos = pos - 1
                    while checkPos >= 1 and text:sub(checkPos, checkPos) == '\\' do
                        backslashes = backslashes + 1
                        checkPos = checkPos - 1
                    end
                    if backslashes % 2 == 0 then
                        inString = false
                        stringChar = nil
                    end
                end
            else
                if char == '"' or char == "'" then
                    inString = true
                    stringChar = char
                elseif char == '(' then
                    parenDepth = parenDepth + 1
                elseif char == ')' then
                    parenDepth = parenDepth - 1
                end
            end
            
            pos = pos + 1
        end
        
        if parenDepth > 0 then
            return nil, "Unterminated function call"
        end
        
        local fullExpressionStr = text:sub(start, pos - 1)
        return fullExpressionStr
    end
    
    -- Parse a table
    local function parseTable()
        local result = {}
        local arrayIndex = 1
        
        skipWhitespaceAndComments()
        if pos > len or text:sub(pos, pos) ~= '{' then
            return nil, "Expected '{'"
        end
        pos = pos + 1
        
        skipWhitespaceAndComments()
        
        -- Empty table
        if pos <= len and text:sub(pos, pos) == '}' then
            pos = pos + 1
            return result
        end
        
        while pos <= len do
            skipWhitespaceAndComments()
            
            if pos > len then
                return nil, "Unexpected end of input"
            end
            
            if text:sub(pos, pos) == '}' then
                pos = pos + 1
                return result
            end
            
            local key, value
            local char = text:sub(pos, pos)
            
            -- Check for explicit key
            if char == '[' then
                -- Bracketed key [key] = value
                pos = pos + 1
                skipWhitespaceAndComments()
                
                key, err = parseValue()
                if not key then
                    return nil, err
                end
                
                skipWhitespaceAndComments()
                if pos > len or text:sub(pos, pos) ~= ']' then
                    return nil, "Expected ']'"
                end
                pos = pos + 1
                
                skipWhitespaceAndComments()
                if pos > len or text:sub(pos, pos) ~= '=' then
                    return nil, "Expected '=' after key"
                end
                pos = pos + 1
                
            elseif char:match('%a') or char == '_' then
                -- Identifier key
                local identifier = parseIdentifier()
                if not identifier then
                    return nil, "Invalid identifier"
                end
                
                skipWhitespaceAndComments()
                if pos <= len and text:sub(pos, pos) == '=' then
                    -- It's a key = value pair
                    pos = pos + 1
                    key = identifier
                else
                    -- It's just a value (identifier as string)
                    key = arrayIndex
                    arrayIndex = arrayIndex + 1
                    -- Reset position to parse the identifier as a value
                    pos = pos - #identifier
                end
            else
                -- Array element
                key = arrayIndex
                arrayIndex = arrayIndex + 1
            end
            
            skipWhitespaceAndComments()
            value, err = parseValue()
            if not value and err then
                return nil, err
            end
            
            result[key] = value
            
            skipWhitespaceAndComments()
            if pos <= len then
                char = text:sub(pos, pos)
                if char == ',' or char == ';' then
                    pos = pos + 1
                elseif char == '}' then
                    -- Will be handled in next iteration
                else
                    return nil, string.format("Expected ',' or '}', got '%s' at pos %d", char, pos  )
                end
            end
        end
        
        return nil, "Unterminated table"
    end
    
    -- Parse any value
    parseValue = function()
        skipWhitespaceAndComments()
        
        if pos > len then
            return nil, "Unexpected end of input"
        end
        
        local char = text:sub(pos, pos)
        
        -- String
        if char == '"' or char == "'" then
            return parseString()
        
        -- Number
        elseif char:match('%d') or char == '-' or char == '.' then
            return parseNumber()
        
        -- Table
        elseif char == '{' then
            return parseTable()
        
        -- In-place function execution: (function() ... end)()
        elseif char == '(' then
            return parseInPlaceFunctionExecution()
        
        -- Boolean or nil
        elseif char:match('%a') then
            local identifier = parseIdentifier()
            if identifier == 'true' then
                return true
            elseif identifier == 'false' then
                return false
            elseif identifier == 'nil' then
                return nil
            elseif identifier == 'function' then
                -- Reset position to start of "function" keyword
                pos = pos - #identifier
                return parseFunction()
            else
                -- Treat as string literal (unquoted identifier)
                return identifier
            end
        
        else
            return nil, "Unexpected character: " .. char
        end
    end
    
    -- First, check if the input starts with "return"
    skipWhitespaceAndComments()
    
    -- Check for "return" keyword at the beginning
    if pos <= len - 5 and text:sub(pos, pos + 5) == "return" then
        -- Check if it's followed by whitespace or a valid character
        local nextPos = pos + 6
        if nextPos > len or text:sub(nextPos, nextPos):match('%s') or text:sub(nextPos, nextPos) == '{' then
            pos = pos + 6 -- Skip "return"
            skipWhitespaceAndComments()
        end
    end
    
    local result, err = parseValue()
    if err then
        return nil, err
    end
    
    -- Make sure we've consumed all input (except trailing whitespace/comments)
    skipWhitespaceAndComments()
    if pos <= len then
        return nil, "Unexpected trailing content"
    end
    
    return result
end

-- Public safe parser function that wraps the internal parser with pcall
local function safeLuaTableParser(text)
    local success, result, err = pcall(_safeLuaTableParserInternal, text)
    
    if success then
        -- Internal function succeeded, return its result
        if result then
            return result, err
        else
            -- Internal function returned nil with error message
            return {}, err or "Parse failed"
        end
    else
        -- pcall failed, return empty table
        return {}, "Parser error: " .. tostring(result)
    end
end


if not Spring then 
    local function deep_equal(a, b)
        if a == b then return true end
        if type(a) ~= "table" or type(b) ~= "table" then
            return false, string.format("Type mismatch: %s vs %s (a=%s, b=%s)", type(a), type(b), tostring(a), tostring(b))
        end

        -- Check all keys/values in a
        for k, v in pairs(a) do
            local equal, reason = deep_equal(v, b[k])
            if not equal then
                return false, string.format("At key [%s]: %s", tostring(k), reason or "values differ")
            end
        end

        -- Ensure b doesn't have keys missing in a
        for k in pairs(b) do
            if a[k] == nil then
                return false, string.format("Key [%s] exists in b but not in a", tostring(k))
            end
        end

        return true
    end

    local function compare(ttext)
        local safet, err1 = safeLuaTableParser(ttext)
        local err2, unsafet = pcall(loadstring('return '..ttext))
        local equal, reason = deep_equal(safet, unsafet)
        print("The two tables are equal? " .. tostring(equal) .. " " .. reason or "")
        if err1 then
            print("safeLuaTableParser error: " .. tostring(err1))
        end
    end

    -- This is our test class when run outside of Spring
    -- e.g. "C:\Users\Peti\Downloads\ZeroBraneStudio\bin\lua.exe" "C:\Users\Peti\Documents\My Games\Spring\games\Beyond-All-Reason.sdd\safeluaparser.lua" ...

    print("Running tests for safeLuaTableParser...")
    -- Get the command line args from Lua executable:
    local args = {...}
    print("Command line args:", table.concat(args, ", "))

    local content = nil
    for i, arg in ipairs(args) do
        print("Arg " .. i .. ": " .. arg)
        local inputFile = args[1]
        if inputFile then
            print("Reading test input from file: " .. inputFile)
            local file = io.open(inputFile, "r")
            if file then
                content = file:read("*all")
                file:close()
                
                if content then
                    print("Parsing content from file...")
                    compare(content)
                end
            else
                print("Error: Could not open file " .. inputFile)
            end
        else
            print("No input file specified. Usage: lua safeluaparser.lua <filename>")
        end
    end

    -- if args were given, exit straight up:
    if #args ~= 0 then
        print("Done with file tests, exiting.")
        os.exit()
    end


    -- Test function definition parsing
    local function testFunctionParsing()
        print("Testing function definition parsing...")
        
        -- Test case 1: Simple function
        local test1 = '{func = function() return true end}'
        local result1, err1 = safeLuaTableParser(test1)
        if result1 then
            print("Test 1 passed: func = " .. tostring(result1.func))
            print("Type: " .. type(result1.func))
        else
            print("Test 1 failed: " .. (err1 or "unknown error"))
        end
        
        -- Test case 2: Function with parameters
        local test2 = '{func = function(a, b) return a + b end}'
        local result2, err2 = safeLuaTableParser(test2)
        if result2 then
            print("Test 2 passed: func = " .. tostring(result2.func))
            print("Type: " .. type(result2.func))
        else
            print("Test 2 failed: " .. (err2 or "unknown error"))
        end
        
        -- Test case 3: Nested function
        local test3 = '{func = function() local inner = function() return 1 end; return inner() end}'
        local result3, err3 = safeLuaTableParser(test3)
        if result3 then
            print("Test 3 passed: func = " .. tostring(result3.func))
            print("Type: " .. type(result3.func))
        else
            print("Test 3 failed: " .. (err3 or "unknown error"))
        end
        
        -- Test case 4: In-place function execution
        local test4 = '{result = (function() return true end)()}'
        local result4, err4 = safeLuaTableParser(test4)
        if result4 then
            print("Test 4 passed: result = " .. tostring(result4.result))
            print("Type: " .. type(result4.result))
        else
            print("Test 4 failed: " .. (err4 or "unknown error"))
        end
        
        -- Test case 5: In-place function execution with parameters
        local test5 = '{result = (function(x) return x * 2 end)(5)}'
        local result5, err5 = safeLuaTableParser(test5)
        if result5 then
            print("Test 5 passed: result = " .. tostring(result5.result))
            print("Type: " .. type(result5.result))
        else
            print("Test 5 failed: " .. (err5 or "unknown error"))
        end

        -- Test case 6: Complex function with nested definitions
        local test6 = '{flip = function(t) for k,v in pairs(t) do if type(v) == "table" then v[3], v[4] = 1.0 - v[3], 1.0 - v[4] end end end }'
        print("Testing complex function: " .. test6)
        local result6, err6 = safeLuaTableParser(test6)
        if result6 then
            print("Test 6 passed: flip = " .. tostring(result6.flip))
            print("Type: " .. type(result6.flip))
            print(err6 or "no error")
        else
            print("Test 6 failed: " .. (err6 or "unknown error"))
        end
        
        -- Test case 7: Just the function itself to debug
        local test7 = 'function(t) for k,v in pairs(t) do if type(v) == "table" then v[3], v[4] = 1.0 - v[3], 1.0 - v[4] end end end'
        print("Testing standalone function: " .. test7)
        local result7, err7 = safeLuaTableParser(test7)
        if result7 then
            print("Test 7 passed: result = " .. tostring(result7))
            print("Type: " .. type(result7))
            print("err7: " .. tostring(err7))
        else
            print("Test 7 failed: " .. (err7 or "unknown error"))
        end
        
        -- Test case 8: Just the function itself to debug
        local test8 = [[{buildoptions=(function()local a={[1]='corfus',[2]='corafus',[3]='corageo',[4]='corbhmth',[5]='cormoho',[6]='cormexp',[7]='cormmkr',[8]='coruwadves',[9]='coruwadvms',[10]='corarad',[11]='corshroud',[12]='corfort',[13]='corlab',[14]='cortarg',[15]='corsd',[16]='corgate',[17]='cortoast',[18]='corvipe',[19]='cordoom',[20]='corflak',[21]='corscreamer',[22]='corvp',[23]='corfmd',[24]='corap',[25]='corint',[26]='corplat',[27]='corsy',[28]='coruwmme',[29]='coruwmmm',[30]='corenaa',[31]='corfdoom',[32]='coratl',[33]='coruwfus',[34]='corjugg',[35]='corshiva',[36]='corsumo',[37]='corgol',[38]='corkorg',[39]='cornanotc2plat',[40]='cornanotct2',[41]='cornecro',[42]='cordoomt3',[43]='corhllllt',[44]='cormaw',[45]='cormwall',[46]='corgatet3'}return a end)()}]]
        print("Testing standalone function: " .. test8)
        local result8, err8 = safeLuaTableParser(test8)
        if result8 then
            print("Test 8 passed: result = " .. tostring(result8))
            print("Type: " .. type(result8))
            print("err8: " .. tostring(err8))
        else
            print("Test 8 failed: " .. (err8 or "unknown error"))
        end
    end

    testFunctionParsing()

    -- Test pcall wrapper functionality
    local function testPcallWrapper()
        print("\nTesting pcall wrapper functionality...")
        
        -- Test case 1: Valid input should work
        local test1 = '{key = "value", number = 42}'
        local result1, err1 = safeLuaTableParser(test1)
        print("Test 1 (valid input):")
        print("  Result type: " .. type(result1))
        if type(result1) == "table" then
            print("  Table contents: key=" .. tostring(result1.key) .. ", number=" .. tostring(result1.number))
        end
        print("  Error: " .. tostring(err1))
        
        -- Test case 2: Invalid input should return empty table
        local test2 = '{invalid syntax here @#$%'
        local result2, err2 = safeLuaTableParser(test2)
        print("Test 2 (invalid input):")
        print("  Result type: " .. type(result2))
        print("  Table size: " .. #result2)
        print("  Error: " .. tostring(err2))
        
        -- Test case 3: Nil input should return empty table
        local result3, err3 = safeLuaTableParser(nil)
        print("Test 3 (nil input):")
        print("  Result type: " .. type(result3))
        print("  Table size: " .. #result3)
        print("  Error: " .. tostring(err3))
        
        -- Test case 4: Empty string should return empty table
        local result4, err4 = safeLuaTableParser("")
        print("Test 4 (empty string):")
        print("  Result type: " .. type(result4))
        print("  Table size: " .. #result4)
        print("  Error: " .. tostring(err4))
    end

    testPcallWrapper()

    -- Test return statement handling
    local function testReturnStatements()
        print("\nTesting return statement handling...")
        
        -- Test case 1: return with a simple table
        local test1 = 'return {key = "value", number = 42}'
        local result1, err1 = safeLuaTableParser(test1)
        print("Test 1 (return table):")
        print("  Result type: " .. type(result1))
        if type(result1) == "table" then
            print("  Table contents: key=" .. tostring(result1.key) .. ", number=" .. tostring(result1.number))
        end
        print("  Error: " .. tostring(err1))
        
        -- Test case 2: return with nested tables
        local test2 = 'return {outer = {inner = "nested"}}'
        local result2, err2 = safeLuaTableParser(test2)
        print("Test 2 (return nested table):")
        print("  Result type: " .. type(result2))
        if type(result2) == "table" and type(result2.outer) == "table" then
            print("  Nested value: outer.inner=" .. tostring(result2.outer.inner))
        end
        print("  Error: " .. tostring(err2))
        
        -- Test case 3: return with comments and whitespace
        local test3 = '-- This is a config file\nreturn {\n  setting = true,\n  value = 123\n}'
        local result3, err3 = safeLuaTableParser(test3)
        print("Test 3 (return with comments):")
        print("  Result type: " .. type(result3))
        if type(result3) == "table" then
            print("  Table contents: setting=" .. tostring(result3.setting) .. ", value=" .. tostring(result3.value))
        end
        print("  Error: " .. tostring(err3))
        
        -- Test case 4: return with function definitions
        local test4 = 'return {func = function() return "hello" end}'
        local result4, err4 = safeLuaTableParser(test4)
        print("Test 4 (return with function):")
        print("  Result type: " .. type(result4))
        if type(result4) == "table" then
            print("  Function value: func=" .. tostring(result4.func) .. " (type: " .. type(result4.func) .. ")")
        end
        print("  Error: " .. tostring(err4))
        
        -- Test case 5: Regular table without return (should still work)
        local test5 = '{normal = "table"}'
        local result5, err5 = safeLuaTableParser(test5)
        print("Test 5 (normal table without return):")
        print("  Result type: " .. type(result5))
        if type(result5) == "table" then
            print("  Table contents: normal=" .. tostring(result5.normal))
        end
        print("  Error: " .. tostring(err5))
    end

    testReturnStatements()

    print("done")
end 

return {SafeLuaTableParser = safeLuaTableParser}