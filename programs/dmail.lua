local dmail = require("/programs/api/dmail")
local yaml = require("/programs/api/yaml")

local exited = false

local termWidth, termHeight = term.getSize()

local messageList = window.create(term.current(), 1, 4, termWidth, termHeight - 5)
local messageBody = window.create(term.current(), 2, 5, termWidth-1, termHeight - 5)
local parentTerm = term.current()

local status = {}
local messages = {}
local readMessages = yaml.load("/.data/dmail/read.yaml")
if readMessages ~= nil and readMessages.read ~= nil then
    readMessages = readMessages.read
else
    readMessages = {}
end
local attachmentsDownloaded = {}

local scroll = 0
local selectedDmail = 0

local dmailListMenu
local dmailDisplayMenu
local composeDmailMenu

local menuButtons = {}
local menuButtonSelected = {0, 0}

local config = yaml.load("/.data/dmail/config.yaml")
if config == nil then
    config = {
        main_server = 20,
        servers = {20}
        }
    yaml.save(config, "/.data/dmail/config.yaml")
end

local contacts = yaml.load("/.data/dmail/contacts.yaml")
if contacts == nil or contacts.contacts == nil then
    contacts = {{name = "Tuna", id = 9}}
    yaml.save({contacts = contacts}, "/.data/dmail/contacts.yaml")
else
    contacts = contacts.contacts
end

local function nameOrID(id)
    for i, contact in pairs(contacts) do
        if contact.id == id then
            return contact.name
        end
    end
    return tostring(id)
end

local function isMessageRead(messageId)
    for i, message in pairs(readMessages) do
        if message == messageId then
            return true
        end
    end
    return false
end

