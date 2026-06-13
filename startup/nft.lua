local completion = require("cc.shell.completion")

shell.setAlias("nft", "/programs/nft.lua")

shell.setCompletionFunction("programs/nft.lua", completion.build(
        {completion.choice, {"display", "clean"}},
        completion.file
        ))
