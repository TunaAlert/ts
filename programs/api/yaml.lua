local function isnumber(n)
    return type(n) == "number" and n == n
end

local function isList(t)
    return #t > 0 or t[1] ~= nil
end

local function parse(str)
    local data = {}
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
    else return ""
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
            return thisIterationPrefix .. constructInlineJSON(data)
        end
        for k, v in pairs(data) do
            if type(v) == "table" then
                yaml = yaml .. constructYaml(v, nextLayerPrefix, true)
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

local function save(data, file)
    if type(data) ~= "table" then
        return false
    end
    local yaml = constructYaml(data, "", false)
    local handle = io.open(file, "w")
    handle.write(yaml)
    handle.close()
    return true    
end

return{
    parse = parse,
    load = load,
    save = save
}
