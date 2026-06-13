local nft = require("cc.image.nft")

local function usage()
    print("Usage: nft display <file>")
    print("  or   nft clean <file>")
end

if #arg ~= 2 then
    usage()
    return
end

local cmd = arg[1]
local file = arg[2]

if cmd == "display" then
    local image = nft.load(file)
    for i = 1, #image, 1 do
        print()
    end
    local x, y = term.getCursorPos()
    nft.draw(image, 2, y-#image)
    print()
elseif cmd == "clean" then
    local buffer = ""
    for line in io.lines(file) do
        for c = 1, #line, 1 do
            local char = string.sub(line, c, c)
            if char ~= string.char(0xc2) then
                buffer = buffer .. char
            end
        end
        buffer = buffer .. "\n"
    end
    
    local fileout = fs.open(file, "w")
    fileout.write(buffer)
    fileout.close()
else
    usage()
    return
end
