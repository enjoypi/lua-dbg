local d = require("debugger")

d.Break()
for k, v in pairs(d) do
	print(k, v)
end

