local function isnumber(n)
    return type(n) == "number" and n == n
end

local function isList(t)
    if type(t) ~= "table" then
        return false
    end
    if #t > 0 then
        return true
    end
    for k, v in pairs(t) do
        return false
    end
    return true
end

local function parse(str)
    local data = {}
    local stack = {}
    local inStringLiteral = false
    local isString = false
    local layers = {}
    local buffer = ""
    local key = ""

    local row = 1
    local column = 1
    
    for i = 1, #str, 1 do
        local char = string.sub(str, i, i)
        if inStringLiteral then
            if char == "\\" then
                i = i + 1
                column = column + 1
                local nextChar = string.sub(str, i, i)
                if nextChar == "\\" then
                    buffer = buffer .. "\\"
                elseif nextChar == "\"" then
                    buffer = buffer .. "\""
                elseif nextChar == "n" then
                    buffer = buffer .. "\n"
                else
                    error(("Unexpected token %s at %d:%d"):format(nextChar, row, column))
                end
            elseif char == "\"" then
                inStringLiteral = false
                isString = true
            else
                buffer = buffer .. char
            end
        elseif char == "{" then
            if #stack == 0 then
                stack[1] = data
            elseif layers[#layers] == "{}" then
                if key ~= "" then
                    local newTable = {}
                    stack[#stack][key] = newTable
                    stack[#stack + 1] = newTable
                else
                    error(("Unexpected Token { at %d:%d"):format(row, column))
                end
            else
                local list = stack[#stack]
                local newTable = {}
                list[#list + 1] = newTable
                stack[#stack + 1] = newTable
            end
            layers[#layers + 1] = "{}"
        elseif char == "}" then
            if layers[#layers] == "{}" then
                if buffer ~= "" then
                    local value = buffer
                    if not isString then
                        if isnumber(tonumber(buffer)) then
                            value = tonumber(buffer)
                        elseif buffer == "true" or buffer == "false" then
                            value = buffer == "true"
                        else
                            error(("Unexpected token %s at %d:%d"):format(buffer, row, column))
                        end
                    end
                    stack[#stack][key] = value
                    buffer = ""
                end
                layers[#layers] = nil
                stack[#stack] = nil
            else
                error(("Unexpected token } at %d:%d"):format(row, column))
            end
        elseif char == "[" then
            if #stack == 0 then
                stack[1] = data
            elseif layers[#layers] == "{}" then
                if key ~= "" then
                    local newTable = {}
                    stack[#stack][key] = newTable
                    stack[#stack + 1] = newTable
                else
                    error(("Unexpected Token { at %d:%d"):format(row, column))
                end
            else
                local list = stack[#stack]
                local newTable = {}
                list[#list + 1] = newTable
                stack[#stack + 1] = newTable
            end
            layers[#layers + 1] = "[]"
        elseif char == "]" then
            if layers[#layers] == "[]" then
                if buffer ~= "" then
                    local value = buffer
                    if not isString then
                        if isnumber(tonumber(buffer)) then
                            value = tonumber(buffer)
                        elseif buffer == "true" or buffer == "false" then
                            value = buffer == "true"
                        else
                            error(("Unexpected token %s at %d:%d"):format(buffer, row, column))
                        end
                    end
                    local list = stack[#stack]
                    list[#list + 1] = value
                    buffer = ""
                end
                layers[#layers] = nil
                stack[#stack] = nil
            else
                error(("Unexpected token ] at %d:%d"):format(row, column))
            end
        elseif char == ":" then
            if buffer ~= "" then
                key = buffer
                buffer = ""
            else
                error(("Unexpected token : at %d:%d"):format(row, column))
            end
            isString = false
        elseif char == "," then
            if buffer ~= "" then
                local value = buffer
                if not isString then
                    if isnumber(tonumber(buffer)) then
                        value = tonumber(buffer)
                    elseif buffer == "true" or buffer == "false" then
                        value = buffer == "true"
                    else
                        error(("Unexpected token %s at %d:%d"):format(buffer, row, column))
                    end
                end
                if layers[#layers] == "{}" then
                    if key ~= "" then
                        stack[#stack][key] = value
                    else
                        error(("Unexpected token %s at %d:%d"):format(buffer, row, column))
                    end
                else
                    local list = stack[#stack]
                    list[#list + 1] = value
                end
            end
            buffer = ""
            key = ""
            isString = false
        elseif char == "\"" then
            if buffer == "" then
                inStringLiteral = true
            else
                error(("Unexpected token \" at %d:%d"):format(row, column))
            end
        elseif string.find(char, "%S") then
            if isString then
                error(("Unexpected token %s at %d:%d"):format(char, row, column))
            else
                buffer = buffer .. char
            end
        elseif char == "\n" then
            row = row + 1
            column = 0
        end
        column = column + 1
    end
    
    return data
end

local function encode(data)
    if type(data) == "number" or type(data) == "boolean" then
        return tostring(data)
    elseif type(data) == "string" then
        return "\"" .. data .. "\""
    elseif type(data) == "table" then
        if isList(data) then
            local str = "["
            for i, v in pairs(data) do
                local enc = encode(v)
                if enc ~= "" then
                    if str ~= "[" then
                        str = str .. ", "
                    end
                    str = str .. enc
                end
            end
            return str .. "]"
        else
            local str = "{"
            for k, v in pairs(data) do
                local enc = encode(v)
                if enc ~= "" then
                    if str ~= "{" then
                        str = str .. ", "
                    end
                    str = str .. "\"" .. k .. "\": " .. enc
                end
            end
            return str .. "}"
        end
    end
    return ""
end

return {
    parse = parse,
    encode = encode
}
