local yaml = require("/programs/api/yaml")
local json = require("/programs/api/json")

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
            command = string.sub(file, 1, #file-4),
            name = data.name or string.sub(file, 1, #file-4),
            description = data.description or ""
        }
        programList[#programList+1] = info
    end
    return programList
end

local function findRepoForProgram(program)
    local programRepo = nil
    local repos = getRepos()
    for i, repo in pairs(repos) do
        if repo.type == "github" then
            if http.get(("https://raw.githubusercontent.com/%s/%s/refs/heads/%s/ts/%s.yaml"):format(repo.owner, repo.repo, repo.branch, program)) ~= nil then
                programRepo = repo
            end
        elseif repo.type == "url" then
            if http.get(("%s/ts/%s.yaml"):format(repo.url, program)) ~= nil then
                programRepo = repo
            end
        end
    end
    return programRepo
end

local function install(program, repo)
    if repo == nil then
        repo = findRepoForProgram(program)
        if repo == nil then
            return false
        end
    end
    local yamlUrl = nil
    local fileUrlGetter = nil
    if repo.type == "github" then
        yamlUrl = ("https://raw.githubusercontent.com/%s/%s/refs/heads/%s/ts/%s.yaml"):format(repo.owner, repo.repo, repo.branch, program)
        fileUrlGetter = function(r, f) return ("https://raw.githubusercontent.com/%s/%s/refs/heads/%s/%s"):format(r.owner, r.repo, r.branch, f) end
    elseif repo.type == "url" then
        yamlurl = ("%s/ts/%s.yaml"):format(repo.url, program)
        fileUrlGetter = function(r, f) return ("%s/%s"):format(r.url, f) end
    else
        return false
    end
    if yamlUrl ~= nil and fileUrlGetter ~= nil then
        local request = http.get(yamlUrl)
        if request == nil then
            return false
        end
        local data = yaml.parse(request.readAll())
        request.close()
        if data == nil then
            return false
        end
        data.repo = repo
        yaml.save(data, ("/ts/%s.yaml"):format(program))
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
        return true
    else
        return false
    end
end

local function remove(program)
    local data = yaml.load(("/ts/%s.lua"):format(program))
    if data == nil then
        return false
    end
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
    fs.delete(("/ts/%s.lua"):format(program))
    return true
end

local function upgrade()
    local fileList = fs.list("/ts/")
    for i, file in pairs(fileList) do
        local data = yaml.load("/ts/" .. file)
        local program = string.sub(filr, 1, #file-4)
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
    local addRepo = true
    for i, preRepo in pairs(config.repos) do
        if reposEqual(preRepo, repo) then
            addRepo = false
        end
    end
    if addRepo then
        config.repos[#config.repos + 1] = repo
        yaml.save(config, "/.data/ts/config.yaml")
    end
    return addRepo
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
