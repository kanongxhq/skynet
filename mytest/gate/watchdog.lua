local skynet = require "skynet"
local netpack = require "skynet.netpack"
local cjson = require "cjson"
local proto = require "proto.proto"
local utils = require "utils.utils"
local socket = require "skynet.socket"

local gate = nil
local CMD = {}
local SOCKET = {}
local agent = {}

local function send_package(pack)
	local json = cjson.encode(pack)
	local package = string.pack(">s2", json)
	socket.write(client_fd, package)
end

local function recv_data(tbData)
	if tbData and tbData.cmd then
		local cmdName = proto.c2s[tbData.cmd] 
		if cmdName and cmdName == "auth" then
			skynet.error("support client request",cmdName)
			local f = REQUEST[cmdName]
			local response = f(tbData.token)
			if response then
				send_package(response)
			end
			skynet.error("unsupport client request function")
			socket.close_fd(client_fd)
		else
			skynet.error("unsupport client request",tbData.cmd)
		end
	else
		socket.close_fd(client_fd)
		skynet.error("client data error")
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


function SOCKET.open(fd, addr)
	skynet.error("watchdog client connect: " .. addr)
	agent[fd] = skynet.newservice("agent")
	skynet.call(agent[fd], "lua", "start", { gate = gate, client = fd, watchdog = skynet.self() })
	--skynet.call(gate, "lua", "forward", fd)
end

local function close_agent(fd)
	local a = agent[fd]
	agent[fd] = nil
	if a then
		skynet.call(gate, "lua", "kick", fd)
		-- disconnect never return
		skynet.send(a, "lua", "disconnect")
	end
end

function SOCKET.close(fd)
	skynet.error("watchdog client close: "..fd)
	--print("socket close",fd)
	close_agent(fd)
end

function SOCKET.error(fd, msg)
	skynet.error("watchdog client error: "..fd)
	--print("socket error",fd, msg)
	close_agent(fd)
end

function SOCKET.warning(fd, size)
	skynet.error("watchdog client warning: "..fd)
	-- size K bytes havn't send out in fd
	--print("socket warning", fd, size)
end

function SOCKET.data(fd, msg)
	skynet.error("watchdog client data: "..msg)

end

function CMD.start(conf)
	skynet.error(string.format("watchdog start %s:%d", conf.address, conf.port))
	skynet.call(gate, "lua", "open" , conf)
end

function CMD.close(fd)
	skynet.error("watchdog client close: " .. fd)
	close_agent(fd)
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
