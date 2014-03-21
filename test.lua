local d = require("debugger")
d.Start()
d.SetBreakpoint(5, "test.lua")
for k, v in pairs(d) do
	print(k, v)
end

