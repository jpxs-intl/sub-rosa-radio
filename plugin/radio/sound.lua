local plugin = ...

local DEFAULT_SAMPLE_RATE = 48000
local OPUS_FRAME_LENGTH = 0.02
local INT16_DIFF = 65535
local INT16_MIN = -32768
local INT16_MAX = 32767
local FRAME_SECOND = 50
local EMPTY = {}

local random = _G.math.random
local tonumber = _G.tonumber
local tostring = _G.tostring
local floor = _G.math.floor
local char = _G.string.char
local byte = _G.string.byte
local ipairs = _G.ipairs
local assert = _G.assert
local sin = _G.math.sin
local min = _G.math.min
local pairs = _G.pairs
local print = _G.print
local type = _G.type

local PI = _G.math.pi
local TAU = 2 * PI
local INTERVAL = TAU / DEFAULT_SAMPLE_RATE

local opusEncoder = _G.OpusEncoder.new()

local SILENCE_FRAME = char(0x78, 0xEF, 0x79, 0xEF, 0x41, 0x67, 0xEF, 0xEF, 0xEF, 0x4C, 0xEF)

local function round(num)
	return floor(num + 0.5)
end

local function tonumber_s16le(value)
	local x = (value:sub(2, 2):byte() * 256) + value:sub(1, 1):byte()
	if x < 32768 then
		return x
	else
		return x - 65536
	end
end

local function tostring_s16le(value)
	if value < 0 then
		value = value + 65536
	end
	return char(value % 256, floor(value / 256))
end

local module = {
	["next"] = 0,
	["speaker"] = {
		["next"] = 0,
		["count"] = 1,
		["buffer"] = {
		--	"./plugins/sound/gob.pcm",
		--	"./plugins/sound/guy.pcm",
		},
	},
	["wave"] = {
		["encoder"] = {
			["sine"] = function(self)
				self.index = self.index + 1
				--print(self.index, self.length);
				if self.index <= self.length then
					local frame = ""
					local start = self.start
					for i = 1, 960 do
						local rad = start
						local rad = 0.5 + (math.sin(rad * self.frequency) * 0.5)
						local n = INT16_MIN + math.floor(self.amplitude * INT16_DIFF * rad)
						--print(n);
						frame = frame .. tostring_s16le(n)
						start = start + INTERVAL
					end
					self.start = start
					return opusEncoder:encodeFrame(frame)
				end
			end,
			["square"] = function(self)
				self.index = self.index + 1
				if self.index <= self.length then
					local frame = ""
					local start = self.start
					local div = self.frequency / 2
					local max = INT16_MAX * self.amplitude
					local min = INT16_MIN * self.amplitude
					for i = 1, 960 do
						local n = start % self.frequency
						if n < div then
							--print(n, max);
							frame = frame .. tostring_s16le(max)
						else
							--print(n, min);
							frame = frame .. tostring_s16le(min)
						end
						start = start + INTERVAL
					end
					self.start = start
					return opusEncoder:encodeFrame(frame)
				end
			end,
		},
	},
	["calculateEarShots"] = {},
}

