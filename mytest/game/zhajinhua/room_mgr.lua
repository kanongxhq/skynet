local skynet = require "skynet"
local netpack = require "skynet.netpack"
local socket = require "skynet.socket"

local cjson = require "cjson"
local proto = require "proto.proto"
local utils = require "utils.utils"

local REQUEST = {}
local CMD = {}

local cht_zhajinhua_room = {}
local hy_zhajinhua_room = {}
local roomid_playercnt_map = {}

local tb_room_id = {}

for i = 1,1000000 do
    table.insert(tb_room_id,i)
end
local function gen_room_id()
    local rand = math.rand(1,#tb_room_id)
    local room_id = tb_room_id[rand]
    table.remove(tb_room_id,rand)
end

local function recyle_room_id(room_id)
    table.insert(tb_room_id,room_id)
end

local function get_not_full_room()
    table.sort(room_player_count)
    local emptyIndex = nil
    local fullIndex = nil

end

function REQUEST.enter_room(fd,ud,room_type,room_id)
    if room_type == 0 then -- 好友场
        local rooms = hy_zhajinhua_room[room_type]
        if rooms and #rooms > 0 then
            local room = rooms[room_id]
            if room then
                local ret = skynet.call(room,"lua","enter_room")
            else

            end
        else
            
        end
    else -- 传统场
        local rooms = cht_zhajinhua_room[room_type]
        if rooms and #rooms > 0 then
            local rand = math.rand(1,#rooms)
            local ret = skynet.call(rooms[rand],"lua","enter_room")
        else
            local room_id = gen_room_id()
            local room = skynet.newservice("zhajinhua.room_mgr")

            cht_zhajinhua_room[room_type] = {}
            cht_zhajinhua_room[room_type][room_id] = room

            skynet.call(room,"lua","start",{
                room_type = room_type,
                base_bet = 100
            })
            local ret = skynet.call(room,"lua","enter_room")
        end
    end
end

function CMD.player_exit(source,room_id)
    if room_player_count[room_id] and room_player_count[room_id] > 0 then
        room_player_count[room_id] = room_player_count[room_id] -1
    end
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
                skynet.ret(skynet.pack(f(source,subcmd, ...)))
            end
		end
	end)
end)