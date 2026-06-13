--make sure dependencies are met
if not fs.exists("/programs/api/ts.lua") then
    local request = http.get(("https://raw.githubusercontent.com/TunaAlert/ts/refs/heads/main/programs/api/ts.lua?cb=%x"):format(math.random(0, 2 ^ 30)))
    local handle = io.open("/programs/api/ts.lua", "w")
    handle:write(request.readAll())
    handle:close()
    request.close()
    
    request = http.get(("https://raw.githubusercontent.com/TunaAlert/ts/refs/heads/main/.data/ts/config.yaml?cb=%x"):format(math.random(0, 2 ^ 30)))
    handle = io.open("/.data/ts/config.yaml", "w")
    handle:write(request.readAll())
    handle:close()
    request.close()
end

if not fs.exists("/programs/api/yaml.lua") then
    local request = http.get(("https://raw.githubusercontent.com/TunaAlert/ts/refs/heads/main/programs/api/yaml.lua?cb=%x"):format(math.random(0, 2 ^ 30)))
    local handle = io.open("/programs/api/yaml.lua", "w")
    handle:write(request.readAll())
    handle:close()
    request.close()
end

local ts = require("/programs/api/ts")

local function usage()
    print("usage: ts install <program> [-github <owner> <repo> <branch> | -url <rurl>]")
    print("  or   ts remove <program>")
    print("  or   ts upgrade")
    print("  or   ts update")
    print("  or   ts list [programs | repos]")
    print("  or   ts config <repo-add | repo-remove> <-github <owner> <repo> <branch> | -url <url>>")
end

if #arg < 1 then
    usage()
    return
end

local cmd = arg[1]

if cmd == "install" then
    if #arg < 2 then
        usage()
        return
    end
    local program = arg[2]
    local repo = nil
    if #arg > 2 then
        if arg[3] == "-github" then
            if #arg ~= 6 then
                usage()
                return
            end
            repo = {
                type = "gitgub",
                owner = arg[4],
                repo = arg[5],
                branch = arg[6],
            }
        elseif arg[3] == "-url" then
            if #arg ~= 4 then
                usage()
                return
            end
            repo = {
                type = "url",
                url = arg[4]
            }
        else
            usage()
            return
        end
    end
    ts.install(program, repo)
elseif cmd == "remove" then
    if #arg ~= 2 then
        usage()
        return
    end
    local program = arg[2]
    ts.remove(program)
elseif cmd == "upgrade" then
    if #arg ~= 1 then
        usage()
        return
    end
    ts.upgrade()
elseif cmd == "update" then
    if #arg ~= 1 then
        usage()
        return
    end
    ts.update()
elseif cmd == "list" then
    if #arg > 2 then
        usage()
        return
    end
    local what = "programs"
    if #arg == 2 then
        what = arg[2]
    end
    if what == "programs" then
        local programs = ts.getInstalledPrograms()
        local lines = {}
        for i, program in pairs(programs) do
            lines[i] = ("%-8s %s"):format(program.command, program.name)
        end
        local pages = table.concat(lines, "\n")
        textutils.pagedPrint(pages)
    elseif what == "repos" then
        local repos = ts.getRepos()
        local lines = {}
        for i, repo in pairs(repos) do
            if repo.type == "github" then
                lines[i] = ("github: %s/%s/%s"):format(repo.owner, repo.repo, repo.branch)
            elseif repo.type == "url" then
                lines[i] = ("url: %s"):format(repo.url)
            else
                lines[i] = ("malformed repo")
            end
        end
        local pages = table.concat(lines, "\n")
        textutils.pagedPrint(pages)
    else
        usage()
        return
    end
elseif cmd == "config" then
    if #arg < 4 or #arg > 6 then
        usage()
        return
    end
    if arg[2] == "repo-add" then
        if arg[3] == "-github" then
            if #arg ~= 6 then
                usage()
                return
            end
            local repo = {
                type = "github",
                owner = arg[4],
                repo = arg[5],
                branch = arg[6]
            }
            ts.addRepo(repo)
        elseif arg[3] == "-url" then
            if #arg ~= 4 then
                usage()
                return
            end
            local repo = {
                type = "url",
                url = arg[4]
            }
            ts.addRepo(repo)
        else
            usage()
            return
        end
    elseif arg[2] == "repo-remove" then
        if arg[3] == "-github" then
            if #arg ~= 6 then
                usage()
                return
            end
            local repo = {
                type = "github",
                owner = arg[4],
                repo = arg[5],
                branch = arg[6]
            }
            ts.removeRepo(repo)
        elseif arg[3] == "-url" then
            if #arg ~= 4 then
                usage()
                return
            end
            local repo = {
                type = "url",
                url = arg[4]
            }
            ts.removeRepo(repo)
        else
            usage()
            return
        end
    else
        usage()
        return
    end
else
    usage()
    return
end