function module.encodeFile(path, encoder)
	encoder:open(path)
	local content = ""
	local frame = encoder:encodeFrame()
	while frame ~= nil do
		content = content .. char(#frame) .. frame
		frame = encoder:encodeFrame()
	end
	encoder:close()
	return content
end

function module.speaker.reset()
	print("Speakers reset")
	---- BOT RESET
	for i, bot in ipairs(players.getBots()) do
		if bot.data.isSpeaker then
			bot:remove()
		end
	end
	for i = 0, module.speaker.count - 1 do
		local speaker = players.createBot()
		speaker.data.isSpeaker = i
		speaker.data.opusPlayer = {
			["id"] = nil,
			["mode"] = nil,
			["path"] = nil,
			["start"] = nil,
			["media"] = nil,
			["queue"] = {},
			["replay"] = 0,
			["frames"] = {
				["path"] = nil,
				["file"] = nil,
				["open"] = function(self, path)
					self.path = path
					self.file = io.open(path, "r")
				end,
				["encodeFrame"] = function(self)
					return self.file:read("*l")
				end,
				["close"] = function(self)
					self.path = nil
					self.file:close()
				end,
				["rewind"] = function(self)
					self.file:close()
					self.file = io.open(self.path, "r")
				end,
			},
			["buffer"] = {
				["index"] = 0,
				["path"] = nil,
				["open"] = function(self, path)
					self.path = path
					self.index = 0
				end,
				["encodeFrame"] = function(self)
					self.index = self.index + 1
					return module.speaker.buffer[self.path][self.index]
				end,
				["close"] = function(self)
					self.path = nil
					self.index = 0
				end,
				["rewind"] = function(self)
					self.index = 0
				end,
			},
			["wave"] = {
				["name"] = nil,
				["index"] = 0,
				["start"] = 0,
				["length"] = 0,
				["frequency"] = 440,
				["amplitude"] = 1,
				["open"] = function(self, data)
					if type(data) ~= "table" then
						return
					end
					if data.type ~= "wave" then
						return
					end
					local name = data.name
					if module.wave.encoder[name] then
						self.name = data.name
						self.index = 0
						self.start = 0
						self.length = data.length
						self.frequency = math.min(24000, data.frequency)
						self.amplitude = data.amplitude
						self.encodeFrame = module.wave.encoder[name]
					end
				end,
				["close"] = function(self)
					self.name = nil
					self.index = 0
					self.start = 0
					self.length = 0
					self.frequency = 440
					self.encodeFrame = nil
				end,
				["rewind"] = function(self)
					self.index = 0
				end,
			},
			["source"] = nil,
			["override"] = nil,
			["rangeSquare"] = 65536,
			["currentFrame"] = 32,
		}
		speaker.voice.volumeLevel = 1
		for j = 0, 63 do
			speaker.data.opusPlayer.queue[j] = SILENCE_FRAME
		end
		speaker.voice.isSilenced = true
		speaker.voice.currentFrame = 32
		speaker.data.opusPlayer.currentFrame = 32
		module.speaker[i] = speaker
		print(speaker.data.opusPlayer, speaker.index)
	end
	---- BUFFER RESET
	for i, path in ipairs(module.speaker.buffer) do
		local buffer = {}
		local index = 0
		if path:sub(-4, -1) == ".pcm" then
			opusEncoder:open(path)
			repeat
				index = index + 1
				buffer[index] = opusEncoder:encodeFrame()
			until buffer[index] == nil
			opusEncoder:close()
		elseif path:sub(-7, -1) == ".frames" then
			local file = io.open(path, "r")
			index = 1
			local bytes = file:read(1)
			while bytes ~= nil do
				buffer[index] = file:read(byte(bytes))
				bytes = file:read(1)
				index = index + 1
			end
			file:close()
		end
	end
end

function module.speaker.get(listeners, volume)
	print("Get speakers")
	local next = (module.speaker.next + 1) % module.speaker.count
	module.speaker.next = next
	local speaker
	for i, bot in ipairs(players.getBots()) do
		print(bot.index, bot.data.isSpeaker)
		if bot.data.isSpeaker == next then
			speaker = bot
			break
		end
	end
	speaker.voice.isSilenced = false
	speaker.voice.volumeLevel = volume
	if #listeners > 0 then
		speaker.data.opusPlayer.id = module.next
		for i, player in ipairs(listeners) do
			if player.data.opusListener == nil then
				player.data.opusListener = {}
			end
			player.data.opusListener[module.next] = true
		end
	end
	module.next = module.next + 1
	return speaker
end

function module.speaker.updateMedia(speaker, path)
	if type(path) == "string" then
		if module.speaker.buffer[path] then
			speaker.data.opusPlayer.buffer:open(path)
			speaker.data.opusPlayer.media = speaker.data.opusPlayer.buffer
		elseif path:sub(-4, -1) == ".pcm" then
			if speaker.data.opusPlayer.encoder == nil then
				speaker.data.opusPlayer.encoder = OpusEncoder.new()
			end
			speaker.data.opusPlayer.encoder:open(path)
			speaker.data.opusPlayer.media = speaker.data.opusPlayer.encoder
		elseif path:sub(-7, -1) == ".frames" then
			speaker.data.opusPlayer.frames:open(path)
			speaker.data.opusPlayer.media = speaker.data.opusPlayer.frames
		end
	else
		if path.type == "wave" then
			speaker.data.opusPlayer.wave:open(path)
			speaker.data.opusPlayer.media = speaker.data.opusPlayer.wave
		end
	end
end

function module.speaker.assertListener(connection, player, listener, speaker, source)
	local rangeSquare = speaker.data.opusPlayer.rangeSquare
	if rangeSquare ~= nil and listener ~= nil and source ~= nil then
		if listener:getRigidBody(3).pos:distSquare(source.pos) > rangeSquare then
			return false
		end
	end
	local id = speaker.data.opusPlayer.id
	if id ~= nil then
		if player.data.opusListener == nil then
			return false
		end
		return player.data.opusListener[id]
	end
	return true
end

function module.speaker.setFrame(speaker)
	local clock = os.realClock()
	if speaker.data.opusPlayer.start == nil then
		speaker.data.opusPlayer.start = clock
	end
	local next = floor((clock - speaker.data.opusPlayer.start) * FRAME_SECOND) % 64
	if next ~= speaker.data.opusPlayer.currentFrame then
		local frame = speaker.data.opusPlayer.media:encodeFrame()
		if frame == nil then
			speaker.data.opusPlayer.replay = speaker.data.opusPlayer.replay - 1
			if speaker.data.opusPlayer.replay >= 0 then
				speaker.data.opusPlayer.media:rewind()
				frame = speaker.data.opusPlayer.media:encodeFrame()
			else
				if speaker.data.opusPlayer.source ~= nil then
					if speaker.data.opusPlayer.source.data.isSoundSource then
						speaker.data.opusPlayer.source:remove()
					end
					speaker.data.opusPlayer.source = nil
				end
				speaker.data.opusPlayer.id = nil
				speaker.data.opusPlayer.start = nil
				speaker.data.opusPlayer.media:close()
				speaker.voice.volumeLevel = 1
				for i = 0, 63 do
					speaker.data.opusPlayer.queue[i] = SILENCE_FRAME
				end
				speaker.voice.isSilenced = true
				speaker.data.opusPlayer.currentFrame = 32
			end
		end
		if frame ~= nil then
			speaker.data.opusPlayer.queue[next] = frame
			speaker.data.opusPlayer.currentFrame = next
		end
	end
end

function module.speaker.findEarShot(connection, player, listener, speaker, source)
	---- Look for any inactive slots
	for i = 0, 7 do
		local earShot = connection:getEarShot(i)
		if not earShot.isActive or earShot.player == speaker then
			return i
		end
	end
	---- Look for slots with override 'self' and equal path
	local time = os.realClock()
	local timeSelf = speaker.data.opusPlayer.start or time
	local timeAny = speaker.data.opusPlayer.start or time
	local replaceSelf = -1
	local replaceAny = -1
	for i = 0, 7 do
		local earShot = connection:getEarShot(i)
		if earShot.player.data.opusPlayer ~= nil then
			local override = earShot.player.data.opusPlayer.override
			if override ~= nil then
				local start = earShot.player.data.opusPlayer.start or time
				if
					override == "self"
					and earShot.player.data.opusPlayer.path == speaker.data.opusPlayer.path
					and start < timeSelf
				then
					timeSelf = start
					replaceSelf = i
				elseif override == "any" and start < timeAny then
					timeAny = start
					replaceAny = i
				end
			end
		end
	end
	if replaceSelf >= 0 then
		return replaceSelf
	elseif replaceAny >= 0 then
		return replaceAny
	end
end

function module.wave.set(name, frequency, amplitude, length)
	return {
		["type"] = "wave",
		["name"] = name,
		["frequency"] = frequency,
		["amplitude"] = amplitude,
		["length"] = length,
	}
end

function module.calculateEarShots.global(connection, player, listener, speaker, source)
	local slot = module.speaker.findEarShot(connection, player, listener, speaker, source)
	if slot == nil then
		return
	end
	local earShot = connection:getEarShot(slot)
	earShot.player = speaker
	earShot.human = listener
	earShot.receivingItem = nil
	earShot.isActive = true
end

function module.calculateEarShots.human(connection, player, listener, speaker, source)
	local slot = module.speaker.findEarShot(connection, player, listener, speaker, source)
	if slot == nil then
		return
	end
	local earShot = connection:getEarShot(slot)
	earShot.player = speaker
	earShot.human = source
	earShot.receivingItem = nil
	earShot.isActive = true
end

function module.calculateEarShots.item(connection, player, listener, speaker, source)
	local slot = module.speaker.findEarShot(connection, player, listener, speaker, source)
	if slot == nil then
		return
	end
	local earShot = connection:getEarShot(slot)
	earShot.player = speaker
	earShot.human = nil
	earShot.receivingItem = source
	earShot.isActive = true
end

function module.earShotCalculation()
	for i, player in ipairs(players.getNonBots()) do
		local connection = player.connection
		if connection ~= nil then
			hook.run("CalculateEarShots", connection, player)
			hook.run("PostCalculateEarShots", connection, player)
			--local listener = player.human or connection.spectatingHuman;
			--if listener ~= nil then
			--    for j, bot in ipairs(players.getBots()) do
			--        if bot.data.isSpeaker and not bot.voice.isSilenced then
			--            if
			--                module.speaker.assertListener(
			--                    connection, player, listener, bot, bot.data.opusPlayer.source
			--                )
			--            then
			--                for k, frame in pairs(bot.data.opusPlayer.queue) do
			--                    bot.voice:setFrame(k, frame, bot.voice.volumeLevel);
			--                    bot.data.opusPlayer.queue[k] = nil;
			--                end
			--                bot.voice.currentFrame = bot.data.opusPlayer.currentFrame;
			--                module.calculateEarShots[bot.data.opusPlayer.mode](
			--                    connection, player, listener, bot, bot.data.opusPlayer.source
			--                );
			--            end
			--        end
			--    end
			--end
		end
	end
end

function module.global(path, volume, replay, listeners, override)
	local speaker = module.speaker.get(listeners, volume)
	speaker.data.opusPlayer.mode = "global"
	speaker.data.opusPlayer.path = path
	speaker.data.opusPlayer.start = nil
	speaker.data.opusPlayer.replay = replay
	speaker.data.opusPlayer.source = nil
	speaker.data.opusPlayer.override = override
	speaker.data.opusPlayer.rangeSquare = nil
	module.speaker.updateMedia(speaker, path)
	module.speaker.setFrame(speaker)
	module.earShotCalculation()
	return speaker
end

function module.human(path, volume, replay, listeners, override, human, rangeSquare)
	local speaker = module.speaker.get(listeners, volume)
	speaker.data.opusPlayer.mode = "human"
	speaker.data.opusPlayer.path = path
	speaker.data.opusPlayer.start = nil
	speaker.data.opusPlayer.replay = replay
	speaker.data.opusPlayer.source = human
	speaker.data.opusPlayer.override = override
	speaker.data.opusPlayer.rangeSquare = rangeSquare
	module.speaker.updateMedia(speaker, path)
	module.speaker.setFrame(speaker)
	return speaker, human
end

function module.item(path, volume, replay, listeners, override, item, rangeSquare)
	local speaker = module.speaker.get(listeners, volume)
	speaker.data.opusPlayer.mode = "item"
	speaker.data.opusPlayer.path = path
	speaker.data.opusPlayer.start = nil
	speaker.data.opusPlayer.replay = replay
	speaker.data.opusPlayer.source = item
	speaker.data.opusPlayer.override = override
	speaker.data.opusPlayer.rangeSquare = rangeSquare
	module.speaker.updateMedia(speaker, path)
	module.speaker.setFrame(speaker)
	module.earShotCalculation()
	return speaker, item
end

function module.at(path, volume, replay, listeners, override, pos, rangeSquare)
	local item = items.create(itemTypes[32], pos, orientations.n)
	item.rigidBody.isSettled = true
	item.data.isSoundSource = true
	item.hasPhysics = false
	item.isStatic = false
	local speaker = module.speaker.get(listeners, volume)
	speaker.data.opusPlayer.mode = "item"
	speaker.data.opusPlayer.path = path
	speaker.data.opusPlayer.start = nil
	speaker.data.opusPlayer.replay = replay
	speaker.data.opusPlayer.source = item
	speaker.data.opusPlayer.override = override
	speaker.data.opusPlayer.rangeSquare = rangeSquare
	module.speaker.updateMedia(speaker, path)
	module.speaker.setFrame(speaker)
	module.earShotCalculation()
	return speaker, item
end

	
	plugin:addHook("Logic", function()
		for i, bot in ipairs(players.getBots()) do
			if bot.data.opusPlayer ~= nil and not bot.voice.isSilenced then
				module.speaker.setFrame(bot)
			end
		end
	end)
	
	plugin:addHook("PostCalculateEarShots", function(connection, player)
		local listener = player.human or connection.spectatingHuman
		if listener ~= nil then
			for j, bot in ipairs(players.getBots()) do
				if bot.data.isSpeaker and not bot.voice.isSilenced then
					if module.speaker.assertListener(connection, player, listener, bot, bot.data.opusPlayer.source) then
						for k, frame in pairs(bot.data.opusPlayer.queue) do
							bot.voice:setFrame(k, frame, bot.voice.volumeLevel)
							bot.data.opusPlayer.queue[k] = nil
						end
						bot.voice.currentFrame = bot.data.opusPlayer.currentFrame
						module.calculateEarShots[bot.data.opusPlayer.mode](
							connection,
							player,
							listener,
							bot,
							bot.data.opusPlayer.source
						)
					end
				end
			end
		end
	end)
	
	plugin.commands["/frames"] = {
		["info"] = "Converts a .pcm file into encoded frames.",
		["canCall"] = function(player, human, args)
			return player.isConsole
		end,
		["call"] = function(player, human, args)
			local path = args[1]
			local file = io.open(path:sub(1, -5) .. ".frames", "w")
			file:write(module.encodeFile(path, opusEncoder))
			file:close()
			print("Success!")
		end,
	}
	
	plugin.commands["/wav"] = {
		["info"] = "Plays a wave.",
		["usage"] = "<string wave> <number frequency>",
		["canCall"] = function(player, human, args)
			return player.isConsole or player.isAdmin
		end,
		["call"] = function(player, human, args)
			assert(human, "Not spawned in.")
			local wave = tostring(args[1])
			assert(wave, "No wave type specified.")
			assert(module.wave.encoder[wave], "Invalid wave type.")
			local freq = tonumber(args[2])
			assert(freq, "Invalid frequency.")
			assert(freq < 24000, "Frequency must be <= 24kHz.")
			module.at(
				module.wave.set(wave, freq, 0.5, 4 * FRAME_SECOND),
				1,
				0,
				EMPTY,
				"self",
				human.pos + Vector(10, 10, 10),
				65536
			)
			print("Success!")
		end,
	}


return module
