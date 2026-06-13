local ftp = require("/programs/api/ftp")

if not rednet.isOpen() then
  print("no modem attached")
  return
end

local function usage()
    print("usage: ftp host [dir] [r][w]")
    print("  or   ftp push <host> <file> [destination]")
    print("  or   ftp pull <host> <file> [destination]")
    print("  or   ftp pushdir <host> [dir] [destination]")
    print("  or   ftp pulldir <host> [dir] [destination]")
    print("  or   ftp list <host> [dir]")
end

if #arg == 0 then
    usage()
    return nil
end

if arg[1] == "host" then
    local folder = shell.dir() .. "/"
    if arg[2] ~= nil and #arg[2] > 0 then
        if arg[2][1] == "/" then
            folder = arg[2]
        else
            folder = shell.dir() .. "/" .. arg[2]
        end
    end
    local readperm = arg[3] == nil or string.find(arg[3], "r") ~= nil
    local writeperm = arg[3] == nil or string.find(arg[3], "w") ~= nil
    if not (readperm or writeperm) then
        print("Either read permissions or write permissions are required")
        return
    end
    print(("Hosting on id %d"):format(os.getComputerID()))
    if folder ~= "/" then
        print(("restricted access to %s"):format(folder))
    end
    if not readperm then
        print("writeonly")
    elseif not writeperm then
        print("readonly")
    end
    ftp.host(folder, readperm, writeperm)
end

if #arg < 2 or #arg > 4 then
    usage()
    return nil
end

local host = tonumber(arg[2])
local file = arg[3]
local name = arg[4] or file

if not host then
    usage()
    return
end

if arg[1] == "list" then
    if #arg > 3 then
        usage()
        return
    end
    local status, files = ftp.list(host, file)
    if status == ftp.SUCCESS then
        for i, file in pairs(files) do
            print(("  %s"):format(file))
        end
    else
        print("couldn't fetch file list")
    end
	return
end

if #arg < 3 then
    usage()
    return
end

if arg[1] == "push" then
    print(("uploading %s to %d as %s"):format(file, host, name))
    ftp.push(host, file, name)
    print("done")
elseif arg[1] == "pull" then
    print(("downloading %s from %d as %s"):format(file, host, name))
    ftp.pull(host, file, name)
    print("done")
elseif arg[1] == "pushdir" then
    print(("uploading %s to %d as %s"):format(file, host, name))
    ftp.pushdir(host, file, name)
    print("done")
elseif arg[1] == "pulldir" then
    print(("downloading %s from %d as %s"):format(file, host, name))
    ftp.pulldir(host, file, name)
    print("done")
end
