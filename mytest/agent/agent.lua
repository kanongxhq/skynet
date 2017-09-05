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

local function send_package(pack)
	local json = cjson.encode(pack)
	local package = string.pack(">s2", json)
	socket.write(user_data.fd, package)
end

local function recv_data(tbData)
	if tbData and tbData.cmd then
			local cmdName = proto.c2s[tbData.cmd] 
			if cmdName then
				skynet.error(agent,"support client request",cmdName)
				local f = REQUEST[cmdName]
				if f then
					local response = f(tbData)
					if response then
						send_package(response)
					end
				else
					skynet.error(agent,"unsupport client request function")
				end
			else
				skynet.error(agent,"unsupport client request",tbData.cmd)
			end
	else
		skynet.error(agent,"client data error")
	end
end

-- 对已分包数据进行解包
skynet.register_protocol {
	name = "client",
	id = skynet.PTYPE_CLIENT,
	unpack = function (msg, sz)
		-- 解包
		local json = skynet.tostring(msg,sz) 
		return cjson.decode(json)
	end,
	dispatch = function(_, _,tbData,...)
		--分发协议数据
		recv_data(tbData)
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
