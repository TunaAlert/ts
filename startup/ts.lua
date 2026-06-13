local completion = require("cc.shell.completion")

local programs = {}
--TODO: load programs

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
