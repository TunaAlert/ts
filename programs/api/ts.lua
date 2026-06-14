local yaml = require("/programs/api/yaml")
local json = require("/programs/api/json")

local function versionEqualOrHigher(installed, required)
    local iparts = {}
    local rparts = {}

    for part in string.gmatch(installed, "[^%.]+") do
        iparts[#iparts + 1] = part
    end
    for part in string.gmatch(required, "[^%.]+") do
        rparts[#rparts + 1] = part
    end

    for i = 1, #rparts, 1 do
        inum = tonumber(iparts[i] or 0)
        rnum = tonumber(rparts[i])
        if inum < rnum then
            return false
        elseif inum > rnum then
            return true
        end
    end
    
    return true
end

local function getProgramsInRepo(repo)
    if repo.type ~= "github" then
        return {}
    end
    
    local request = http.get(("https://api.github.com/repos/%s/%s/git/trees/%s"):format(repo.owner, repo.repo, repo.branch))
    if request == nil then
        return {}
    end

    local tree_data = json.parse(request.readAll()).tree
    request.close()
    local ts_url = nil
    for i, branch in pairs(tree_data) do
        if branch.path == "ts" then
            ts_url = branch.url
        end
    end

    request = http.get(ts_url)
    if request == nil then
        return {}
    end

    tree_data = json.parse(request.readAll()).tree
    request.close()
    local programs = {}
    for i, branch in pairs(tree_data) do
        if branch.type == "blob" then
            programs[#programs + 1] = string.sub(branch.path, 1, #branch.path - 5)
        end
    end
    
    return programs
end

local function getRepos()
    local config = yaml.load("/.data/ts/config.yaml")
    if config == nil or config.repos == nil then
        return {}
    end
    return config.repos
end

local function getPrograms()
    local repos = getRepos()

    local programs = {}
    for i, repo in pairs(repos) do
        local repoprograms = getProgramsInRepo(repo)
        for i, program in pairs(repoprograms) do
            programs[#programs + 1] = program
        end
    end
    return programs
end

local function getInstalledPrograms()
    local fileList = fs.list("/ts/")
    local programList = {}
    for i, file in pairs(fileList) do
        local data = yaml.load("/ts/" .. file)
        local info = {
            command = string.sub(file, 1, #file-5),
            name = data.name or string.sub(file, 1, #file-5),
            description = data.description or ""
        }
        programList[#programList+1] = info
    end
    return programList
end

local function findRepoForProgram(program)
    local repos = getRepos()
    for i, repo in pairs(repos) do
        if repo.type == "github" then
            if http.get(("https://raw.githubusercontent.com/%s/%s/refs/heads/%s/ts/%s.yaml"):format(repo.owner, repo.repo, repo.branch, program)) ~= nil then
                return repo
            end
        elseif repo.type == "url" then
            if http.get(("%s/ts/%s.yaml"):format(repo.url, program)) ~= nil then
                return repo
            end
        end
    end
    return nil
end

local function install(program, repo, forceDependencies)
    print("Installing program " .. program)
    if repo == nil then
        repo = findRepoForProgram(program)
        if repo == nil then
            print("No suitable repository found")
            return false
        end
        print("Fetching from repository:")
        if repo.type == "github" then
            print(("  github %s/%s/%s"):format(repo.owner, repo.repo, repo.branch))
        else
            print(("  url %s"):format(repo.url))
        end
    end
    local yamlUrl = nil
    local fileUrlGetter = nil
    if repo.type == "github" then
        yamlUrl = ("https://raw.githubusercontent.com/%s/%s/refs/heads/%s/ts/%s.yaml"):format(repo.owner, repo.repo, repo.branch, program)
        fileUrlGetter = function(r, f) return ("https://raw.githubusercontent.com/%s/%s/refs/heads/%s/%s"):format(r.owner, r.repo, r.branch, f) end
    elseif repo.type == "url" then
        yamlUrl = ("%s/ts/%s.yaml"):format(repo.url, program)
        fileUrlGetter = function(r, f) return ("%s/%s"):format(r.url, f) end
    else
        print("Unknown repo type " .. tostring(repo.type))
        return false
    end
    local request = http.get(yamlUrl)
    if request == nil then
        print("Couldn't fetch program data")
        return false
    end
    local data = yaml.parse(request.readAll())
    request.close()
    if data == nil then
        print("Malformed program data")
        return false
    end
    local unmetDependencies = {}
    if data.dependencies ~= nil then
        for i, dependency in pairs(data.dependencies) do
            local depData = yaml.load(("/ts/%s.yaml"):format(dependency.program))
            if depData == nil or depData.version == nil then
                unmetDependencies[#unmetDependencies+1] = dependency
            elseif not versionEqualOrHigher(depData.version, dependency.version) then
                unmetDependencies[#unmetDependencies+1] = dependency
            end
        end
    end
    if #unmetDependencies > 0 and not forceDependencies then
        local userinput = ""
        local firstPass = true
        repeat
            if firstPass then
                print(("%d unmet dependencies for %s. Do you want to install them?"):format(#unmetDependencies, data.name))
            else
                print("please type y or n")
            end
            term.write("y/n > ")
            userinput = io.stdin:read("l")
        until userinput == "y" or userinput == "n"
        if userinput == "n" then
            print("installation aborted")
            return false
        end
    end

    data.repo = repo
    yaml.save(data, ("/ts/%s.yaml"):format(program))
    
    for i, dependency in pairs(unmetDependencies) do
        install(dependency.program, findRepoForProgram(dependency.program), true)
    end
    
    local startupFile = nil
    for i, file in pairs(data.files) do
        request = http.get(fileUrlGetter(repo, file))
        if request ~= nil then
            local handle = io.open(file, "w")
            handle:write(request.readAll())
            handle:close()
            request.close()
            if string.find(file, "^/?startup/") then
                startupFile = file
            end
        end
    end
    if startupFile ~= nil then
        shell.run(startupFile)
    end
    print(("Installed %s"):format(data.name))
    return true
end

local function remove(program)
    local data = yaml.load(("/ts/%s.yaml"):format(program))
    if data == nil then
        print("Didn't find " .. program)
        return false
    end
    print("Removing " .. (data.name or program))
    for i, file in data.files do
        if fs.exists(file) then
            fs.delete(file)
            file = fs.getDir(file)
            while file ~= "" and #fs.list(file) == 0 do
                fs.delete(file)
                file = getDir(file)
            end
        end
    end
    fs.delete(("/ts/%s.yaml"):format(program))
    print("Done")
    return true
end

local function upgrade()
    local fileList = fs.list("/ts/")
    for i, file in pairs(fileList) do
        local data = yaml.load("/ts/" .. file)
        local program = string.sub(file, 1, #file-5)
        install(program, data.repo)
    end
end

local function update()
    install("ts")
end

local function reposEqual(a, b)
    return a.type == b.type and a.url == b.url and a.owner == b.owner and a.repo == b.repo and a.branch == b.branch
end

local function addRepo(repo)
    local config = yaml.load("/.data/ts/config.yaml")
    if config == nil then
        config = {}
    end
    if config.repos == nil then
        config.repos = {}
    end
    local add = true
    for i, preRepo in pairs(config.repos) do
        if reposEqual(preRepo, repo) then
            add = false
        end
    end
    if add then
        config.repos[#config.repos + 1] = repo
        yaml.save(config, "/.data/ts/config.yaml")
        print("Added Repo")
    else
        print("Repo already in repo list")
    end
    return add
end

local function removeRepo(repo)
    local config = yaml.load("/.data/ts/config.yaml")
    if config == nil then
        config = {}
    end
    if config.repos == nil then
        config.repos = {}
    end
    local removed = false
    local index = 0
    for i, preRepo in pairs(config.repos) do
        if reposEqual(preRepo, repo) then
            index = i
            removed = true
        end
    end
    if removed then
        table.remove(config.repos, index)
        yaml.save(config, "/.data/ts/config.yaml")
        print("Repo removed")
    else
        print("Repo not in repo list")
    end
    return removed
end

return {
    getPrograms = getPrograms,
    getInstalledPrograms = getInstalledPrograms,
    getRepos = getRepos,
    install = install,
    remove = remove,
    upgrade = upgrade,
    update = update,
    addRepo = addRepo,
    removeRepo = removeRepo
}
