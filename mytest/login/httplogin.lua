local skynet = require "skynet"
local socket = require "skynet.socket"

local port = tonumber(...)
skynet.start(function()
	
	local agent = {}
	for i = 1,20 do
		agent[i] = skynet.newservice("loginagent")
	end
	local balance = 1
	local id = socket.listen("127.0.0.1",port)
	socket.start(id,function(_id,addr)
		skynet.error("httplogin",string.format("%s connected, pass it to agent :%08x", addr, agent[balance]))
		skynet.send(agent[balance],"lua",_id)
		balance = balance + 1
		if balance > #agent then
			balance = 1
		end
	end)
	
end)
