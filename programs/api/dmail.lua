local ftp = require("/programs/api/ftp")

local function send(server, recipient, subject, body, attachments)
    local mail_id = ("%s %d %d"):format(os.getComputerID(), recipient, os.date("%Y-%m-%d %H-%M-%S"))
    local mailFile = ("/.data/dmail/outbox/%s.mail"):format(mail_id)
    local handle = io.open(mailFile)
    handle:write(("sender:%d\n"):format(os.getComputerID()))
    handle:write(("subject:%s\n"):format(subject))
    for i, attachment in attachments do
        handle:write(("attachment:%s\n"):format(fs.getName(attachment)))
    end
    handle:write("body\n" .. body)
    handle:close()

    local status = {}
    
    status[#status + 1] = ftp.push(server, mailFile, ("%d/inbox/%s.mail"):format(recipient, mail_id))
    for i, attachment in attachments do
        status[#status + 1] = ftp.push(server, attachment, ("%d/attachments/%s/%s"):format(recipient, mail_id, fs.getName(attachment)))
    end
    return status
end

local function openMail(server, mail)
    local mailFile = ("/.data/dmail/inbox/%s.mail"):format(mail)
    if not fs.exists(mailFile) then
        if server > 0 then
            local remoteFile = ("%d/inbox/%s.mail"):format(os.getComputerID(), mail)
            local status = ftp.pull(server, remoteFile, mailFile)
            if status ~= ftp.SUCCESS then
                return status
            end
            ftp.delete(server, remoteFile)
        else
            return ftp.ACCESS_DENIED
        end
    end
    
    local message = {
        sender = 0,
        subject = "",
        attachments = {},
        body = ""
        }
    
    local inBody = false
    for line in io.lines(mailFile) do
        if inBody then
            if #message.body > 0 then
            	message.body = message.body .. "\n" .. line
            else
                message.body = line
            end
        else
            local key = string.match(line, "^%w+") or ""
            local value = string.sub(line, #key+2)
            if key == "sender" then
                message.sender = tonumber(value)
            elseif key == "subject" then
                message.subject = value
            elseif key == "attachment" then
                message.attachments[#message.attachments + 1] = value
            elseif key == "body" then
                inBody = true
            end
        end
    end

    for i, attachment in pairs(message.attachments) do
        local attachmentFile = ("/.data/dmail/attachments/%s/%s"):format(mail, attachment)
        if not fs.exists(attachmentFile) then
            local remoteFile = ("%d/attachments/%s/%s"):format(os.getComputerID(), mail, attachment)
            if not fs.exists(mailFile) then
                local status = ftp.pull(server, remoteFile, attachmentFile)
                if status == ftp.SUCCESS then
                    ftp.delete(server, remoteFile)
                end
            end
        end
    end
    
    return ftp.SUCCESS, message
end

local function fetchLocal()
    local messageFiles = {}
    local localInbox = fs.list("/.data/dmail/inbox")
    for i, localMessage in pairs(localInbox) do
        messageFiles[#messageFiles + 1] = string.sub(localMessage, 1, #localMessage)
    end
    local messages = {}
    for i, messageFile in pairs(messageFiles) do
        local stat, message = openMail(0, string.sub(messageFile, 1, #messageFile - 5))
        if stat == ftp.SUCCESS then
            messages[#messages+1] = message
        end
    end
    return status, messages
end

local function fetch(server)
    local status, messageFiles = ftp.list(server, ("%d/inbox/"):format(os.getComputerID()))
    if status ~= ftp.SUCCESS then
        messageFiles = {}
    end
    local messages = {}
    for i, messageFile in pairs(messageFiles) do
        local stat, message = openMail(server, string.sub(messageFile, 1, #messageFile - 5))
        if stat == ftp.SUCCESS then
            messages[#messages+1] = message
        end
    end
    return status, messages
end

return {
    send = send,
    fetch = fetch,
    fetchLocal = fetchLocal,
    openMail = openMail,
    SUCCESS = ftp.SUCCESS,
    UNKNOWN_RESPONSE = ftp.UNKNOWN_RESPONSE,
    NO_RESPONSE = ftp.NO_RESPONSE,
    ACCESS_DENIED = ftp.ACCESS_DENIED
    }
