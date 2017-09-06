local skynet = require "skynet"
local netpack = require "skynet.netpack"
local socket = require "skynet.socket"

local WATCHDOG
local cjson = require "cjson"
local proto = require "proto.proto"
local utils = require "utils.utils"

local opmysql = nil
local CMD = {}
local REQUEST = {}

--用户状态数据
local user_data = {}
user_data.fd = 0
user_data.ud = 0
user_data.is_online = false

local function send_package(cmd,body)
	local json = cjson.encode(body)
	local package = proto.pack(cmd,body)
	proto.encrypt(package)
	socket.write(user_data.fd, package)
end

local function recv_data(cmd,body)
	if cmd then
			local cmdName = proto.c2s[cmd] 
			if cmdName then
				skynet.error(agent,"support client request",cmdName)
				local f = REQUEST[cmdName]
				if f then
					local cmd,response = f(body)
					if response then
						send_package(cmd,response)
					end
				else
					skynet.error(agent,"unsupport client request function")
				end
			else
				skynet.error(agent,"unsupport client request",cmd)
			end
	else
		skynet.error(agent,"client data error")
	end
end

-- 对已分包数据进行解包
skynet.register_protocol {
	name = "client",
	id = skynet.PTYPE_CLIENT,
	unpack = function (cmd, body)
		-- 解包
		return cmd,body
	end,
	dispatch = function(_, _,cmd,body,...)
		--分发协议数据
		recv_data(cmd,body)
	end
}

local function handshake()
	skynet.fork(function()
		while user_data.is_online do
			send_package({cmd = proto.s2c["handshake"]})
			skynet.sleep(500)
		end
	end)
end

local function check_if_need_exit()
	skynet.timeout(1000,function()
		if not user_data.is_online then
			skynet.call(WATCHDOG, "lua", "kick", user_data.fd,user_data.ud)
		end
	end)
end


function REQUEST.login()
	skynet.error("agent login")
	return {cmd = proto.s2c["loginresp"], msg = "success" }
end

function REQUEST.logout()
	skynet.error("agent logout")
	send_package( {cmd = proto.s2c["logoutresp"], msg = "success" })
	skynet.call(WATCHDOG, "lua", "kick", user_data.fd,user_data.ud)
end

function REQUEST.chat(data)
	skynet.error("agent chat",data)
	return {cmd = proto.s2c["chat"], msg = data}
end

function CMD.start(conf)
	skynet.error("agent start")
	local fd = conf.client
	local gate = conf.gate
	WATCHDOG = conf.watchdog
	user_data.fd = fd
	user_data.ud= conf.user_id
	user_data.is_online = true
	skynet.call(gate, "lua", "forward", fd)
	handshake()
end

function CMD.disconnect()
	skynet.error("agent disconnect")
	user_data.fd = 0
	user_data.is_online = false
	check_if_need_exit()
end

function CMD.exit()
	skynet.error("agent exit")
	skynet.exit()
end

skynet.start(function()
	opmysql = skynet.localname(".opmysql")
	skynet.dispatch("lua", function(_,_, command, ...)
		local f = CMD[command]
		skynet.ret(skynet.pack(f(...)))
	end)
end)
