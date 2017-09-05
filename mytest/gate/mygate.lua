local skynet = require "skynet"
local gateserver = require "gate.mygateserver"
local netpack = require "skynet.netpack"

local watchdog 
local connection = {}	-- fd -> connection : { fd , client, agent , ip, mode }
local forwarding = {}	-- agent -> connection

skynet.register_protocol {
	name = "client",
	id = skynet.PTYPE_CLIENT,
}

local function unforward(c)
	if c.agent then
		forwarding[c.agent] = nil
		c.agent = nil
		c.client = nil
	end
end

-- 移除客户端连接句柄
local function close_fd(fd)
	local c = connection[fd]
	if c then
		unforward(c)
		connection[fd] = nil
	end
end

local handler = {}

--gatesecver 监听成功回调
function handler.open(source, conf)
	skynet.error(string.format("mygate listen %s:%d", conf.address, conf.port))
	watchdog = conf.watchdog or source
end

-- 客户端 连接成功回调
function handler.connect(fd, addr)
	skynet.error(string.format("mygate client connect %s", addr))
	local c = {
		fd = fd,
		ip = addr,
	}
	connection[fd] = c -- 保存客户端连接句柄
	skynet.send(watchdog, "lua", "socket", "open", fd, addr)
end

-- 客户端 主动断开连接
function handler.disconnect(fd)
	--skynet.error("mygate client disconnect")
	close_fd(fd)
	skynet.send(watchdog, "lua", "socket", "close", fd)
end

-- 客户端 连接发生异常
function handler.error(fd, msg)
	--skynet.error("mygate client error")
	close_fd(fd)
	skynet.send(watchdog, "lua", "socket", "error", fd, msg)
end

-- 客户度 数据长度警告
function handler.warning(fd, size)
	--skynet.error("mygate client warning")
	skynet.send(watchdog, "lua", "socket", "warning", fd, size)
end

-- 收到客户端数据 
function handler.message(fd, msg, sz)
	--skynet.error(string.format("mygate message %d", sz))
	-- recv a package, forward it
	local c = connection[fd]
	local agent = c.agent
	if agent then
		skynet.redirect(agent, c.client, "client", 0, msg, sz) -- 客户端代理服务发送client消息
	else
		skynet.send(watchdog, "lua", "socket", "data", fd, netpack.tostring(msg, sz))
	end
end

local CMD = {}

function CMD.forward(source, fd, client, address)
	skynet.error("mygate","forward",fd)
	local c = assert(connection[fd])
	unforward(c)
	c.client = client or 0
	c.agent = address or source 
	forwarding[c.agent] = c -- 保存客户端代理服务
	gateserver.openclient(fd) --
end

function CMD.accept(source, fd)
	skynet.error("mygate accept")
	local c = assert(connection[fd])
	unforward(c)
	gateserver.openclient(fd)
end

function CMD.kick(source, fd)
	--skynet.error("mygate client kick "..fd)
	close_fd(fd)
	gateserver.closeclient(fd)
end

function CMD.openclient(source, fd)
	--skynet.error("mygate client openclient "..fd)
	gateserver.openclient(fd)
end

function CMD.closeclient(source, fd)
	--skynet.error("mygate client closeclient "..fd)
	gateserver.closeclient(fd)
end

function handler.command(cmd, source, ...)
	local f = assert(CMD[cmd])
	return f(source, ...)
end

gateserver.start(handler)
