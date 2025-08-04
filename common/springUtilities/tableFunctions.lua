local function safeLuaTableParser(text)
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
                    return nil, "Expected ',' or '}'"
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
        elseif char:match('%d') or char == '-' then
            return parseNumber()
        
        -- Table
        elseif char == '{' then
            return parseTable()
        
        -- Boolean or nil
        elseif char:match('%a') then
            local identifier = parseIdentifier()
            if identifier == 'true' then
                return true
            elseif identifier == 'false' then
                return false
            elseif identifier == 'nil' then
                return nil
            else
                -- Treat as string literal (unquoted identifier)
                return identifier
            end
        
        else
            return nil, "Unexpected character: " .. char
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

local function customKeyToUsefulTable(dataRaw)
    if not dataRaw then
        return
    end
    if type(dataRaw) ~= 'string' then
        Spring.Echo("Customkey data error! type == " .. type(dataRaw))
        return
    end
    
    -- Decode the data
    dataRaw = string.gsub(dataRaw, '_', '=')
    dataRaw = string.base64Decode(dataRaw)
    
    -- Use safe parser instead of loadstring
    local usefulTable, err = safeLuaTableParser(dataRaw)
    if usefulTable then
        if collectgarbage then
            collectgarbage("collect")
        end
        return usefulTable
    else
        Spring.Echo("Customkey parse error:", err or "Unknown error")
    end
    
    if collectgarbage then
        collectgarbage("collect")
    end
end

return {
    CustomKeyToUsefulTable = customKeyToUsefulTable,
    SafeLuaTableParser = safeLuaTableParser, -- Export for standalone use
}