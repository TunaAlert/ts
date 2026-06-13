local completion = require("cc.shell.completion")

shell.setAlias("pgps", "/programs/pgps.lua")

shell.setCompletionFunction("programs/pgps.lua", completion.build(
        {completion.choice, {"locate", "fix"}}
        ))
