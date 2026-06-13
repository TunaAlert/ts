local completion = require("cc.shell.completion")

shell.setAlias("ftp", "/programs/ftp.lua")

shell.setCompletionFunction("programs/ftp.lua", completion.build(
        {completion.choice, {"host", "list", "push", "pull", "pushdir", "pulldir"}},
        function(shell, text, previous)
            if previous[2] == "host" then
                return completion.dir(shell, text)
            end
            return nil
        end,
        function(shell, text, previous)
            if previous[2] == "host" then
                return completion.choice(shell, text, previous, {"rw", "r", "w"})
            elseif previous[2] == "list" then
                return completion.dir(shell, text)
            elseif previous[2] == "push" then
                return completion.file(shell, text)
            elseif previous[2] == "pull" then
                return completion.file(shell, text)
            elseif previous[2] == "pushdir" then
                return completion.dir(shell, text)
            elseif previous[2] == "pulldir" then
                return completion.dir(shell, text)
            end
            return nil
        end,
        function(shell, text, previous)
            if previous[2] == "push" then
                return completion.file(shell, text)
            elseif previous[2] == "pull" then
                return completion.file(shell, text)
            elseif previous[2] == "pushdir" then
                return completion.dir(shell, text)
            elseif previous[2] == "pulldir" then
                return completion.dir(shell, text)
            end
            return nil
        end
        ))
