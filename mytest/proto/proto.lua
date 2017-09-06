local skynet = require "skynet"
local utils = require "utils.utils"
local proto = {}
proto.HEADSIZE = 11

--对数据进行打包
function proto.pack(cmd,body)
	local body_size = #body
    local version = 0
    local key = math.random(0,255)
    local flag = 1
    local pNo = 1
    local pack =  string.pack("<HBHBBI4c"..body_size,body_size,version,cmd, key,flag,pNo,body)
	return pack
end

--对带有包头的已解密数据包进行解包，返回协议号和包体
function proto.unpack(pack)
	if #pack <proto.HEADSIZE then
		return
	else
		local cmd = pack:byte(5)*256 + pack:byte(4)
		local body = pack.sub(proto.HEADSIZE + 1)
		return cmd,body
	end
end
--对带有包头的数据进行加密
function proto.encrypt(pack)
	skynet.error("proto.encrypt:"..utils.bytes(pack))
	assert(#pack >= proto.HEADSIZE)
	local key = pack:byte(6)
	skynet.error("proto.encrypt:"..key)
	for i = proto.HEADSIZE + 1,#pack do
        pack[i] = (pack:byte(i)~key) + key
    end
	return pack
end

--对带有包头的数据进行解密
function proto.decrypt(pack)
	assert(#pack >= proto.HEADSIZE)
	local key = pack:byte(6)
	for i = proto.HEADSIZE + 1,#pack do
        pack[i] = (pack:byte(i) - key) ~ key
    end
	return pack
end




proto.c2s = {
	[10000] = "handshake",
	[10001] = "auth",
	[10002] = "logout",
	[10003] = "chat",
} 

local c2s = {}
for k,v in pairs(proto.c2s) do
	c2s[v] = k
end

for k,v in pairs(c2s) do
	proto.c2s[k] = v
end

proto.s2c = {
	[50000] = "handshake",
	[50001] = "auth_resp",
	[50002] = "logout_resp",
	[50003] = "chat",
} 

local s2c = {}
for k,v in pairs(proto.s2c) do
	s2c[v] = k
end

for k,v in pairs(s2c) do
	proto.s2c[k] = v
end

return proto