local require = require
local pairs = pairs
local print = print

module(...)

function f( ... )
	-- body
	for k, v in pairs(require("debug")) do
		print(k, v)
	end
end
