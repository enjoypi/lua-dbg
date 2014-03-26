local require = require
local os = os
local type = type
local tostring = tostring
local coroutine = require("coroutine")
local table = require("table")

local function CoroutineRecursive(f, ...)
	return CoroutineRecursive(coroutine.yield(f(...)))
end

local threads = {}
local runningThreads = {}
local runningThreadAmount = 0
local GetThread = function()
	local threadInfo = table.remove(threads)
	if threadInfo == nil then
		return coroutine.create(function(f, ...)
			return CoroutineRecursive(f, ...)
		end)
	end
	return threadInfo.thread
end

local function reset(thread)
	local threadInfo = {}
	threadInfo.lastRunTime = os.clock()
	threadInfo.thread = thread
	table.insert(threads, threadInfo)
	runningThreads[thread] = nil
	runningThreadAmount = runningThreadAmount - 1
end

local suspenedByUser = function() end -- 这是一个用来判断是否是用户终止的常量

local function CatchThread(thread, success, state, ...)
	if (success == false) then -- 协程出错
		runningThreads[thread] = nil
		runningThreadAmount = runningThreadAmount - 1
		return error(require("debug").traceback(tostring(state), 3))
	end
	if (state ~= suspenedByUser) then -- 任务完成
		reset(thread)
		return state, ...
	else -- User Yielded
		return ...
	end
end

function LuaResume(thread, ...)
	return CatchThread(thread, coroutine.resume(thread, ...))
end

local LuaResume = LuaResume

module(...)

function GetCurrentThread()
	return coroutine.running()
end

function Run(...)
	local thread = GetThread()
	runningThreads[thread] = true
	runningThreadAmount = runningThreadAmount + 1
	return LuaResume(thread, ...)
end

Resume = LuaResume

function Yield(...)
	if coroutine.running() == nil then
		error("Can not yield in main thread.")
	end
	return coroutine.yield(suspenedByUser, ...)
end

function Wrap(f)
	return function(...)
		Run(f, ...)
	end
end

function RecycleThread()
	local thread = coroutine.running()
	if thread == nil then
		error("Can not RecycleThread in main thread.")
	end
	reset(thread)
end

function RunningThreadAmount()
	return runningThreadAmount
end
