require "utils.string"
local skynet = require "skynet"
local max_client = 64

skynet.start(function()
	skynet.error("client start")
	if not skynet.getenv "daemon" then
		local console = skynet.newservice("console")
	end
	local debug_console_port        =  tonumber(skynet.getenv "debug_console_port" or 7001)
	skynet.newservice("debug_console",debug_console_port)

	--mysql db 服务器
	skynet.uniqueservice("opmysql")

	local client = skynet.newservice("client_robot")
	skynet.send(client, "lua", "login")
	skynet.exit()
end)
