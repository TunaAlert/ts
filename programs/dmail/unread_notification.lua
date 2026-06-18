local dmail = require("/programs/api/dmail")
local yaml = require("/programs/api/yaml")

local messages = {}
local readMessages = yaml.load("/.data/dmail/read.yaml")
if readMessages ~= nil and readMessages.read ~= nil then
    readMessages = readMessages.read
else
    readMessages = {}
end

local config = yaml.load("/.data/dmail/config.yaml")
if config == nil then
    config = {
        mainServer = 0,
        servers = {0},
        drawInvisibleCharacters = false,
        showImageAttachments = false,
        initialScreen = "list" -- list, compose, menu
        }
    yaml.save(config, "/.data/dmail/config.yaml")
end
config.servers[1] = config.mainServer

local function isMessageRead(messageId)
    for i, message in pairs(readMessages) do
        if message == messageId then
            return true
        end
    end
    return false
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

loadMessages()
local unread = unreadCount()
if unread == 1 then
  print("You have 1 unread message.")
elseif unread > 1 then
  print(("You have %d unread messages."):format(unread))
end
