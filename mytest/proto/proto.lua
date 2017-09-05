local proto = {}

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