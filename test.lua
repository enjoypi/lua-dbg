local d = require("debugger")

function f( ... )
	print(coroutine.running())
	d.Break()
	require("test_inner").f()
	-- body
end

require("coroutineEnhanced").Run(f)

