-- Starts the lib
local discordia = require("discordia")
local client = discordia.Client({
	cacheAllMembers = true
})

-- Aux libs
local http_request = require("coro-http").request
local event = require("core").Emitter:new()
local timer = require("timer")
local base64_encode = require("base64").encode

-- Aux functions
local isAdmin = function(member)
	return member:getPermissions():has(discordia.enums.permission.administrator)
end

table.tostring = function(list, depth, stop)
	depth = depth or 1
	stop = stop or 0

	local out = { }
	
	for k, v in next, list do
		out[#out + 1] = string.rep("\t", depth) .. ("["..(type(k) == "number" and k or ("'" .. k .. "'")).."]") .. "="
		local t = type(v)
		if t == "table" then
			out[#out] = out[#out] .. ((stop > 0 and depth > stop) and tostring(v) or table.tostring(v, depth + 1, stop - 1))
		elseif t == "number" or t == "boolean" then
			out[#out] = out[#out] .. tostring(v)
		elseif t == "string" then
			out[#out] = out[#out] .. string.format("%q", v)
		else
			out[#out] = out[#out] .. "nil"
		end
	end
	
	return "{\n" .. table.concat(out, ",\n") .. "\n" .. string.rep("\t", depth - 1) .. "}"
end

local DEBUG = function(data, tag, str, ...)
	data.debug[#data.debug + 1] = string.format("[" .. tag .. "] " .. str, ...)
	data.action = data.action - 1

	if data.action > 0 then
		data.message:setContent("Backup will be finished in approximately " .. (data.action * 2) .. " seconds!")
	else
		timer.setTimeout(1500, coroutine.wrap(function(data)
			if not data or data.action > 0 then return end

			for k, v in next, data.cache.role do
				data.cache.role[k] = v.id
			end
			data.cache = table.tostring(data.cache)
			data.debug = table.concat(data.debug, "\n")

			local fileName = data.input.id .. "-" .. data.output.id

			data.message:setContent("The guild **" .. data.input.id .. "**-_" .. data.input.name .. "_ has been copied to the guild of id **" .. data.output.id .. "**.\n\tDuration: " .. (os.time() - data.time) .. " seconds.")
			data.message:reply({
				files = {
					{ "LOGS-" .. fileName .. ".log", data.debug },
					{ "TREE-" .. fileName .. ".lua", "-- [old_id] = \"new_id\"\n" .. data.cache },
				}
			})

			data.output:leave()
			data.input:leave()
			data = nil
		end), data)
	end
end

local build
do
	local triggerEvent = function(data)
		data.wraps = data.wraps - 1
		if data.wraps < 1 then
			data.stage = data.stage + 1
			event:emit(data.id, data)
		end
	end

	local sortGT = function(tbl)
		local arr = tbl:toArray()
		table.sort(arr, function(o1, o2)
			return o1.position > o2.position
		end)
		return arr
	end

	local sortLT = function(tbl)
		local arr = tbl:toArray()
		table.sort(arr, function(o1, o2)
			return o1.position < o2.position
		end)
		return arr
	end

	local delContent = function(data)
		data.wraps = 4

		-- Actions that the bot has to perform
		data.action = data.action +
			data.output.textChannels:count() +
			data.output.voiceChannels:count() +
			data.output.categories:count() +
			data.output.emojis:count() +
			data.output.roles:count()

		-- Deletes all channels
		coroutine.wrap(function(data)
			for channel in data.output.textChannels:iter() do
				channel:delete()
				DEBUG(data, "DEBUG", "Deleted text channel '%s-%s'", channel.name, channel.id)
			end
			for channel in data.output.voiceChannels:iter() do
				channel:delete()
				DEBUG(data, "DEBUG", "Deleted voice channel '%s-%s'", channel.name, channel.id)
			end

			triggerEvent(data)
		end)(data)
		-- Deletes all categories
		coroutine.wrap(function(data)
			for category in data.output.categories:iter() do
				category:delete()
				DEBUG(data, "DEBUG", "Deleted category '%s-%s'", category.name, category.id)
			end

			triggerEvent(data)
		end)(data)
		-- Deletes all emojis
		coroutine.wrap(function(data)
			for emoji in data.output.emojis:iter() do
				emoji:delete()
				DEBUG(data, "DEBUG", "Deleted emoji '%s-%s'", emoji.name, emoji.id)
			end

			triggerEvent(data)
		end)(data)
		-- Deletes all roles
		coroutine.wrap(function(data)
			for role in data.output.roles:iter() do
				role:delete()
				DEBUG(data, "DEBUG", "Deleted role '%s-%s'", role.name, role.id)
			end

			triggerEvent(data)
		end)(data)
	end

	local toImage = function(url)
		local tentative, head, body = 0
		repeat
			tentative = tentative + 1
			head, body = http_request("GET", url, nil, nil, 1500)
		until head.code == 200 or tentative >= 5
		if head.code ~= 200 then
			return ''
		end

		return "data:image/png;base64," .. base64_encode(body)
	end

	local mkEmojis = function(data)
		data.action = data.action + data.input.emojis:count()

		local newEmoji
		for emoji in data.input.emojis:iter() do
			newEmoji = data.output:createEmoji(emoji.name, toImage(emoji.url))
			if newEmoji then
				data.cache.emoji[emoji.id] = newEmoji.id
				DEBUG(data, "DEBUG", "Copied emoji '%s'-'%s' @ '%s'", newEmoji.hash, newEmoji.id, newEmoji.url)
			else
				DEBUG(data, "ERROR", "Could not copy the emoji '%s'-'%s' @ '%s'", emoji.hash, emoji.id, emoji.url)
			end
		end
	end

	local mkRoles = function(data)
		data.action = data.action + data.input.roles:count()
		local arr = sortGT(data.input.roles)

		local role, newRole
		for i = 1, #arr do
			role = arr[i]

			if role.position == 0 then -- skips @everyone
				data.cache.role[role.id] = data.output.defaultRole
				DEBUG(data, "DEBUG", "Copied default role")
			elseif not role.managed then -- skips BackupBot
				newRole = data.output:createRole(role.name)
				if newRole then
					data.cache.role[role.id] = newRole
					coroutine.wrap(function(role, newRole)
						newRole:disableAllPermissions()
						newRole:setPermissions(role:getPermissions())
						newRole:setColor(role.color)
						if role.mentionable then
							newRole:enableMentioning()
						end
						if role.hoisted then
							newRole:hoist()
						end
						DEBUG(data, "DEBUG", "Copied and configured the role '%s'-'%s'", newRole.name, newRole.id)
					end)(role, newRole)
				else
					DEBUG(data, "ERROR", "Could not copy the role '%s'-'%s'", role.name, role.id)
				end
			else
				DEBUG(data, "DEBUG", "Skipped the role '%s'-'%s'", role.name, role.id)
			end
		end

		triggerEvent(data)
	end

	local setPermissionOverwrite = function(data, input, output)
		data.action = data.action + input.permissionOverwrites:count()

		local raw, new, overwrite
		for perm in input.permissionOverwrites:iter() do
			if perm.type == "role" then
				raw = perm:getObject()
				new = data.cache.role[raw.id]
				if new then
					overwrite = output:getPermissionOverwriteFor(new)
					if not overwrite then
						DEBUG(data, "ERROR", "Could not copy the overwrite of the role '%s'-'%s' for the channel/category '%s'-'%s'", new.name, new.id, output.name, output.id)
					end
				else
					DEBUG(data, "ERROR", "Could not find the role '%s' to overwrite a permission for the channel/category '%s'-'%s'", raw.name, output.name, output.id)
				end
			else -- member
				raw = perm:getObject()
				new = data.output:getMember(raw.id)
				if new then
					overwrite = output:getPermissionOverwriteFor(new)
					if not overwrite then
						DEBUG(data, "ERROR", "Could not copy the overwrite of the member '%s'-'%s' for the channel/category '%s'-'%s'", new.tag, new.id, output.name, output.id)
					end
				else
					DEBUG(data, "ERROR", "Could not find the member '%s'-'%s' to overwrite a permission for the channel/category '%s'-'%s'", raw.tag, raw.id, output.name, output.id)
				end
			end

			if overwrite then
				overwrite:setPermissions(perm:getAllowedPermissions(), perm:getDeniedPermissions())
				DEBUG(data, "DEBUG", "Permission Overwrites of '%s'-'%s' copied for the channel/category '%s'-'%s'", (new.tag or new.name), new.id, output.name, output.id)
			end
			overwrite = nil
		end
	end

	local mkChannels = function(data)
		data.action = data.action + data.input.categories:count()
		local arr = sortLT(data.input.categories)

		local category, newCategory
		for i = 1, #arr do
			category = arr[i]

			newCategory = data.output:createCategory(category.name)
			if newCategory then
				data.cache.category[category.id] = newCategory.id
				DEBUG(data, "DEBUG", "Copied category '%s'-'%s'", newCategory.name, newCategory.id)
				setPermissionOverwrite(data, category, newCategory)
			else
				DEBUG(data, "ERROR", "Could not copy the category '%s'-'%s'", category.name, category.id)
			end
		end

		data.wrap = 2

		data.action = data.action +
			data.input.textChannels:count() +
			data.input.voiceChannels:count()

		coroutine.wrap(function(data)
			local arr = sortLT(data.input.textChannels)

			local textChannel, newChannel
			for i = 1, #arr do
				textChannel = arr[i]

				newChannel = data.output:createTextChannel(textChannel.name)
				if newChannel then
					data.cache.textChannel[textChannel.id] = newChannel.id
					if textChannel.category then
						newChannel:setCategory(data.cache.category[textChannel.category.id])
					end
					if data.systemChannelId == textChannel.systemChannelId then
						data.systemChannelId = newChannel.id
					end
					coroutine.wrap(function(textChannel, newChannel)
						if textChannel.nsfw then
							newChannel:enableNSFW()
						end
						newChannel:setRateLimit(textChannel.rateLimit)
						newChannel:setTopic(textChannel.topic)

						coroutine.wrap(setPermissionOverwrite)(data, textChannel, newChannel)
						DEBUG(data, "DEBUG", "Copied and configured the text channel '%s'-'%s'", newChannel.name, newChannel.id)
					end)(textChannel, newChannel)
				else
					DEBUG(data, "ERROR", "Could not copy the text channel '%s'-'%s'", textChannel.name, textChannel.id)
				end
			end

			triggerEvent(data)
		end)(data)

		coroutine.wrap(function(data)
			local arr = sortLT(data.input.voiceChannels)

			local voiceChannel, newChannel
			for i = 1, #arr do
				voiceChannel = arr[i]

				newChannel = data.output:createVoiceChannel(voiceChannel.name)
				if newChannel then
					data.cache.voiceChannel[voiceChannel.id] = newChannel.id
					if voiceChannel.category then
						newChannel:setCategory(data.cache.category[voiceChannel.category.id])
					end
					if data.afkChannelId == voiceChannel.afkChannelId then
						data.afkChannelId = newChannel.id
					end
					coroutine.wrap(function(voiceChannel, newChannel)
						newChannel:setBitrate(voiceChannel.bitrate)
						newChannel:setUserLimit(voiceChannel.userLimit)
	
						coroutine.wrap(setPermissionOverwrite)(data, voiceChannel, newChannel)
						DEBUG(data, "DEBUG", "Copied and configured the voice channel '%s'-'%s'", newChannel.name, newChannel.id)
					end)(voiceChannel, newChannel)
				else
					DEBUG(data, "ERROR", "Could not copy the voice channel '%s'-'%s'", voiceChannel.name, voiceChannel.id)
				end
			end

			triggerEvent(data)
		end)(data)
	end

	build = function(data)
		data.action = 1
		data.debug = { }
		data.cache = {
			emoji = { },
			role = { },
			category = { },
			textChannel = { },
			voiceChannel = { }
		}

		DEBUG(data, "DEBUG", "Starting backup")

		event:on(data.id, function(data)
			if data.stage == 1 then
				-- Make roles
				mkRoles(data)

				-- Make emojis
				coroutine.wrap(mkEmojis)(data)
			elseif data.stage == 2 then
				data.afkChannelId = data.input.afkChannelId
				data.systemChannelId = data.input.systemChannelId
				
				-- Make categories and its respective channels
				mkChannels(data)
			elseif data.stage == 3 then
				data.action = data.action + 1

				-- Settings
				if data.afkChannelId then
					data.output:setAFKChannel(data.afkChannelId)
				end
				if data.afkChannelId then
					data.output:setSystemChannel(data.afkChannelId)
				end
				data.output:setAFKTimeout(data.afkTimeout)
				data.output:setExplicitContentSetting(data.input.explicitContentSetting)
				if data.input.iconURL then
					data.output:setIcon(toImage(data.input.iconURL))
				end
				data.output:setName(data.input.name)
				data.output:setNotificationSetting(data.input.notificationSetting)
				data.output:setRegion(data.input.region)
				if data.input.splashURL then
					data.output:setSplash(toImage(data.input.splashURL))
				end
				data.output:setVerificationLevel(data.input.verificationLevel)

				DEBUG(data, "DEBUG", "Set Server settings.")
			end
		end)
		-- Deletes all content of the output guild
		delContent(data)
	end
end

client:on("messageCreate", function(message)
	if message.content == ".BACKUP" and isAdmin(message.member) then
		local guild = client.guilds:find(function(guild) -- Checks if the bot is in a guild that there are only 2 members and that they are obligatorily the bot itself and the requester.
			return guild.totalMemberCount == 2 and guild.members:find(function(member)
				return member.id == message.member.id
			end)
		end)

		if guild and isAdmin(guild.me) then
			pcall(function()
				coroutine.wrap(build)({
					input = message.guild,
					output = guild,
					time = os.time(),
					id = message.guild.id .. guild.id,
					stage = 0,
					message = message.member:send("Backup will be finished in a few minutes.")
				})
			end)

			message:addReaction("\xE2\x98\x91") -- Success
		else
			message:addReaction("\xF0\x9F\x87\xBD") -- Request denied
		end
	end
end)

-- Starts the bot
local token
do
	local file = io.open("token", 'r')
	token = file:read("*l")
	file:close()
end
client:run("Bot " .. token)