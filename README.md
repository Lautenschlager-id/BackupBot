<p align="center"><img src="https://i.imgur.com/y41VeCM.png" width="50%"/></p>

The **BackupBot** is a bot developed for the *Discord Hack Week* and was developed using the [Luvit](https://github.com/luvit/luvit) environment, with the Lua programming language and the [Discordia](https://github.com/SinisterRectus/Discordia/) API.

Its invite link: https://discordapp.com/oauth2/authorize?client_id=592860951917756426&scope=bot&permissions=8<br>
I have decided not to host it, since it easy-to-use and can get overloaded if thousands of people use it at the same time.

## Productivity
The aim of the bot is to copy entirely a server, including roles and emojis.

It can be useful for multiple occasions, such as:
- Refreshing your oldie server;
- Duplicating the server for bot testing purposes; <sub>( Don't code on production ;) )</sub>
- Storing the server structure for possible future damage;
- Why not backuping something important?

## Behavior
The bot initially deletes all content from the duplicated server (channels, categories, emojis, ...) and asynchronally copies all emojis, roles, categories, channels and voice channels, permissions and other server settings.

It will keep you updated about the remaining seconds / processes through private messages.

Once the backup is done, you will receive the guild IDs and the log files.

The [file LOG](example/LOGS-593238982276546570-593245903402303520.log) has a debugging log with all actions and errors <sub>(mostly about creating permissions for non-members)</sub>.<br>
The [file TREE](example/TREE-593238982276546570-593245903402303520.lua) has a tree using the Lua table format `[index] = "value"` with the relation of original-server-id and cloned-server-id, so you know what became what.

## How to start (Code)
**A ready-to-use version of the bot can be downloaded [here](BackupBot.zip).**

To start the bot, open your command prompt <sub>(in the folder of the bot)</sub> and type the command `luvit bot`.

The file `token` must contain the bot token.

## How to start (User)
The bot has a single and simple command, **`.BACKUP`**, that can be used in any channel of the server **that you want to be cloned**.

Even though it's not checked, it's **fundamental** for the bot to have **administrator** permissions in the original server, so it can reach every channel.<br>
**Nothing** will be changed in the original server.

It's **obligatory** for the bot to have **administrator** permissions in the server that is going to be used as backup.<br>
It's recommended that you set the bot role the highest one of the clone server, so it can manage all the roles.<br>
This server is automatically detected by the bot and it relies on two conditions:<br>
- Must have only 2 members;
	- One member must be the bot itself;
	- One member must be who typed the command `.BACKUP`.
- Both members must have administrator permissions.

Once it's matched, the bot will start to work.

See images **[here](example)**.

### Good luck everybody!