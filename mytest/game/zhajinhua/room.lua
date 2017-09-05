local skynet = require "skynet"
local netpack = require "skynet.netpack"
local socket = require "skynet.socket"

local cjson = require "cjson"
local proto = require "proto.proto"
local utils = require "utils.utils"

local REQUEST = {}
local CMD = {}

local fd_player = {} --socket id 对应的玩家
local ud_player = {} --user id   对应的玩家
local room_type = 0

function REQUEST.enter_zhajinhua(fd,ud)

end

function REQUEST.exit_zhajinhua(fd,ud)

end

function CMD.create(room_type)
    room_type = room_type
end

function CMD.exit()
    
end

skynet.start(function()
	skynet.dispatch("lua", function(session, source, cmd, subcmd, ...)
		if cmd == "socket" then
			local f = assert(SOCKET[subcmd])
            if session == 0 then
                f(...)
            else
                skynet.ret(skynet.pack(f(subcmd, ...)))
            end
		else
			local f = assert(CMD[cmd])
            if session == 0 then
                f(subcmd, ...)
            else
                skynet.ret(skynet.pack(f(subcmd, ...)))
            end
		end
	end)
end)