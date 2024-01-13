---@type Plugin
local plugin = ...
plugin.name = "Radio"
plugin.author = "gart"
plugin.description = "Just makes a little radio"

local sound = plugin:require("sound")
local json  = require "main.json"

---@type Player?
local bot
---@type Item?
local radio

-- ptero sftp details
local sftpDetails = {
    host = "SFTPHOST",
    port = 2022,
    serverId = "xxxxxxx",
    username = "username",
    password = "password",
}

function request(query, creds, cb)
    local host = "http://node1.gart.sh:3300"
    local path = "/request"
    
    http.post(host, path, {}, json.encode({
        query = query,
        creds = creds,
    }), "application/json", function (response)
        
        print("status: " .. response.status)
        if (response.status == 200) then
            local data = json.decode(response.body)
            cb(data)
        else
            cb({
                error = "Something went wrong",
                videoId = nil,
            })
        end
    end) 
end

plugin.commands["/search"] = {
    info = "Search for a song",
    usage = "/search <query>",
    call = function (ply, man, args) 

        local query = table.concat(args, " ")
        request(query, sftpDetails, function (data)

            local id = data.videoId

            if (id == nil) then
                messagePlayerWrap(ply, "No results found for " .. query)
                return
            end

            local audioPath = "./plugins/radio/audio/" .. id .. ".pcm"
        
            print("playing " .. audioPath)

            local item = items.create(itemTypes.getByName("Box"), ply.human.pos:clone(), orientations.n)

            local bot = players.createBot()
            bot.data.isSpeaker = true
            sound.speaker.reset()
            sound.item(audioPath, 0.5, 1, {}, "self", item, 1000)

            events.createMessage(2, "Playing " .. data.title, item.index, 1)
            events.createMessage(2, "By " .. data.author.name, item.index, 1)
            events.createMessage(2, "Requested by " .. ply.name, item.index, 1)
         
        end)

    end
}
