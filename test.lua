local d = require("debugger")


function g(...)
	local a = 1999
	print(a)
end

function f( ... )
	print(coroutine.running())
	d.Break()
	require("test_inner").f()
	g(...)
	-- body
end

require("coroutineEnhanced").Run(f)

