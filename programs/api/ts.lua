
--TODO: change to load from config
local repos = {
    {owner="TunaAlert", repo="ts", branch="main"}
}

local function getProgramsInRepo(repo)
  local request = http.get(("https://api.github.com/repos/%s/%s/git/trees/%s"):format(repo.owner, repo.repo, repo.branch)
  
  --TODO: load response to programs. We retrieve the ts branch of the returned tree and request another tree from that hash. You'll get it.
  print(request.readAll())
  
  request.close()
  return {}
end

local function getPrograms()
  local programs = {}
  for i, repo in pairs(repos) do
      table.append(programs, getPorgramsInRepo(repo))
  end
  return programs
end

return {
  getPrograms: getPrograms
}
