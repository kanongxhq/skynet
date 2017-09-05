local skynet = require "skynet"
local netpack = require "skynet.netpack"
local cjson = require "cjson"
local proto = require "proto.proto"
local utils = require "utils.utils"
local socket = require "skynet.socket"

local gate = nil
local CMD = {}
local SOCKET = {}
local fd_agent = {}
local ud_agent = {}

local function send_package(fd,pack)
	local json = cjson.encode(pack)
	local package = string.pack(">s2", json)
	socket.write(fd, package)
end

local function recv_data(fd,tbData)
	if tbData and tbData.cmd then
		local cmdName = proto.c2s[tbData.cmd] 
		if cmdName and cmdName == "auth" then
			skynet.error("watchdog","support client request",cmdName)
			local f = CMD[cmdName]
			if f then
				local response = f(fd,tbData.token)
				if response then
					send_package(fd,response)
				end
			else
				skynet.error("watchdog","unsupport client request function")
				skynet.call(gate, "lua", "kick", fd)
			end
		else
			skynet.error("watchdog","unsupport client request",tbData.cmd)
			skynet.call(gate, "lua", "kick", fd)
		end
	else
		skynet.call(gate, "lua", "kick", fd)
		skynet.error("watchdog","client data error")
	end
end

--玩家连接断开
local function close_agent(fd)
	local agent = fd_agent[fd]
	fd_agent[fd] = nil
	if agent then
		skynet.call(gate, "lua", "kick", fd)
		skynet.send(agent, "lua", "disconnect")
	end
end

--把玩家踢出游戏
local function kick_agent(fd,ud)
	local agent = ud_agent[ud]
	ud_agent[ud] = nil
	close_agent(fd)
	if agent then
		skynet.send(agent, "lua", "exit")
	end
end



function SOCKET.open(fd, addr)
	skynet.error("watchdog client connect: " .. addr)
	skynet.call(gate, "lua", "openclient", fd)
end

function SOCKET.close(fd)
	skynet.error("watchdog client close: "..fd)
	close_agent(fd)
end

function SOCKET.error(fd, msg)
	skynet.error("watchdog client error: "..fd)
	close_agent(fd)
end

function SOCKET.warning(fd, size)
	skynet.error("watchdog client warning: "..fd)
end

function SOCKET.data(fd, msg)
	skynet.error("watchdog client data: "..msg)
	local json = cjson.decode(msg) 
	recv_data(fd,json)
end

function CMD.start(conf)
	skynet.error(string.format("watchdog start %s:%d", conf.address, conf.port))
	skynet.call(gate, "lua", "open" , conf)
end

function CMD.kick(fd,ud)
	skynet.error("watchdog kick client: " .. ud)
	kick_agent(fd,ud)
end

function CMD.auth(fd,token)
	skynet.error("watchdog auth token:"..token)
	if not token or token == "" then
		return {cmd = proto.s2c["auth_resp"], code = -1, msg = "auth fail"}
	end 
	-- 检测token 是否有效
	if token ~= "123456" then
		return {cmd = proto.s2c["auth_resp"], code = -1, msg = "invaild token"}
	end
	-- 通过token 获取用户id
	local ud = 1000
	if not ud then
		return {cmd = proto.s2c["auth_resp"], code = -1, msg = "invaild token"}
	end

	if ud_agent[ud] then
		skynet.error("watchdog","ud_agent[1000] exist")
		fd_agent[fd] = ud_agent[ud]
	else
		skynet.error("watchdog","need to new ud_agent[1000]")
		fd_agent[fd] = skynet.newservice("agent")
		ud_agent[ud] = fd_agent[fd]
	end
	skynet.error("watchdog",string.format("create agent %d",ud_agent[ud]))
	skynet.call(fd_agent[fd], "lua", "start", { gate = gate, client = fd, watchdog = skynet.self(),user_id = ud })
	return {cmd = proto.s2c["auth_resp"], code = 0, msg = "auth success"}
end

skynet.start(function()
	skynet.dispatch("lua", function(session, source, cmd, subcmd, ...)
		if cmd == "socket" then
			local f = SOCKET[subcmd]
			f(...)
			-- socket api don't need return
		else
			local f = assert(CMD[cmd])
			skynet.ret(skynet.pack(f(subcmd, ...)))
		end
	end)
	gate = skynet.newservice("mygate")
end)
