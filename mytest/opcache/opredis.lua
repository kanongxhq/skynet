local skynet = require "skynet"
local redis  = require "skynet.db.redis"

local db
local redis_host        =  skynet.getenv "redis_host" or "127.0.0.1" 
local redis_port        =  tonumber(skynet.getenv "redis_port" or 6379)
local redis_db          =  tonumber(skynet.getenv "redis_db" or 0 )
local redis_auth        =  skynet.getenv "redis_auth" or "foobared" 



local CMD = {}

function CMD.set(key,value)
    db:set(key,value)
end

function CMD.get(key)
    db:get(key)
end

function __init__()

    local config = {
        host = redis_host,
        port = redis_port,
        db   = redis_db,
        auth = redis_auth
    }
    db = redis.connect(config)


    if not db then
		skynet.error("opredis failed to connect redis")
    else
        skynet.error("opredis success to connect redis")
	end
    skynet.dispatch("lua", function (_,session,cmd,...)
        local func = CMD[cmd]
        if cmd then
            if session > 0 then
                skynet.ret(skynet.pack(func(...)))
            else
                func(...)
            end
        else
            skynet.error("redis cmd %s not exist",cmd)
        end
    end)

end

skynet.start(__init__)

------高速缓存----