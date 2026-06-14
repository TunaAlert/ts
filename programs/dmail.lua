local dmail = require("/programs/api/dmail")
local yaml = require("/programs/api/yaml")

local exited = false

local termWidth, termHeight = term.getSize()

local messageList = window.create(term.current(), 1, 3, termWidth, termHeight - 3)
local messageBody = window.create(term.current(), 1, 4, termWidth, termHeight - 4)
local parentTerm = term.current()

local status = {}
local messages = {}
local readMessages = yaml.load("./data/dmail/read.yaml")
if readMessages ~= nil and readMessages.read ~= nil then
    readMessages = readMessages.read
else
    readMessages = {}
end

local scroll = 0
local selectedDmail = 0

local dmailListMenu
local dmailDisplayMenu

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
    readMessages[#readMessages] = messageId
    yaml.save({read = readMessages}, "./data/dmail/read.yaml")
end

local function loadMessages()
    status = {}
    messages = dmail.fetchLocal()
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

local function displayDmailList()
    messageList.setVisible(true)
    messageBody.setVisible(false)

    term.setRedirect(parentTerm)
    term.setBackgroundColor(colors.black)
    term.clear()
    term.setRedirect(messageList)
    
    messageList.setBackgroundColor(colors.black)
    messageList.clear()
    
    local offset = 0
    
    for i, s in ipairs(status) do
        if s ~= dmail.SUCCESS then
            messageList.setCursorPos(1, 1+offset)
            messageList.setTextColor(colors.red)
            messageList.write(("error status %d"):format(s))
            offset = offset + 1
        end
    end
    if #messages == 0 then
        messageList.setCursorPos(termWidth/2 - 5, 1 + offset)
        messageList.setTextColor(colors.gray)
        messageList.write("No messages")
    end
    for i, message in ipairs(messages) do
        if i - scroll >= 1 and i - scroll <= termHeight - 3 then
            messageList.setCursorPos(1, i-scroll + offset)
            if message.read then
                messageList.setTextColor(colors.lightGray)
            else
                messageList.setTextColor(colors.white)
            end
            local bullet = "o"
            if message.selected then
                bullet = "\xf8"
            end
            if selectedDmail == i then
                messageList.setBackgroundColor(colors.gray)
            else
                messageList.setBackgroundColor(colors.black)
            end
            messageList.clearLine()
            messageList.write(
                ("%s %s %s"):format(
                    bullet,
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

    term.redirect(parentTerm)
    term.setBackgroundColor(colors.black)
    term.clear()
    term.setCursorPos(1, 1)
    term.setTextColor(colors.black)
    term.setBackgroundColor(colors.lightGray)
    term.clearLine()
    term.write(message.subject)
    term.setTextColor(colors.green)
    term.setCursorPos(1, 2)
    term.clearLine()
    term.write("  From: " .. message.sender)
    
    term.redirect(messageBody)

    messageBody.setTextColor(colors.white)
    messageBody.setBackgroundColor(colors.black)
    messageBody.clear()
    messageBody.scroll(scroll)
    messageBody.setCursorPos(1, 1)
    write(message.body .. "\n\n")
    messageBody.setTextColor(colors.yellow)
    for i, attachment in pairs(message.attachments) do
        messageBody.write("  + " .. attachment .. "\n")
    end
end

local function clampScrollInList(value)
    return math.max(math.min(value, #messages - ({messageList.getSize()})[2]), 0)
end

dmailListMenu = function()
    scroll = 0
    
    loadMessages()
    displayDmailList()

    local nextMenu = nil
    while not exited and nextMenu == nil do
        local event, a, b, c, d, e, f = os.pullEvent()
        if event == "mouse_click" then
            local button, x, y = a, b, c
            local yoffs = ({messageList.getPosition()})[2]
            local clickedLine = y-yoffs+scroll
            if clickedLine > 0 and clickedLine <= #messages then
                if x < 3 then
                    messages[clickedLine].selected = not messages[clickedLine].selected
                elseif x < 10 then
                else
                    selectedDmail = clickedLine
                    nextMenu = dmailDisplayMenu
                    setMessageRead(messages[clickedLine].id)
                end
            end
            displayDmailList()
        elseif event == "mouse_scroll" then
            local dir = a
            scroll = clampScrollInList(scroll + dir)
            displayDmailList()
        elseif event == "key" then
            local key = keys.getName(a)
            if key == "down" then
                scroll = clampScrollInList(scroll - 1)
                displayDmailList()
            elseif key == "up" then
                scroll = clampScrollInList(scroll + 1)
                displayDmailList()
            end
        end
    end
    return nextMenu
end

dmailDisplayMenu = function()
    scroll = 0

    displayDmail()
    
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