local function setMessageRead(messageId)
    if isMessageRead(messageId) then
        return
    end
    readMessages[#readMessages + 1] = messageId
    yaml.save({read = readMessages}, "/.data/dmail/read.yaml")
end

local function deleteMessage(messageId)
    local messageFile = ("/.data/dmail/inbox/%s.mail"):format(messageId)
    local attachmentDir = ("/.data/dmail/attachments/%s"):format(messageId)
    if fs.exists(messageFile) then
        fs.delete(messageFile)
    end
    if fs.exists(attachmentDir) then
        fs.delete(attachmentDir)
    end
    local readIndex = 0
    for i, message in pairs(readMessages) do
        if message == messageId then
            readIndex = i
        end
    end
    if readIndex ~= 0 then
        table.remove(readMessages, readIndex)
    end
end

local function loadMessages()
    status = {}
    messages = dmail.fetchLocal()
    for i, message in pairs(messages) do
        message.read = isMessageRead(message.id)
        message.selected = false
    end
    for i, server in pairs(config.servers) do
        local s, m = dmail.fetch(server)
        status[#status + 1] = s
        for j, message in pairs(m) do
            message.read = isMessageRead(message.id)
            message.selected = false
            messages[#messages + 1] = message
        end
    end

    table.sort(messages, function(a, b) return a.id > b.id end)
end

local function unreadCount()
    local count = 0
    for i, message in pairs(messages) do
        if not message.read then
            count = count + 1
        end
    end
    return count
end

local function hasUnselectedMessages()
    for i, message in pairs(messages) do
        if not message.selected then
            return true
        end
    end
    return false
end

local function drawLoadingLoop()
    local bufferx = math.random(0, 16)
    while true do
        term.redirect(parentTerm)
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.white)
        term.clear()

        bufferx = bufferx + 1

        term.setCursorPos(termWidth/2 - 7, 3)
        term.write("Loading Dmails")

        for i = 1, 4, 1 do
            if (i + bufferx) % 16 ~= 0 then
                term.setCursorPos(termWidth/2 - 3 + i, termHeight/2 - 2)
                term.write("#")
            end
            if (i + 4 + bufferx) % 16 ~= 0 then
                term.setCursorPos(termWidth/2 + 2, termHeight/2 - 3 + i)
                term.write("#")
            end
            if (i + 8 + bufferx) % 16 ~= 0 then
                term.setCursorPos(termWidth/2 + 3 - i, termHeight/2 + 2)
                term.write("#")
            end
            if (i + 12 + bufferx) % 16 ~= 0 then
                term.setCursorPos(termWidth/2 - 2, termHeight/2 + 3 - i)
                term.write("#")
            end
        end
            
        sleep(0.05)
    end
end

local function displayDmailList()
    messageList.setVisible(true)
    messageBody.setVisible(false)

    term.redirect(parentTerm)
    term.setBackgroundColor(colors.black)
    term.clear()
    term.setCursorPos(1, 1)
    term.setTextColor(colors.white)
    local unread = unreadCount()
    if unread == 0 then
        term.write("no unread messages")
    elseif unread == 1 then
        term.write("1 unread message")
    else
        term.write(("%d unread messages"):format(unread))
    end
    term.setCursorPos(1, 2)
    if hasUnselectedMessages() then
        if menuButtonSelected[1] == 1 and menuButtonSelected[2] == 1 then
            term.blit("[all]  ", "1000100", "fffffff")
        else
            term.write("[all]  ")
        end
    else
        if menuButtonSelected[1] == 1 and menuButtonSelected[2] == 1 then
            term.blit("[none] ", "1000010", "fffffff")
        else
            term.write("[none] ")
        end
    end
    
    if menuButtonSelected[1] == 1 and menuButtonSelected[2] == 2 then
        term.blit("[read] ", "1000010", "fffffff")
    else
        term.write("[read] ")
    end
    
    if menuButtonSelected[1] == 1 and menuButtonSelected[2] == 3 then
        term.blit("[delete]", "10000001", "ffffffff")
    else
        term.write("[delete]")
    end
    
    term.setCursorPos(termWidth-12, termHeight)
    term.setTextColor(colors.yellow)
    if menuButtonSelected[1] == #menuButtons then
        term.blit("[New DMail]", "10000000001", "fffffffffff")
    else
        term.write("[New DMail]")
    end
    term.redirect(messageList)
    
    messageList.setBackgroundColor(colors.black)
    messageList.clear()
    
    local offset = 0
    
    for i, s in ipairs(status) do
        if s ~= dmail.SUCCESS then
            messageList.setCursorPos(1, 1+offset)
            messageList.setTextColor(colors.red)
            messageList.write(("  error status %d"):format(s))
            offset = offset + 1
        end
    end
    if #messages == 0 then
        messageList.setCursorPos(termWidth/2 - 5, 1 + offset)
        messageList.setTextColor(colors.gray)
        messageList.write("No messages")
    end
    for i, message in ipairs(messages) do
        if i - scroll + offset >= 1 and i - scroll + offset <= ({messageList.getSize()})[2] then
            messageList.setCursorPos(1, i-scroll + offset)
            local defaultColor = colors.white
            if message.read then
                defaultColor = colors.lightGray
            end
            local bullet = "o"
            if message.selected then
                bullet = "\xf8"
            end
            if menuButtonSelected[1] == i+1 then
                messageList.setBackgroundColor(colors.gray)
            else
                messageList.setBackgroundColor(colors.black)
            end
            messageList.clearLine()
            if menuButtonSelected[1] == i+1 and menuButtonSelected[2] == 1 then
                messageList.setTextColor(colors.orange)
            else
                messageList.setTextColor(defaultColor)
            end
            messageList.write(bullet)
            if menuButtonSelected[1] == i+1 and menuButtonSelected[2] == 2 then
                messageList.setTextColor(colors.orange)
            else
                messageList.setTextColor(defaultColor)
            end
            messageList.write(
                (" %s %s"):format(
                    string.sub(nameOrID(message.sender) .. "      ", 1, 6),
                    message.subject
                ))
        end
    end
end

local function displayDmail()
    messageList.setVisible(false)
    messageBody.setVisible(true)

    local message = messages[selectedDmail]
    if message == nil then
        return
    end

    term.redirect(parentTerm)
    term.setBackgroundColor(colors.black)
    term.clear()
    term.setCursorPos(1, 1)
    term.clearLine()
    term.setTextColor(colors.yellow)
    if menuButtonSelected[1] == 1 then
        term.blit("[Back]", "144441", "ffffff")
    else
        term.write("[Back]")
    end
    term.setCursorPos(1, 2)
    term.clearLine()
    term.setTextColor(colors.white)
    term.write(message.subject)
    term.setTextColor(colors.lime)
    term.setCursorPos(1, 3)
    term.clearLine()
    term.write("  From " .. message.sender)
    
    term.redirect(messageBody)

    messageBody.setTextColor(colors.white)
    messageBody.setBackgroundColor(colors.black)
    messageBody.clear()
    messageBody.scroll(scroll)
    messageBody.setCursorPos(1, 1)
    message.lineCount = write(message.body)
    for i, attachment in ipairs(message.attachments) do
        messageBody.setCursorPos(3, message.lineCount+1+i)
        local defaultColor = colors.yellow
        if attachmentsDownloaded[i] == true then
            defaultColor = colors.lime
        elseif attachmentsDownloaded[i] == false then
            defaultColor = colors.red
        end
        if menuButtonSelected[1] == #menuButtons - #message.attachments + i then
            messageBody.setTextColor(defaultColor)
            messageBody.write("+ ")
            messageBody.setTextColor(colors.orange)
            messageBody.write("[")
            messageBody.setTextColor(defaultColor)
            messageBody.write(attachment)
            messageBody.setTextColor(colors.orange)
            messageBody.write("]")
        else
            messageBody.setTextColor(defaultColor)
            messageBody.write("+  " .. attachment)
        end
    end
end

local function clampScrollInList(value)
    return math.max(math.min(value, #messages - ({messageList.getSize()})[2]), 0)
end

local function clampScrollInDmail(value)
    return math.max(math.min(value, #messages - ({messageBody.getSize()})[2]), 0)
end

local function handleMenuKeyEvent(key)
    if key == "down" then
        menuButtonSelected[1] = (math.max(math.min(menuButtonSelected[1], #menuButtons), 1)) % #menuButtons + 1
        menuButtonSelected[2] = math.max(math.min(menuButtonSelected[2], #menuButtons[menuButtonSelected[1]]), 1)
    elseif key == "up" then
        menuButtonSelected[1] = (math.max(math.min(menuButtonSelected[1], #menuButtons), 1) - 2) % #menuButtons + 1
        menuButtonSelected[2] = math.max(math.min(menuButtonSelected[2], #menuButtons[menuButtonSelected[1]]), 1)
    elseif key == "left" then
        menuButtonSelected[2] = (math.max(math.min(menuButtonSelected[2], #menuButtons[menuButtonSelected[1]]), 1) - 2) % #menuButtons + 1
    elseif key == "right" then
        menuButtonSelected[2] = (math.max(math.min(menuButtonSelected[2], #menuButtons[menuButtonSelected[1]]), 1)) % #menuButtons + 1
    elseif key == "enter" then
        menuButtonSelected[1] = math.max(math.min(menuButtonSelected[1], #menuButtons), 1)
        menuButtonSelected[2] = math.max(math.min(menuButtonSelected[2], #menuButtons[menuButtonSelected[1]]), 1)
        menuButtons[menuButtonSelected[1]][menuButtonSelected[2]]()
    end
end

dmailListMenu = function()
    local nextMenu = nil
    scroll = 0
    
    parallel.waitForAny(loadMessages, drawLoadingLoop)

    menuButtons = {
        {
            function()
                local flagSet = hasUnselectedMessages()
                for i, message in pairs(messages) do
                    message.selected = flagSet
                end
            end,
            function()
                for i, message in pairs(messages) do
                    message.selected = message.read
                end
            end,
            function()
                for i, message in pairs(messages) do
                    if message.selected then
                        deleteMessage(message.id)
                    end
                end
                parallel.waitForAny(loadMessages, drawLoadingLoop)
            end
        }
    }
    for i, message in ipairs(messages) do
        local buttons = {
            function()
               message.selected = not message.selected
            end,
            function()
                selectedDmail = i
                nextMenu = dmailDisplayMenu
                setMessageRead(message.id)
            end
        }
        menuButtons[#menuButtons + 1] = buttons
    end
    menuButtons[#menuButtons + 1] = {
        function()
            nextMenu = composeDmailMenu
        end
    }
    menuButtonSelected = {0, 0}
    
    displayDmailList()

    while not exited and nextMenu == nil do
        local event, a, b, c, d, e, f = os.pullEvent()
        if event == "mouse_click" then
            local button, x, y = a, b, c
            local yoffs = ({messageList.getPosition()})[2] - 1
            local clickedLine = y-yoffs+scroll
            if y == 2 then
                if x <= 6 then
                    menuButtons[1][1]()
                elseif x >= 8 and x <= 13 then
                    menuButtons[1][2]()
                elseif x >= 15 and x <= 22 then
                    menuButtons[1][3]()
                end
            elseif y == termHeight then
                if x >= termWidth - 12 then
                    menuButtons[#menuButtons][1]()
                end
            elseif y > yoffs and clickedLine > 0 and clickedLine <= #messages then
                if x < 3 then
                    menuButtons[clickedLine+1][1]()
                else
                    menuButtons[clickedLine+1][2]()
                end
            end
            displayDmailList()
        elseif event == "mouse_scroll" then
            local dir = a
            scroll = clampScrollInList(scroll + dir)
            displayDmailList()
        elseif event == "key" then
            local key = keys.getName(a)
            handleMenuKeyEvent(key)
            if menuButtonSelected[1] > 1 and menuButtonSelected[1] < #menuButtons then
                scroll = clampScrollInList(menuButtonSelected[1] - ({messageList.getSize()})[2] / 2)
            end
            displayDmailList()
        end
    end
    return nextMenu
end

dmailDisplayMenu = function()
    local nextMenu = nil
    
    scroll = 0
    menuButtonSelected = {0, 0}
    attachmentsDownloaded = {}
    local selectedMessage = messages[selectedDmail]
    
    displayDmail()
    
    menuButtons = {
        {
            function()
                nextMenu = dmailListMenu
                selectedDmail = 0
            end
        }
    }
    for i = 1, ({messageBody.getSize()})[2] - selectedMessage.lineCount, 1 do
        local filler = {
            function() end
        }
        menuButtons[#menuButtons + 1] = filler
    end
    for i, attachment in ipairs(selectedMessage.attachments) do
        local buttons = {
            function()
                local attachmentFile = ("/.data/dmail/attachments/%s/%s"):format(selectedMessage.id, attachment)
                if not fs.exists(attachmentFile) then
                    attachmentsDownloaded[i] = false
                    return
                end
                local extensionpos = {string.find(attachment, "%.%w$")}
                local extension = ""
                if #extensionpos > 0 then
                    extension = string.sub(attachment, extensionpos[1], extensionpos[2])
                end
                local saveFile = "/downloads/" .. attachment
                local x = 1
                while fs.exists(saveFile) do
                    saveFile = ("/downloads/%s %d%s"):format(string.sub(attachment, 1, #attachment - #extension), x, extension)
                    x = x + 1
                end
                fs.copy(attachmentFile, saveFile)
                attachmentsDownloaded[i] = true
            end
        }
        menuButtons[#menuButtons + 1] = buttons
    end

    displayDmail()
    
    while not exited and nextMenu == nil do
        local event, a, b, c, d, e, f = os.pullEvent()
        if event == "mouse_click" then
            local button, x, y = a, b, c
            if y == 1 then
                if x <= 6 then
                    menuButtons[1][1]()
                end
            end
            displayDmail()
        elseif event == "mouse_scroll" then
            local dir = a
            scroll = clampScrollInDmail(scroll + dir)
            displayDmail()
        elseif event == "key" then
            local key = keys.getName(a)
            handleMenuKeyEvent(key)
            if menuButtonSelected[1] > 1 and menuButtonSelected[1] < #menuButtons then
                scroll = clampScrollInDmail(menuButtonSelected[1] - ({messageList.getSize()})[2] / 2)
            end
            displayDmail()
        end
    end
    return nextMenu
end

composeDmailMenu = function()
    scroll = 0

    composeDmail()
    
    local nextMenu = nil
    while not exited and nextMenu == nil do
        local event, a, b, c, d, e, f = os.pullEvent()
    end
    return nextMenu
end

local nextMenu = dmailListMenu

while not exited and nextMenu ~= nil do
    nextMenu = nextMenu()
end
