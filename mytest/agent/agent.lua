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
user_data.handshake_time = 0

local function log_prefix()
	return string.format("%s[%d]",SERVICE_NAME,user_data.ud)
end

local function send_package(cmd,body)
	body = cjson.encode(body)
	local package = proto.pack(cmd,body)
	package = proto.encrypt(package)
	--skynet.error("agent","send_package "..utils.bytes(package))
	socket.write(user_data.fd, package)
end

local function recv_data(cmd,body)
	if cmd then
			local cmdName = proto.c2s[cmd] 
			if cmdName then
				skynet.error(log_prefix(),"support client request",cmdName)
				local f = REQUEST[cmdName]
				if f then
					local cmd,response = f(body)
					if response then
						send_package(cmd,response)
					end
				else
					skynet.error(log_prefix(),"unsupport client request function")
				end
			else
				skynet.error(log_prefix(),"unsupport client request",cmd)
			end
	else
		skynet.error(log_prefix(),"client data error")
	end
end

-- 对已分包数据进行解包
skynet.register_protocol {
	name = "client",
	id = skynet.PTYPE_CLIENT,
	unpack = function (msg,sz)
		-- 解包
		local package = skynet.tostring(msg,sz)
		skynet.error(log_prefix(),"data:",utils.bytes(package))
		local cmd,body = proto.unpack(package)
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
			send_package(proto.s2c["handshake"],{cmd = proto.s2c["handshake"]})
			skynet.sleep(500)
			if skynet.time() - user_data.handshake_time >30 then
				--客户端超时没回应，认为已断开
				skynet.error(log_prefix(),"time out to kick")
				skynet.call(WATCHDOG, "lua", "kick", user_data.fd,user_data.ud)
			end
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
	skynet.error(log_prefix(),"login")
	return {cmd = proto.s2c["loginresp"], msg = "success" }
end

function REQUEST.logout()
	skynet.error(log_prefix(),"logout")
	send_package( {cmd = proto.s2c["logoutresp"], msg = "success" })
	skynet.call(WATCHDOG, "lua", "kick", user_data.fd,user_data.ud)
end

function REQUEST.chat(data)
	skynet.error(log_prefix(),"chat",data)
	return {cmd = proto.s2c["chat"], msg = data}
end

function REQUEST.handshake(data)
	skynet.error(log_prefix(),"handshake",data)
	user_data.handshake_time = skynet.time()
end



function CMD.start(conf)
	
	local fd = conf.client
	local gate = conf.gate
	WATCHDOG = conf.watchdog
	user_data.fd = fd
	user_data.ud= conf.user_id
	user_data.is_online = true
	skynet.call(gate, "lua", "forward", fd)
	skynet.error(log_prefix(),"start")
	handshake()
	user_data.handshake_time = skynet.time()
end

function CMD.disconnect()
	skynet.error(log_prefix(),"disconnect")
	user_data.fd = 0
	user_data.is_online = false
	check_if_need_exit()
end

function CMD.exit()
	skynet.error(log_prefix(),"exit")
	skynet.exit()
end

skynet.start(function()
	opmysql = skynet.localname(".opmysql")
	skynet.dispatch("lua", function(_,_, command, ...)
		local f = CMD[command]
		skynet.ret(skynet.pack(f(...)))
	end)
end)
