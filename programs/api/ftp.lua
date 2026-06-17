peripheral.find("modem", rednet.open)

UNKNOWN_RESPONSE = 1
SUCCESS = 2
NO_RESPONSE = 3
ACCESS_DENIED = 4

local function split(str)
    local t = {}
    for s in string.gmatch(str, "([^%s]+)") do
        table.insert(t, s)
    end
    return t
end

local function subtable(tbl, s, e)
    local sub = table.create(e-s+1)  
    for i = s, e, 1 do
        sub[#sub+1] = tbl[i]
    end
    return sub
end

local function upload_to(id, file)
    local file = io.open(file)
    if file == nil then
        rednet.send(id, nil, "ftp")
    end
    for line in file:lines() do
        rednet.send(id, line, "ftp")
        repeat
            local xid, message = rednet.receive("ftp")
        until xid == id and message == "next"
    end
    rednet.send(id, nil, "ftp")
    file:close()
end

local function download_from(id, name)
    local file = io.open(name, "w")
    local first_line = true
    repeat
        local xid, line
        repeat
            xid, line = rednet.receive("ftp")
        until xid == id
        if line ~= nil then
            if not first_line then
                file:write("\n")
            else
                first_line = false
            end
            file:write(line)
            rednet.send(id, "next", "ftp")
        end
    until line == nil
    file:close()
end

local function host(folder, readperm, writeperm)
    if folder == nil then
        folder = "/"
    end
	if readperm == nil then
        readperm = true
    end
    if writeperm == nil then
        writeperm = true
    end
    
    while true do
        local id, message = rednet.receive("ftp")
        if id ~= nil then
            message = tostring(message)
            local cmd = split(message)

            local path = folder .. "/" .. table.concat(subtable(cmd, 2, #cmd), " ")
            if fs.isDir(path) then
                path = path .. "/"
            end

			print(("received %s request from %d"):format(cmd[1], id))

            if string.find(path, "[/\\]%.%.[/\\]") then
                rednet.send(id, "denied forbidden", "ftp")
				print("denied access: forbidden path")
            elseif cmd[1] == "list" then
				if not readperm then
					rednet.send(id, "denied permissions", "ftp")
					print("denied access: no read permissions")
				elseif not fs.exists(path) then
                    rednet.send(id, "denied nonexistant", "ftp")
					print("denied access: dir doesn't exist")
                elseif not fs.isDir(path) then
                    rednet.send(id, "denied file", "ftp")
					print("denied access: path is a file")
                else
                    local files = fs.list(path)
                    for i, file in pairs(files) do
                        if fs.isDir(("%s/%s"):format(path, file)) then
                            files[i] = file .. "/"
                        end
                    end
                    rednet.send(id, files, "ftp")
					print("fulfilled")
                end
			elseif cmd[1] == "delete" then
				if writeperm then
					if not fs.exists(path) then
						rednet.send(id, "denied nonexistant", "ftp")
						print("denied access: file doesn't exist")
					elseif fs.isReadOnly(path) then
						rednet.send(id, "denied permissions", "ftp")
						print("denied access: file is read-only")
					else
						fs.delete(path)
						rednet.send(id, SUCCESS, "ftp")
					print("fulfilled")
					end
				else
					rednet.send(id, "denied permissions", "ftp")
					print("denied access: no write permissions")
				end
            elseif fs.isDir(path) then
                rednet.send(id, "denied dir", "ftp")
				print("denied access: path is a dir")
            elseif cmd[1] == "push" then
				if writeperm then
	                rednet.send(id, "start", "ftp")
	                download_from(id, path)
					print("fulfilled")
				else
					rednet.send(id, "denied permissions", "ftp")
					print("denied access: no write permissions")
				end
            elseif cmd[1] == "pull" then
				if readperm then
	                rednet.send(id, "start", "ftp")
	                upload_to(id, path)
					print("fulfilled")
				else
					rednet.send(id, "denied permissions", "ftp")
					print("denied access: no read permissions")
				end
			end
        end
    end
end

local function push(host, file, name)
    rednet.send(host, ("push %s"):format(name), "ftp")
    local t = os.epoch()
    local id, message
    repeat
        id, message = rednet.receive("ftp", 0.1)
    until id == host or os.epoch() - t >= 72000
    if id == nil then
        return NO_RESPONSE
    elseif string.find(message, "denied") then
        local reason = string.sub(message, 8)
        return ACCESS_DENIED, reason
    elseif message == "start" then
        upload_to(host, file)
        return SUCCESS
    else
        return UNKNOWN_RESPONSE, message
    end
end

local function pull(host, file, name)
    rednet.send(host, ("pull %s"):format(file), "ftp")
    local id, message
    local t = os.epoch()
    repeat
        id, message = rednet.receive("ftp", 0.1)
    until id == host or os.epoch() - t >= 72000
    if id == nil then
        return NO_RESPONSE
    elseif string.find(message, "denied") then
        local reason = string.sub(message, 8)
        return ACCESS_DENIED, reason
    elseif message == "start" then
        download_from(host, name)
        return SUCCESS
    else
        return UNKNOWN_RESPONSE, message
    end
end

local function list(host, dir)
    if dir == nil then
        dir = "/"
    end
    rednet.send(host, ("list %s"):format(dir), "ftp")
    local id, message
    local t = os.epoch()
    repeat
        id, message = rednet.receive("ftp", 0.1)
    until id == host or os.epoch() - t >= 72000
    if id == nil then
        return NO_RESPONSE
    elseif type(message) == "string" then
        return ACCESS_DENIED, message
    else
        return SUCCESS, message
    end
end

local function pushdir(host, dir, name)
    local files = fs.list(dir)
    local results = {}
    for i, file in pairs(files) do
        local result = 1
        if fs.isDir(("%s/%s"):format(dir, file)) then
            result = pushdir(host, ("%s/%s"):format(dir, file), ("%s/%s"):format(name, file))
        else
            result = push(host, ("%s/%s"):format(dir, file), ("%s/%s"):format(name, file))
        end
        if results[result] == nil then
            results[result] = 1
        else
        	results[result] = results[result] + 1
        end
    end
    return results
end

local function pulldir(host, dir, name)
    local status, files = list(host, dir)
    if status ~= SUCCESS then
        return status
    end
    local results = {}
    for i, file in pairs(files) do
        local result = 1
        if string.find(file, "/") then
            result = pulldir(host, ("%s/%s"):format(dir, file), ("%s/%s"):format(name, file))
        else
            result = pull(host, ("%s/%s"):format(dir, file), ("%s/%s"):format(name, file))
        end
        if results[result] == nil then
            results[result] = 1
        else
        	results[result] = results[result] + 1
        end
    end
    return results
end

local function delete(host, fileOrDir)
    rednet.send(host, ("delete %s"):format(fileOrDir), "ftp")
	local id, status
    local t = os.epoch()
    repeat
        id, message = rednet.receive("ftp", 0.1)
    until id == host or os.epoch() - t >= 72000
    if id == nil then
        return NO_RESPONSE
    elseif type(message) == "string" then
		return ACCESS_DENIED
	else
        return SUCCESS
    end
end

return {
    UNKNOWN_RESPONSE = UNKNOWN_RESPONSE,
    SUCCESS = SUCCESS,
    NO_RESPONSE  =NO_RESPONSE,
    ACCESS_DENIED = ACCESS_DENIED,
    host = host,
    list = list,
    push = push,
    pull = pull,
    pushdir = pushdir,
    pulldir = pulldir,
	delete = delete
}
