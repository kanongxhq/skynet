local skynet = require "skynet"
require "skynet.manager"
local mysql = require "skynet.db.mysql"

local CMD={}
local db 

local mysql_host        =  skynet.getenv "mysql_host" or "127.0.0.1" 
local mysql_port        =  tonumber(skynet.getenv "mysql_port" or 3306 )
local mysql_database    =  skynet.getenv "mysql_database" or "eimsgame" 
local mysql_user        =  skynet.getenv "mysql_user" or "root" 
local mysql_password    =  skynet.getenv "mysql_password" or "1" 

-------------------------------dump用作打印,数据库操作未防止代码注入


function CMD.insert(sql)

    local res = db:query(sql)     
    skynet.error("query result2=",dump(res))
    return res;
end

function CMD.delete(sql)



end

function CMD.query(sql)

    local res = db:query(sql) 
    --skynet.error("name:", res[1]["username"])
    --skynet.error("query result=",dump( res ) )
    return res

end

function CMD.update(sql)

end


skynet.start(function()
    local config = {
		host=               mysql_host,
		port=               mysql_port,
		database=           mysql_database,
		user=               mysql_user,
		password=           mysql_password,
		max_packet_size =   1024 * 1024
	}
	db=mysql.connect(config)
	if not db then
		skynet.error("opmysql failed to connect mysql")
    else
        skynet.error("opmysql success to connect mysql")
	end
    skynet.dispatch("lua", function(session, source, cmd, ...)
        local f = CMD[cmd]
        if not f then
            return
        end     
        if session > 0 then
            skynet.ret(skynet.pack(f(...)))
        else
            f(...)
        end
    end)
    skynet.register(".opmysql")
end)

