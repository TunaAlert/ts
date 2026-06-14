local function isnumber(n)
    return type(n) == "number" and n == n
end

local function parse(str)
    local data = {}
    local stack = {}
    local inStringLiteral = false
    local isString = false
    local layers = {}
    local buffer = ""
    local key = ""

    for i = 1, #str, 1 do
        local char = string.sub(str, i, i)
        if inStringLiteral then
            if char == "\\" then
                i = i + 1
                local nextChar = string.sub(str, i, i)
                if nextChar == "\\" then
                    buffer = buffer .. "\\"
                elseif nextChar == "\"" then
                    buffer = buffer .. "\""
                elseif nextChar == "n" then
                    buffer = buffer .. "\n"
                else
                    error(("Unexpected token %s near \\"):format(nextChar))
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
                    error("Unexpected Token {")
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
                layers[#layers] = nil
                stack[#stack] = nil
            else
                error("Unexpected token }")
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
                    error("Unexpected Token {")
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
                layers[#layers] = nil
                stack[#stack] = nil
            else
                error("Unexpected token ]")
            end
        elseif char == ":" then
            if buffer ~= "" then
                key = buffer
                buffer = ""
            else
                error("Unexpected token :")
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
                        error(("Unexpected token %s"):format(buffer))
                    end
                end
                if layers[#layers] == "{}" then
                    if key ~= "" then
                        stack[#stack] = value
                    else
                        error(("Unexpected token %s"):format(buffer))
                    end
                else
                    local list = stack[#stack]
                    list[#list + 1] = value
                end
            else
                error("Unexpected token ,")
            end
            isString = false
        elseif char == "\"" then
            if buffer == "" then
                inStringLiteral = true
            else
                error("Unexpected token \"")
            end
        elseif string.find(char, "%S") then
            if isString then
                error("Unexpected token " .. char)
            else
                buffer = buffer .. char
            end
        end
    end
    
    return data
end

local function encode(data)
    return ""
end

return {
    parse = parse,
    encode = encode
}
