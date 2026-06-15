local dmail = require("/programs/api/dmail")
local yaml = require("/programs/api/yaml")

local exited = false

local termWidth, termHeight = term.getSize()

local messageList = window.create(term.current(), 1, 4, termWidth, termHeight - 5)
local messageBody = window.create(term.current(), 2, 5, termWidth-1, termHeight - 6)
local attachmentList = window.create(term.current(), 2, 5, termWidth-1, termHeight - 5)
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
local composedMessage = {}

local dmailListMenu
local dmailDisplayMenu
local composeDmailMenu

local menuButtons = {}
local menuButtonSelected = {0, 0}

local PopUp = {
    new = function()
        local pu = {}
        pu.title = ""
        pu.messages = {}
        pu.buttons = {}
        pu.getWidth = function()
            return termWidth - 4
        end
        pu.getHeight = function()
            if #pu.messages == 0 then
                return 5
            else
                return #pu.messages + 6
            end
        end
        
        if menuButtonSelected[1] > 0 then
            menuButtonSelected = {1, 1}
        end
        return pu
    end
}
local popUp

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
        if s ~= dmail.SUCCESS then
            status[#status + 1] = {server = server, status = s}
        end
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

local function getLines(text, maxWidth)
    local lines = {""}
    local firstParagraph = true
    for paragraph in string.gmatch(text .. "\n", "([^\n]*)\n?") do
        if firstParagraph then
            firstParagraph = false
        else
            lines[#lines] = lines[#lines] .. "\n"
            lines[#lines+1] = ""
        end
        for token in string.gmatch(paragraph .. " ", "(%S*)%s?") do
           if lines[#lines] == "" then
                lines[#lines] = token
            elseif #lines[#lines] + #token + 1 > maxWidth then
                lines[#lines] = lines[#lines] .. " "
                lines[#lines+1] = token
            else
                lines[#lines] = lines[#lines] .. " " .. token
            end
        end
    end
    return lines
end

local function getBodyPosInLine(body, maxWidth, lineIndex, columnIndex)
    local lines = getLines(body, maxWidth)
    local index = 0
    local croppedBody = body
    for i = 1, lineIndex - 1, 1 do
        local s, e = string.find(croppedBody, lines[i])
        croppedBody = string.sub(croppedBody, e)
        index = index + e
    end
    return index + math.min(columnIndex, #lines[lineIndex] + 1)
end

local function getLinePosInBody(body, maxWidth, index)
    local lines = getLines(body, maxWidth)
    local line = 1
    local accumulativeLength = 0
    while line <= #lines and accumulativeLength + #lines[line] < index - 1 do
        accumulativeLength = accumulativeLength + #lines[line]
        line = line + 1
    end
    local column = index - accumulativeLength
    return line, column
end

local function writeNoPush(redirect, text)
    local maxWidth, maxHeight = redirect.getSize()
    local lines = getLines(text, maxWidth)
    for i, line in ipairs(lines) do
        local y = i - scroll
        if y > 0 and y <= maxHeight then
            redirect.setCursorPos(1, y)
            redirect.write("^" .. line .. "$")
        end
    end
    return lines
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
    attachmentList.setVisible(false)

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
    term.setTextColor(colors.yellow)
    if hasUnselectedMessages() then
        if menuButtonSelected[1] == 1 and menuButtonSelected[2] == 1 then
            term.blit("[all]  ", "1444100", "fffffff")
        else
            term.write("[all]  ")
        end
    else
        if menuButtonSelected[1] == 1 and menuButtonSelected[2] == 1 then
            term.blit("[none] ", "1444410", "fffffff")
        else
            term.write("[none] ")
        end
    end
    
    if menuButtonSelected[1] == 1 and menuButtonSelected[2] == 2 then
        term.blit("[read] ", "1444410", "fffffff")
    else
        term.write("[read] ")
    end
    
    if menuButtonSelected[1] == 1 and menuButtonSelected[2] == 3 then
        term.blit("[delete]", "e111111e", "ffffffff")
    else
        term.write("[delete]")
    end

    term.setTextColor(colors.yellow)
    term.setCursorPos(2, termHeight)
    if menuButtonSelected[1] == #menuButtons and menuButtonSelected[2] == 1 then
        term.blit("[Exit]", "144441", "ffffff")
    else
        term.write("[Exit]")
    end
    
    term.setCursorPos(termWidth-11, termHeight)
    if menuButtonSelected[1] == #menuButtons and menuButtonSelected[2] == 2 then
        term.blit("[New DMail]", "14444444441", "fffffffffff")
    else
        term.write("[New DMail]")
    end
    term.redirect(messageList)
    
    messageList.setBackgroundColor(colors.black)
    messageList.clear()
    
    local offset = 0
    
    for i, s in ipairs(status) do
        messageList.setCursorPos(1, 1+offset)
        messageList.setTextColor(colors.red)
        local errorString = "unknown error"
        if s.status == dmail.ACCESS_DENIED then
            errorString = "access denied"
        elseif s.status == dmail.NO_RESPONSE then
            errorString = "no response"
        end
        messageList.write(("  server %d: %s"):format(s.server, errorString))
        offset = offset + 1
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
    attachmentList.setVisible(false)

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
    term.write("  From " .. nameOrID(message.sender))
    
    term.redirect(messageBody)

    messageBody.setTextColor(colors.white)
    messageBody.setBackgroundColor(colors.black)
    messageBody.clear()
    message.lineCount = #writeNoPush(messageBody, message.body)
    for i, attachment in ipairs(message.attachments) do
        messageBody.setCursorPos(3, message.lineCount+1+i - scroll)
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

local function composeDmail()
    messageList.setVisible(false)
    messageBody.setVisible(not attachmentList.isVisible())
    
    term.redirect(parentTerm)
    term.setBackgroundColor(colors.black)
    term.clear()

    term.setTextColor(colors.yellow)
    term.setCursorPos(1, 1)
    if popUp == nil and menuButtonSelected[1] == 1 and menuButtonSelected[2] == 1 then
        term.blit("[Back]", "144441", "ffffff")
    else
        term.write("[Back]")
    end
    term.setCursorPos(termWidth/2 - 6, 1)
    if popUp == nil and menuButtonSelected[1] == 1 and menuButtonSelected[2] == 2 then
        term.blit("[Attachments]", "1444444444441", "fffffffffffff")
    else
        term.write("[Attachments]")
    end

    term.setCursorPos(termWidth-6, 1)
    if popUp == nil and menuButtonSelected[1] == 1 and menuButtonSelected[2] == 3 then
        term.blit("[Send]", "144441", "ffffff")
    else
        term.write("[Send]")
    end
    
    term.setTextColor(colors.white)
    term.setCursorPos(1, 2)
    term.write("Sub:")
    term.setCursorPos(1, 3)
    term.write("To:")
    
    term.setCursorPos(5, 2)
    if composedMessage.subject == "" then
        term.setTextColor(colors.gray)
        term.write("subject")
    else
        term.setTextColor(colors.white)
        term.write(composedMessage.subject)
    end

    term.setCursorPos(5, 3)
    if type(composedMessage.recipient) == "string" and #composedMessage.recipient > 0 then
        term.setTextColor(colors.red)
        term.write(composedMessage.recipient)
    elseif type(composedMessage.recipient) == "number" and composedMessage.recipient ~= 0 then
        term.setTextColor(colors.green)
        term.write(nameOrID(composedMessage.recipient))
    else
        term.setTextColor(colors.gray)
        term.write("recipient")
    end

    if attachmentList.isVisible() then
        attachmentList.setBackgroundColor(colors.black)
        attachmentList.clear()
        
    else
        messageBody.setBackgroundColor(colors.black)
        messageBody.clear()
    
        messageBody.setCursorPos(1, 1 - scroll)
        if composedMessage.body == "" then
            messageBody.setTextColor(colors.gray)
            messageBody.write("Your message")
            composedMessage.lines = {""}
        else
            messageBody.setTextColor(colors.white)
            composedMessage.lines = writeNoPush(messageBody, composedMessage.body)
        end

        messageBody.setTextColor(colors.lime)
        for i, attachment in ipairs(composedMessage.attachments) do
            messageBody.setCursorPos(1, #composedMessage.lines + 1 + i - scroll)
            messageBody.write("  +  " .. fs.getName(attachment))
        end
        
        if menuButtonSelected[1] > 1 then
            if menuButtonSelected[1] == 2 then
                term.setCursorPos(4+menuButtonSelected[2], 2)
            elseif menuButtonSelected[1] == 3 then
                term.setCursorPos(4+menuButtonSelected[2], 3)
            else
                messageBody.setCursorPos(menuButtonSelected[2], menuButtonSelected[1] - scroll - 3)
            end
            term.setTextColor(colors.white)
            term.setCursorBlink(true)
        else
            term.setCursorBlink(false)
        end
    end
    
    if popUp ~= nil then
        term.setCursorBlink(false)
        local w = popUp.getWidth()
        local h = popUp.getHeight()
        local x = (termWidth - w) / 2
        local y = (termHeight - h) / 2

        term.setTextColor(colors.orange)
        term.setBackgroundColor(colors.gray)
        for i = 1, w, 1 do
            term.setCursorPos(x+i-1, y)
            term.write("#")
            term.setCursorPos(x+i-1, y+h-1)
            term.write("#")
        end
        for i = 2, h-1, 1 do
            term.setCursorPos(x, y+i-1)
            term.write("#")
            term.setCursorPos(x+w-1, y+i-1)
            term.write("#")
        end
        term.setBackgroundColor(colors.black)
        
        term.setTextColor(colors.yellow)
        term.setCursorPos(x+2, y+1)
        term.write(string.sub(popUp.title, 1, w-4))

        term.setTextColor(colors.red)
        for i, message in ipairs(popUp.messages) do
            term.setCursorPos(x+3, y+2+i)
            term.write(string.sub(message, 1, w-5))
        end

        term.setCursorPos(x+2, y+h-2)
        for i, button in ipairs(popUp.buttons) do
            if menuButtonSelected[2] == i then
                term.setTextColor(colors.orange)
                term.write("[")
                term.setTextColor(colors.yellow)
                term.write(button.label)
                term.setTextColor(colors.orange)
                term.write("] ")
            else
                term.setTextColor(colors.yellow)
                term.write("[" .. button.label .. "] ")
            end
        end
    end
end

local function clampScrollInList(value)
    return math.max(math.min(value, #messages + #status - ({messageList.getSize()})[2]), 0)
end

local function clampScrollInDmail(value)
    if selectedDmail > 0 then
        return math.max(math.min(value, messages[selectedDmail].lineCount + 2 + #messages[selectedDmail].attachments - ({messageBody.getSize()})[2]), 0)
    else
        return 0
    end
end

local function clampScrollInCompose(value)
    return math.max(math.min(value, 100), 0)
end

local function handleMenuKeyEvent(key)
    if key == keys.down then
        menuButtonSelected[1] = (math.max(math.min(menuButtonSelected[1], #menuButtons), 1)) % #menuButtons + 1
        menuButtonSelected[2] = math.max(math.min(menuButtonSelected[2], #menuButtons[menuButtonSelected[1]]), 1)
    elseif key == keys.up then
        menuButtonSelected[1] = (math.max(math.min(menuButtonSelected[1], #menuButtons), 1) - 2) % #menuButtons + 1
        menuButtonSelected[2] = math.max(math.min(menuButtonSelected[2], #menuButtons[menuButtonSelected[1]]), 1)
    elseif key == keys.left then
        menuButtonSelected[2] = (math.max(math.min(menuButtonSelected[2], #menuButtons[menuButtonSelected[1]]), 1) - 2) % #menuButtons + 1
    elseif key == keys.right then
        menuButtonSelected[2] = (math.max(math.min(menuButtonSelected[2], #menuButtons[menuButtonSelected[1]]), 1)) % #menuButtons + 1
    elseif key == keys.enter then
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
            exited = true
        end,
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
            local clickedLine = y-yoffs+scroll-#status
            if y == 2 then
                if x <= 6 then
                    menuButtons[1][1]()
                elseif x >= 8 and x <= 13 then
                    menuButtons[1][2]()
                elseif x >= 15 and x <= 22 then
                    menuButtons[1][3]()
                end
            elseif y == termHeight then
                if x <= 7 then
                    menuButtons[#menuButtons][1]()
                elseif x >= termWidth - 11 then
                    menuButtons[#menuButtons][2]()
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
            menuButtonSelected = {0, 0}
            scroll = clampScrollInList(scroll + dir)
            displayDmailList()
        elseif event == "key" then
            local key = a
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
    for i = 1, selectedMessage.lineCount + 2 - ({messageBody.getSize()})[2], 1 do
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
                    attachmentsDownloaded[i] = nil
                    displayDmail()
                    dmail.fetchAttachments(selectedMessage.server, selectedMessage.id, {attachment})
                    if not fs.exists(attachmentFile) then
                        attachmentsDownloaded[i] = false
                        return
                    end
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
            local pos = {messageBody.getPosition()}
            local size = {messageBody.getSize()}
            if y == 1 then
                if x <= 6 then
                    menuButtons[1][1]()
                end
            elseif y >= pos[2] and y < pos[2] + size[2] then
                local lineClicked = y - pos[2] + 2 + scroll
                if lineClicked > selectedMessage.lineCount + 2 and lineClicked <= selectedMessage.lineCount + 2 + #selectedMessage.attachments then
                    local attachmentClicked = lineClicked - selectedMessage.lineCount - 2
                    menuButtons[#menuButtons - #selectedMessage.attachments + attachmentClicked][1]()
                end
            end
            displayDmail()
        elseif event == "mouse_scroll" then
            local dir = a
            menuButtonSelected = {0, 0}
            scroll = clampScrollInDmail(scroll + dir)
            displayDmail()
        elseif event == "key" then
            local key = a
            handleMenuKeyEvent(key)
            if menuButtonSelected[1] >= 1 and menuButtonSelected[1] <= #menuButtons then
                scroll = clampScrollInDmail(menuButtonSelected[1]- 1)
            end
            displayDmail()
        end
    end
    return nextMenu
end

composeDmailMenu = function()
    attachmentList.setVisible(false)
    local nextMenu = nil
    scroll = 0

    composedMessage = {
        subject = "",
        recipient = "",
        body = "",
        lines = {""},
        attachments = {}
    }

    menuButtons = {
        {
            function()
                if attachmentList.isVisible() then
                    attachmentList.setVisible(false)
                else
                    if composedMessage.body == "" and #composedMessage.attachments == 0 then
                        popUp = PopUp.new()
                        popUp.title = "Are you sure?"
                        popUp.messages = {"Your message will", "be discarded."}
                        popUp.buttons = {
                            {
                                label = "Cancel",
                                click = function()
                                    popUp = nil
                                end
                            },
                            {
                                label = "Discard",
                                click = function()
                                    popUp = nil
                                    nextMenu = dmailListMenu
                                end
                            }
                        }
                    else
                        nextMenu = dmailListMenu
                    end
                end
            end,
            function()
                attachmentList.setVisible(true)
                scroll = 0
            end,
            function()
                if type(recipient) == "number" and recipient ~= 0 then
                    local status = dmail.send(config.mainServer, composedMessage.recipient, composedMessage.subject, composedMessage.body, composedMessage.attachments)
                    if status[1] ~= dmail.SUCCESS then
                        popUp = PopUp.new()
                        popUp.title = "Dmail not Sent"
                        popUp.buttons = {
                            {
                                label = "Close",
                                click = function()
                                    popUp = nil
                                end
                            }
                        }
                    else
                        local failed = {}
                        for i, s in ipairs(status) do
                            if s ~= dmail.SUCCESS then
                                failed[#failed+1] = fs.getName(composedMessage.attachments[i-1])
                            end
                        end
                        popUp = PopUp.new()
                        popUp.title = "Dmail Sent"
                        popUp.buttons = {
                            {
                                label = "Menu",
                                click = function()
                                    popUp = nil
                                    nextMenu = dmailListMenu
                                end
                            },
                            {
                                label = "New",
                                click = function()
                                    popUp = nil
                                    nextMenu = composeDmailMenu
                                end
                            }
                        }
                        if #failed > 0 then
                            table.insert(failed, 1, "Failed to send:")
                            popUp.messages = failed
                        end
                    end
                end
            end
        }
    }

    menuButtonSelected = {0, 0}
    
    composeDmail()
    
    while not exited and nextMenu == nil do
        local event, a, b, c, d, e, f = os.pullEvent()
        if event == "mouse_click" then
            local button, x, y = a, b, c
            if y == 1 then
                if x <= 6 then
                    menuButtons[1][1]()
                elseif x >= termWidth/2 - 6 and x <= termWidth/2 + 6 then
                    menuButtons[1][2]()
                elseif x >= termWidth - 6 then
                    menuButtons[1][3]()
                end
            elseif popUp ~= nil then
                local pw = popUp.getWidth()
                local ph = popUp.getHeight()
                local px = (termWidth - pw) / 2
                local py = (termHeight - ph) / 2
                if y == py + ph - 2 then
                    local offs = px + 2
                    for i, button in ipairs(popUp.buttons) do
                        if x >= offs and x < offs + #button.label + 2 then
                            button.click()
                        end
                        offs = offs + #button.label + 3
                    end
                end
            elseif y == 2 then
                menuButtonSelected = {2, math.max(math.min(x - 4, #composedMessage.subject + 1), 1)}
            elseif y == 3 then
                if type(composedMessage.recipient) == "string" then
                    menuButtonSelected = {3, math.max(math.min(x - 4, #composedMessage.recipient + 1), 1)}
                else
                    menuButtonSelected = {3, math.max(math.min(x - 4, #nameOrID(composedMessage.recipient) + 1), 1)}
                end
            elseif y >= 5 and y < termHeight then
                menuButtonSelected[1] = math.min(y - 1 + scroll, #composedMessage.lines + 3)
                menuButtonSelected[2] = math.max(math.min(x - 1, #composedMessage.lines[menuButtonSelected[1]-3] + 1), 1)
            end
            composeDmail()
        elseif event == "mouse_scroll" then
            local dir = a
            if menuButtonSelected[1] == 1 then
                menuButtonSelected = {0, 0}
            end
            scroll = clampScrollInCompose(scroll + dir)
            composeDmail()
        elseif event == "key" then
            local key = a
            if popUp ~= nil then
                if key == keys.left then
                    menuButtonSelected[2] = (menuButtonSelected[2] - 2) % #popUp.buttons + 1
                elseif key == keys.right then
                    menuButtonSelected[2] = (menuButtonSelected[2]) % #popUp.buttons + 1
                elseif key == keys.enter then
                    popUp.buttons[menuButtonSelected[2]].click()
                end
            else
                local rows = #composedMessage.lines + 3
                local columnCount = 1
                if key == keys.up then
                    menuButtonSelected[1] = (menuButtonSelected[1] - 2) % rows + 1
                elseif key == keys.down then
                    menuButtonSelected[1] = (menuButtonSelected[1]) % rows + 1
                end
                if menuButtonSelected[1] == 1 then
                    columnCount = 3
                    menuButtonSelected[2] = math.min(menuButtonSelected[2], columnCount)
                    if key == keys.right then
                        menuButtonSelected[2] = (menuButtonSelected[2]) % columnCount + 1
                    elseif key == keys.left then
                        menuButtonSelected[2] = (menuButtonSelected[2] - 2) % columnCount + 1
                    elseif key == keys.enter then
                        menuButtons[1][menuButtonSelected[2]]()
                    end
                elseif menuButtonSelected[1] == 2 then
                    columnCount = #composedMessage.subject + 1
                    menuButtonSelected[2] = math.min(menuButtonSelected[2], columnCount)
                    if key == keys.right then
                        menuButtonSelected[2] = math.min(menuButtonSelected[2] + 1, columnCount)
                    elseif key == keys.left then
                        menuButtonSelected[2] = math.max(menuButtonSelected[2] - 1, 1)
                    elseif key == keys.enter then
                        menuButtonSelected[1] = 3
                        if type(composedMessage.recipient) == "string" then
                            menuButtonSelected[2] = #composedMessage.recipient
                        else
                            menuButtonSelected[2] = #nameOrID(composedMessage.recipient)
                        end
                    elseif key == keys.backspace then
                        if menuButtonSelected[2] > 1 then
                            composedMessage.subject = string.sub(composedMessage.subject, 1, menuButtonSelected[2] - 2) .. string.sub(composedMessage.subject, menuButtonSelected[2])
                        end
                    elseif key == keys.delete then
                        if menuButtonSelected[2] <= #composedMessage.subject then
                            composedMessage.subject = string.sub(composedMessage.subject, 1, menuButtonSelected[2] - 1) .. string.sub(composedMessage.subject, menuButtonSelected[2] + 1)
                        end
                    end
                elseif menuButtonSelected[1] == 3 then
                    local str = #composedMessage.recipient
                    if type(str) == "number" then
                        str = tostring(nameOrID(composedMessage.recipient))
                    end
                    columnCount = #str + 1
                    menumenuButtonSelected[2] = math.min(menuButtonSelected[2], columnCount)
                    if key == keys.right then
                        menuButtonSelected[2] = math.min(menuButtonSelected[2] + 1, columnCount)
                    elseif key == keys.left then
                        menuButtonSelected[2] = math.max(menuButtonSelected[2] - 1, 1)
                    elseif key == keys.enter then
                        menuButtonSelected[1] = 4
                        menuButtonSelected[2] = math.min(menuButtonSelected[2] + 3, #composedMessage.lines[1] + 1)
                    elseif key == keys.backspace then
                        if menuButtonSelected[2] > 1 then
                            composedMessage.recipient = string.sub(composedMessage.recipient, 1, menuButtonSelected[2] - 2) .. string.sub(composedMessage.recipient, menuButtonSelected[2])
                        end
                    elseif key == keys.delete then
                        if menuButtonSelected[2] <= #composedMessage.recipient then
                            composedMessage.recipient = string.sub(composedMessage.recipient, 1, menuButtonSelected[2] - 1) .. string.sub(composedMessage.recipient, menuButtonSelected[2] + 1)
                        end
                    end
                elseif menuButtonSelected[1] >= 4 then
                    columnCount = #composedMessage.lines[menuButtonSelected[1]-3] + 1
                    menuButtonSelected[2] = math.min(menuButtonSelected[2], columnCount)
                    if key == keys.right then
                        menuButtonSelected[2] = menuButtonSelected[2] + 1
                        if menuButtonSelected[2] > columnCount then
                            if menuButtonSelected[1] - 3 < #composedMessage.lines then
                                menuButtonSelected[1] = menuButtonSelected[1] + 1
                                menuButtonSelected[2] = 1
                            else
                                menuButtonSelected[2] = columnCount
                            end
                        end
                    elseif key == keys.left then
                        menuButtonSelected[2] = menuButtonSelected[2] - 1
                        if menuButtonSelected[2] < 1 then
                            if menuButtonSelected[1] - 3 > 1 then
                                menuButtonSelected[1] = menuButtonSelected[1] - 1
                                menuButtonSelected[2] = #composedMessage.lines[menuButtonSelected[1]-3] + 1
                            else
                                menuButtonSelected[2] = 1
                            end
                        end
                    elseif key == keys.enter then
                        local index = getBodyPosInLine(composedMessage.body, termWidth - 1, menuButtonSelected[1] - 3, menuButtonSelected[2])
                        composedMessage.body = string.sub(composedMessage.body, 1, index - 1) .. "\n" .. string.sub(composedMessage.body, index)
                        composedMessage.lines = getLines(composedMessage.body, termWidth - 1)
                        menuButtonSelected[1], menuButtonSelected[2] = getLinePosInBody(composedMessage.body, termWidth - 1, index + 1)
                        menuButtonSelected[1] = menuButtonSelected[1] + 3
                    elseif key == keys.backspace then
                        local index = getBodyPosInLine(composedMessage.body, termWidth - 1, menuButtonSelected[1] - 3, menuButtonSelected[2])
                        if index > 1 then
                            composedMessage.body = string.sub(composedMessage.body, 1, index - 2) .. string.sub(composedMessage.body, index)
                            composedMessage.lines = getLines(composedMessage.body, termWidth - 1)
                            menuButtonSelected[1], menuButtonSelected[2] = getLinePosInBody(composedMessage.body, termWidth - 1, index + 1)
                            menuButtonSelected[1] = menuButtonSelected[1] + 3
                        end
                    elseif key == keys.delete then
                        local index = getBodyPosInLine(composedMessage.body, termWidth - 1, menuButtonSelected[1] - 3, menuButtonSelected[2])
                        if index <= #composedMessage.body then
                            composedMessage.body = string.sub(composedMessage.body, 1, index - 1) .. string.sub(composedMessage.body, index + 1)
                            composedMessage.lines = getLines(composedMessage.body, termWidth - 1)
                            menuButtonSelected[1], menuButtonSelected[2] = getLinePosInBody(composedMessage.body, termWidth - 1, index + 1)
                            menuButtonSelected[1] = menuButtonSelected[1] + 3
                        end
                    end
                end
            end
            composeDmail()
        elseif event == "char" then
            local char = a
            if menuButtonSelected[1] == 2 then
                composedMessage.subject = string.sub(composedMessage.subject, 1, menuButtonSelected[2] - 1) .. char .. string.sub(composedMessage.subject, menuButtonSelected[2])
                menuButtonSelected[2] = menuButtonSelected[2] + 1
            elseif menuButtonSelected[1] == 3 then
                if type(composedMessage.recipient) == "string" then
                    composedMessage.recipient = nameOrID(composedMessage.recipient)
                end
                composedMessage.recipient = string.sub(composedMessage.recipient, 1, menuButtonSelected[2] - 1) .. char .. string.sub(composedMessage.recipient, menuButtonSelected[2])
                menuButtonSelected[2] = menuButtonSelected[2] + 1
            elseif menuButtonSelected[1] > 3 and menuButtonSelected[1] - 4 <= #composedMessage.lines then
                local index = getBodyPosInLine(composedMessage.body, termWidth - 1, menuButtonSelected[1] - 3, menuButtonSelected[2])
                composedMessage.body = string.sub(composedMessage.body, 1, index - 1) .. char .. string.sub(composedMessage.body, index)
                composedMessage.lines = getLines(composedMessage.body, termWidth - 1)
                menuButtonSelected[1], menuButtonSelected[2] = getLinePosInBody(composedMessage.body, termWidth - 1, index + 1)
                menuButtonSelected[1] = menuButtonSelected[1] + 3
            end
            composeDmail()
        end
    end
    return nextMenu
end

local nextMenu = dmailListMenu

while not exited and nextMenu ~= nil do
    nextMenu = nextMenu()
end

term.redirect(parentTerm)
term.clear()
term.setCursorPos(1, 1)
