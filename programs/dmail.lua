local dmail = require("/programs/api/dmail")
local yaml = require("/programs/api/yaml")

local exited = false

local termWidth, termHeight = term.getSize()

local messageList = window.create(term.current(), 1, 3, termWidth, termHeight - 3)
local messageBody = window.create(term.current(), 1, 4, termWidth, termHeight - 4)

local status = {}
local messages = {}

local scroll = 0

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
    return false
end

local function loadMessages()
    status = {}
    messages = dmail.fetchLocal()
    for i, server in pairs(config.servers) do
        local s, m = dmail.fetch(server)
        status[#status + 1] = s
        for j, message in pairs(m) do
            message.read = isMessageRead(message.id)
            messages[#messages + 1] = message
        end
    end

    table.sort(messages, function(a, b) return a.id > b.id end)
end

local function displayDmailList()
    shell.run("clear")
    
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
            messageList.write(
                ("%s %s %s"):format(
                    "o",
                    string.sub(nameOrID(message.sender) .. "      ", 1, 6),
                    message.subject
                ))
        end
    end
end

loadMessages()
displayDmailList()

while not exited do
    local event, a, b, c, d, e, f = os.pullEvent()
    term.setCursorPos(1, 1)
    term.write(event .. "               ")
    if event == "mouse_click" then
        local button, x, y = a, b, c
        if y > 3 and y <= #messages + 3 then
            messages[y-3].read = true
        end
        displayDmailList()
    elseif event == "mouse_scroll" then
        local dir = a
        scroll = scroll + dir
        displayDmailList()
    end
end
