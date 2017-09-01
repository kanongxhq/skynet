local skynet = require "skynet"
local proto = require "proto.proto"
local socket = require "skynet.socket"
local httpc = require "http.httpc"
local cjson = require "cjson"
local utils = require "utils.utils"

local last = ""
local function send_package(fd, pack)
    local package = string.pack(">s2", pack)
    socket.write(fd, package)
end

local function unpack_package(text)
    local size = #text
    if size < 2 then
        return nil, text
    end
    local s = text:byte(1) * 256 + text:byte(2)
    if size < s + 2 then
        return nil, text
    end

    return text:sub(3, 2 + s), text:sub(3 + s)
end

local function recv_package(fd,last)
    local result
    result, last = unpack_package(last)
    if result then
        return result, last
    end
    local str = socket.read(fd)
    if str == false then
        return false,last
    end
    return unpack_package(last .. str)
end

local session = 0

local function send_request(fd,args)
    session = session + 1
    local str = cjson.encode(args)
    skynet.error("send_request ", str)
    send_package(fd, str)
end



local function print_response(session, args)
    skynet.error("RESPONSE", session)
    if args then
        for k, v in pairs(args) do
            print(k, v)
        end
    end
end

local function dispatch_package(fd)
    while true do
        local v
        v, last = recv_package(fd,last)
        if v == false then
            skynet.error("dispatch_package recv error")
            break
        elseif v then
            skynet.error("dispatch_package recv "..v)
        end
    end
end


local CMD = {}

function CMD.login()
    httpc.timeout = 1000 -- set timeout 1 second
    local url = "127.0.0.1:6002"
    local respheader = {}
    local status, body = httpc.get(url, "login?name=xhq12&pwd=xhq12", respheader)
    if status ~= 200 then
        skynet.error("connect loginserver fail")
    else
        skynet.error("body:"..body)
        local ret = cjson.decode(body)
        if ret.code == 0 then
            --print(utils.dump(ret))
            token = ret.token
            local fd = socket.open(ret.game_host, ret.game_port)
            if fd then
                send_request(fd,{cmd = proto.c2s["auth"], token = token})
                skynet.fork(function() 
                    dispatch_package(fd) 
                end)
            else
                skynet.error(string.format("connect %s:%d fail",ret.game_host,ret.game_port))
            end
            
        else
            skynet.error("login fail")
        end
    end
end


skynet.start(function()
    skynet.dispatch("lua", function (source, address, cmd, ...)
		local f = CMD[cmd]
		if f and source > 0 then
			skynet.ret(skynet.pack(f( ...)))
		else
			f(...)
		end
	end)  
end)
