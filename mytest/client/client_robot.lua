local skynet = require "skynet"
local proto = require "proto.proto"
local socket = require "skynet.socket"
local httpc = require "http.httpc"
local cjson = require "cjson"
local utils = require "utils.utils"
local last = ""

--加密打包
local function pack_package(cmd,body)
    local pack =  proto.pack(cmd,body)
    skynet.error("pack_package:"..utils.bytes(pack))
    pack = proto.encrypt(pack)
    skynet.error("pack_package:"..utils.bytes(pack))
    return pack
end

--分包解密
local function unpack_package(text)
    local size = #text
    if size < proto.HEADSIZE then
        return nil,nil, text
    end
    local body_size = text:byte(2) * 256 + text:byte(1)
    local pack_size = proto.HEADSIZE + body_size 
    if size < pack_size then
        return nil,nil, text
    end
    local package = text.sub(1,pack_size)
    local last = text:sub(pack_size + 1)
    proto.decrypt(package)
    return proto.unpack(package), last
end

local function send_package(fd,cmd,pack)
    if not cmd then
        return 
    end
    socket.write(fd, pack_package(cmd,pack))
end

local function send_request(fd,cmd,body)
    local str = cjson.encode(body)
    skynet.error("send_request ", str)
    send_package(fd,cmd,str)
end

local function recv_package(fd,last)
    local cmd,pack
    cmd,pack,last = unpack_package(last)
    if cmd then
        return cmd, pack,last
    end
    local str = socket.read(fd)
    if str == false then
        return false,nil,last
    end
    return unpack_package(last .. str)
end
local function dispatch_package(fd)
    while true do
        local cmd,pack
        cmd,pack,last = recv_package(fd,last)
        if cmd == false then
            skynet.error("dispatch_package recv error")
            break
        elseif cmd then
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
        skynet.error("login","body:"..body)
        local ret = cjson.decode(body)
        if ret.code == 0 then
            --print(utils.dump(ret))
            token = ret.token
            local fd = socket.open(ret.game_host, ret.game_port)
            if fd then
                send_request(fd,proto.c2s["auth"],{cmd = proto.c2s["auth"], token = token})
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
