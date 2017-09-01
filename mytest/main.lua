require "utils.string"
local skynet = require "skynet"
local max_client = 64

skynet.start(function()
	skynet.error("Server start")
	if not skynet.getenv "daemon" then
		local console = skynet.newservice("console")
	end
	local debug_console_port        =  tonumber(skynet.getenv "debug_console_port" or 6001)
	skynet.newservice("debug_console",debug_console_port)

	--mysql db 服务器
	skynet.uniqueservice("opmysql")
	--redis db 服务器
	skynet.uniqueservice("opredis")

	--登录服务器
	local httplogin_port        =  tonumber(skynet.getenv "httplogin_port" or 6002)
	skynet.newservice("httplogin",httplogin_port)

	--网关服务器
	local game_host        =  skynet.getenv "game_host" or "127.0.0.1"
	local game_port        =  tonumber(skynet.getenv "game_port" or 6003)
	local watchdog = skynet.newservice("watchdog")
	skynet.call(watchdog, "lua", "start", {
		address = game_host,
		port = game_port,
		maxclient = max_client,
		nodelay = true,
	})
	skynet.exit()
end)
