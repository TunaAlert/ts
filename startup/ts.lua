local completion = require("cc.shell.completion")
local ts = require("/programs/api/ts")

local programs = ts.getPrograms()

shell.setAlias("ts", "/programs/ts.lua")

shell.setCompletionFunction("programs/ts.lua", completion.build(
        {completion.choice, {"install", "remove", "upgrade", "update", "list", "config"}},
        function(shell, text, previous)
            if previous[2] == "install" or previous[2] == "remove" then
                return completion.choice(shell, text, previous, programs)
            elseif previous[2] == "list" then
                return completion.choice(shell, text, previous, {"programs", "repos"})
            elseif previous[2] == "config" then
                return completion.choice(shell, text, previous, {"repo-add", "repo-remove"})
            end
            return nil
        end,
        function(shell, text, previous)
            if previous[2] == "config" or previous[2] == "install" then
                return completion.choice(shell, text, previous, {"-github", "-url"})
            end
            return nil
        end
        ))
