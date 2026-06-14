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

local function parseJson(str, line)
    local data = {}
    local stack = {}
    local layers = {}
    local buffer = ""
    local key = ""
    local inStringLiteral = false
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
                    error(("Unrecognized escape character \\%s in line %d"):format(nextChar, line))
                end
            elseif char == "\"" then
                inStringLiteral = false
                stack[#stack][key] = buffer
            else
                buffer = buffer .. char
            end
        elseif char == "{" then
            if #stack == 0 then
                stack[1] = data
            elseif layers[#layers] == "{}" then
                local newTable = {}
                stack[#stack][key] = newTable
                stack[#stack + 1] = newTable
            else
                local list = stack[#stack]
                local newTable = {}
                list[#list + 1] = newTable
                stack[#stack + 1] = newTable
            end
            layers[#layers+1] = "{}"
        elseif char == "[" then
            if #stack == 0 then
                stack[1] = data
            elseif layers[#layers] == "{}" then
                local newTable = {}
                stack[#stack][key] = newTable
                stack[#stack + 1] = newTable
            else
                local list = stack[#stack]
                local newTable = {}
                list[#list + 1] = newTable
                stack[#stack + 1] = newTable
            end
            layers[#layers+1] = "[]"
        elseif #layers == 0 then
            error(("Malformed Json in line %d"):format(line))
        elseif char == "}" then
            if layers[#layers] == "{}" then
                stack[#stack][key] = buffer
                buffer = ""
                layers[#layers] = nil
                stack[#stack] = nil
            else
                error(("Unexpected token } in line %d"):format(line))
            end
        elseif char == "]" then
            if layers[#layers] == "[]" then
                local list = stack[#stack]
                list[#list + 1] = buffer
                buffer = ""
                layers[#layers] = nil
                stack[#stack] = nil
            else
                error(("Unexpected token } in line %d"):format(line))
            end
        elseif char == ":" then
            if layers[#layers] == "{}" then
                key = buffer
                buffer = ""
            else
                buffer = buffer .. ":"
            end
        elseif char == "\"" then
            if buffer == "" then
                inStringLiteral = true
            else
                buffer = buffer .. "\""
            end
        elseif string.find(char, "%s") then
            if #buffer > 0 then
                buffer = buffer .. char
            end
        elseif char == "," then
            if layers[#layers] == "{}" then
                stack[#stack][key] = buffer
                buffer = ""
            else
                local list = stack[#stack]
                list[#list + 1] = buffer
                buffer = ""
            end
        else
            buffer = buffer .. char
        end
    end
    if #layers > 0 then
        error(("Missing closing brackets (%s) in Json line %d"):format(layers[#layers], line))
    end
    return data
end

local function parse(str)

    local lines = {}
    
    for line in string.gmatch(str, "[^\n]+") do
        lines[#lines + 1] = line
    end
    
    local indentStep = 0
    local lineData = {}
    for i, line in pairs(lines) do
        if line ~= nil then
            local data = {
                indent = 0,
                key = nil,
                value = nil,
                inList = false,
                line = i
            }
            if string.find(line, "^%s*%w+: ?.*$") then
                if string.find(line, "^%s+") then
                    data.indent = #(string.match(line, "^%s+"))
                    if indentStep == 0 then
                        indentStep = data.indent
                    elseif data.indent % indentStep ~= 0 then
                        error("malformed Yaml indentation in line " .. tostring(i))
                    end
                    data.indent = data.indent / indentStep
                end
                data.key = string.match(line, "%w+")
                if string.find(line, ": .+$") then
                    local value = string.match(line, ": .+$")
                    value = string.sub(value, 3)
                    if isnumber(tonumber(value)) then
                        value = tonumber(value)
                    elseif value == "true" or value == "false" then
                        value = value == "true"
                    elseif string.sub(value, 1, 1) == "[" or string.sub(value, 1, 1) == "{" then
                        value = parseJson(value, i)
                    end
                    data.value = value
                end
            elseif string.find(line, "^%s+%- %w+: ?.*$") then
                data.indent = #(string.match(line, "^%s+"))
                if indentStep == 0 then
                    indentStep = data.indent
                elseif data.indent % indentStep ~= 0 then
                    error("malformed Yaml indentation in line " .. tostring(i))
                end
                data.indent = data.indent / indentStep
                data.key = string.match(line, "%w+")
                local value = string.match(line, ": .+$")
                value = string.sub(value, 3)
                if isnumber(tonumber(value)) then
                    value = tonumber(value)
                elseif value == "true" or value == "false" then
                    value = value == "true"
                elseif string.sub(value, 1, 1) == "[" or string.sub(value, 1, 1) == "{" then
                    value = parseJson(value, i)
                end
                data.value = value
                data.inList = true
            elseif string.find(line, "^%s+%- .+$") then
                data.indent = #(string.match(line, "^%s+"))
                if indentStep == 0 then
                    indentStep = data.indent
                elseif data.indent % indentStep ~= 0 then
                    error("malformed Yaml indentation in line " .. tostring(i))
                end
                data.indent = data.indent / indentStep
                local value = string.match(line, "- .+$")
                value = string.sub(value, 3)
                if isnumber(tonumber(value)) then
                    value = tonumber(value)
                elseif value == "true" or value == "false" then
                    value = value == "true"
                elseif value[1] == "[" or value[1] == "{" then
                    value = parseJson(value, i)
                end
                data.value = value
                data.inList = true
            elseif string.find(line, "%S") then
                error("malformed yaml in line " .. tostring(i))
            end
            lineData[#lineData+1] = data
        end
    end
    
    local data = {}

    local stack = {data}
    
    for i, ld in pairs(lineData) do
        if ld.key ~= nil then
            if ld.inList then
                if ld.indent < #stack then
                    local newTable = {}
                    local list = stack[ld.indent+1]
                    list[#list+1] = newTable
                    stack[ld.indent+2] = newTable
                    for i = ld.indent+3, #stack, 1 do
                        stack[i] = nil
                    end
                    if ld.value ~= nil then
                        newTable[ld.key] = ld.value
                    else
                        local newNewTable = {}
                        newTable[ld.key] = newNewTable
                        stack[ld.indent+3] = newNewTable
                    end
                else
                    error("malformed yaml indent in line " .. tostring(ld.line))
                end
            elseif ld.value ~= nil then
                if ld.indent < #stack then
                    stack[ld.indent+1][ld.key] = ld.value
                    for i = ld.indent+2, #stack, 1 do
                        stack[i] = nil
                    end
                else
                    error("malformed yaml indent in line " .. tostring(ld.line))
                end
            else
                if ld.indent < #stack then
                    local newTable = {}
                    stack[ld.indent+1][ld.key] = newTable
                    stack[ld.indent+2] = newTable
                    for i = ld.indent+3, #stack, 1 do
                        stack[i] = nil
                    end
                else
                    error("malformed yaml indent in line " .. tostring(ld.line))
                end
            end
        elseif ld.inList then
            if ld.indent < #stack then
                if ld.value ~= nil then
                    local list = stack[ld.indent+1]
                    list[#list+1] = ld.value
                else
                    error("malformed yaml in line " .. tostring(ld.line))
                end
            else
                error("malformed yaml indent in line " .. tostring(ld.line))
            end
        else
            error("malformed yaml in line " .. tostring(ld.line))
        end
    end
    
    return data
end

local function load(file)
    local str = ""
    for line in io.lines(file) do
        str = str .. line .. "\n"
    end
    return parse(str)
end

local function constructInlineJSON(data)
    if type(data) == "string" then
        return "\"" .. data .. "\""
    elseif type(data) == "number" or type(data) == "boolean" then
        return tostring(data)
    elseif type(data) == "table" then
        local json = ""
        if isList(data) then
            json = "["
            for k, v in pairs(data) do
                local valueJson = constructInlineJSON(v)
                if valueJSON ~= "" then
                    if json ~= "[" then
                        json = json .. ", "
                    end
                    json = json .. valueJson
                end
            end
            json = json .. "]"
        else
            json = "{"
            for k, v in pairs(data) do
                local valueJson = constructInlineJSON(v)
                if valueJSON ~= "" then
                    if json ~= "{" then
                        json = json .. ", "
                    end
                    json = json .. k .. ": " .. valueJson
                end
            end
            json = json .. "}"
        end
        return json
    else
        return ""
    end
end

local function constructYaml(data, prefix, inList)
    local yaml = ""
    
    local thisIterationPrefix = prefix
    local nextLayerPrefix = prefix .. "  "
    if inList then
        thisIterationPrefix = prefix .. "- "
        nextLayerPrefix = prefix .. "    "
    end
    
    if isList(data) then
        if inList then
            return thisIterationPrefix .. constructInlineJSON(data) .. "\n"
        end
        for k, v in pairs(data) do
            if type(v) == "table" then
                yaml = yaml .. constructYaml(v, prefix, true)
            elseif type(v) == "number" or type(v) == "boolean" or type(v) == "string" then
                yaml = yaml .. thisIterationPrefix .. "- " .. tostring(v) .. "\n"
            end
            if inList then
                thisIterationPrefix = prefix .. "  "
            end
        end
    else
        for k, v in pairs(data) do
            if type(v) == "table" then
                yaml = yaml .. thisIterationPrefix .. k .. ":\n"
                yaml = yaml .. constructYaml(v, nextLayerPrefix, false)
            elseif type(v) == "number" or type(v) == "boolean" or type(v) == "string" then
                yaml = yaml .. thisIterationPrefix .. k .. ": " .. tostring(v) .. "\n"
            end
            if inList then
                thisIterationPrefix = prefix .. "  "
            end
        end
    end
    return yaml
end

local function encode(data)
    return constructYaml(data, "", false)
end

local function save(data, file)
    if type(data) ~= "table" then
        return false
    end
    local yaml = encode(data)
    local handle = io.open(file, "w")
    handle.write(yaml)
    handle.close()
    return true    
end

return {
    parse = parse,
    encode = encode,
    load = load,
    save = save
}
