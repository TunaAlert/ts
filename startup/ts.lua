local completion = require("cc.shell.completion")

local repos = {
    {owner="TunaAlert", repo="ts", branch="main"}
}

local programs = {}

for i, repo in pairs(repos) do
    local request = http.get(("https://api.github.com/repos/%s/%s/git/trees/%s"):format(repo.owner, repo.repo, repo.branch)

    --TODO: load response to programs. We retrieve the ts branch of the returned tree and request another tree from that hash. You'll get it.
    print(request.readAll())
    
    request.close()
end
        
shell.setAlias("ts", "/programs/ts.lua")

shell.setCompletionFunction("programs/ts.lua", completion.build(
        {completion.choice, {"install", "remove", "upgrade", "update", "list"}},
        function(shell, text, previous)
            if previous[2] == "install" or previous[2] == "remove" then
                return completion.choice(shell, text, previous, programs)
            end
            return nil
        end
        ))
