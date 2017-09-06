local skynet = require "skynet"
local socket = require "skynet.socket"

local httpd = require "http.httpd"
local sockethelper = require "http.sockethelper"
local urlutils = require "http.url"
local cjson = require "cjson"
local utils = require "utils.utils"
local game_host        =  skynet.getenv "game_host" or ""
local game_port        =  skynet.getenv "game_port" or ""

local opmysql = nil
local function response(id,code,msg,...)
	local data = cjson.encode(msg)
	local ok,err = httpd.write_response(sockethelper.writefunc(id),code,data)
	if not ok then
		skynet.error("loginagent",string.format("socket %d response err =  %s", id, err))
	end
end

local function register(id,msg)
	local str = string.format("select * from user_info where user_name = '%s'",msg.name)
    local result = skynet.call(opmysql,"lua","query",str)
    if #result == 0 then 
        -- 可以插入数据
        local str1 = string.format("insert into user_info values('%s','%s',0)",msg.name,msg.password);
        local result2 = skynet.call(opmysql,"lua","insert",str1)
        return {code = 1,msg = "register ok"}
    end
    return  {code = -1,msg = "acccount exist"}
end

local function login(id,msg)
	if not msg.name or msg.name == "" then
		return  {code = -1,msg = "acccount is empty"}
	end

	if not msg.pwd or msg.pwd == "" then
		return  {code = -1,msg = "password is empty"}
	end

	local str = string.format("select * from user_info where user_name ='%s'",msg.name)
    local result = skynet.call(opmysql,"lua","query",str)
    if(msg.name == result[1]["user_name"]) then
        if result[1]["is_online"] == 1 then
			skynet.error("loginagent",string.format("client %s login fail : acccount has  login",msg.name))
			return  {code = -1,msg = "acccount has  login"}
		else
			skynet.error("loginagent",string.format("client %s login success",msg.name))
			return  {code = 0,msg = "login success",token = "123456",game_host = game_host,game_port = game_port}
		end
	else
		skynet.error("loginagent",string.format("client %s login fail : acccount is not exist",msg.name))
		return  {code = -1,msg = "acccount is not exist"}
    end
end

local function handle(id)
	socket.start(id)
	local code,url,_,_,body = httpd.read_request(sockethelper.readfunc(id),128)
	if not code or code ~= 200 then
		return
	end 
	local path,query = urlutils.parse(url)
	skynet.error("loginagent","client req url:"..url)
	if path == "register" then
		response(id,200,register(id,urlutils.parse_query(query)))
	elseif path == "login" then
		response(id,200,login(id,urlutils.parse_query(query)))
	end
end

skynet.start(function()
	opmysql = skynet.localname(".opmysql")
	skynet.dispatch("lua",function(_,_,id)
		handle(id)
		socket.close(id)
	end)
end)