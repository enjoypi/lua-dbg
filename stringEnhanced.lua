local select = select
local tostring = tostring
local string = require("string")
local table = require("table")
local type = type
local error = error
local tonumber = tonumber
local ipairs = ipairs
local assert = assert

module(...)

-- 将转义字符替换，防止被当做模式匹配, 首先把%替换了，再替换其他符号
local match = { "%%", "%^", "%$", "%(", "%)", "%.", "%[", "%]", "%*", "%+", "%-", "%?"}
local repl = { "%%%%", "%%^", "%%$", "%%(", "%%)", "%%.", "%%[", "%%]", "%%*", "%%+", "%%-", "%%?" }
assert(#match == #repl)

function ReplaceMagicCharacters(str)
	for i = 1, #match do
		str = string.gsub(str, match[i], repl[i])
	end
	return str
end

function Convert(sourceCodepage, targetCodepage, s)
	local unicodeLength = win32.MultiByteToWideChar(sourceCodepage, 0, s, -1, nil, 0);
	local unicode = ffi.new("wchar_t[?]", unicodeLength)
	unicodeLength = win32.MultiByteToWideChar(sourceCodepage, 0, s, -1, unicode, unicodeLength);
	if (unicodeLength <= 0) then
		return
	end

	local mbLength = win32.WideCharToMultiByte(targetCodepage, 0, unicode, -1, nil, 0, nil, nil);
	local mb = ffi.new("char[?]", mbLength)
	mbLength = win32.WideCharToMultiByte(targetCodepage, 0, unicode, -1, mb, mbLength, nil, nil);
	if (mbLength <= 0) then
		return
	end
	return ffi.string(mb), mbLength
end

function UTF8ToNative(s)
	return Convert(65001, 0, s)
end

function NativeToUTF8(s)
	return Convert(0, 65001, s)
end

function Length(codepage, s)
	-- MultiByteToWideChar返回的是需要的长度，因此是包含了'\0‘的，这里只要-1就是正确长度了
	return win32.MultiByteToWideChar(codepage, 0, s, -1, nil, 0) - 1
end

function NativeLength(s)
	return Length(0, s)
end

local function Utf8Charbytes(s, i)
	-- argument defaults
	i = i or 1

	-- argument checking
	if type(s) ~= "string" then
		error("bad argument #1 to 'utf8charbytes' (string expected, got " .. type(s) .. ")")
	end
	if type(i) ~= "number" then
		error("bad argument #2 to 'utf8charbytes' (number expected, got " .. type(i) .. ")")
	end

	local c = s:byte(i)

	-- determine bytes needed for character, based on RFC 3629
	-- validate byte 1
	if c > 0 and c <= 127 then
		-- UTF8-1
		return 1

	elseif c >= 194 and c <= 223 then
		-- UTF8-2
		local c2 = s:byte(i + 1)

		if not c2 then
			return 0
		end

		-- validate byte 2
		if c2 < 128 or c2 > 191 then
			return 0
		end

		return 2

	elseif c >= 224 and c <= 239 then
		-- UTF8-3
		local c2 = s:byte(i + 1)
		local c3 = s:byte(i + 2)

		if not c2 or not c3 then
			return 0
		end

		-- validate byte 2
		if c == 224 and (c2 < 160 or c2 > 191) then
			return 0
		elseif c == 237 and (c2 < 128 or c2 > 159) then
			return 0
		elseif c2 < 128 or c2 > 191 then
			return 0
		end

		-- validate byte 3
		if c3 < 128 or c3 > 191 then
			return 0
		end

		return 3

	elseif c >= 240 and c <= 244 then
		-- UTF8-4
		local c2 = s:byte(i + 1)
		local c3 = s:byte(i + 2)
		local c4 = s:byte(i + 3)

		if not c2 or not c3 or not c4 then
			return 0
		end

		-- validate byte 2
		if c == 240 and (c2 < 144 or c2 > 191) then
			return 0
		elseif c == 244 and (c2 < 128 or c2 > 143) then
			return 0
		elseif c2 < 128 or c2 > 191 then
			return 0
		end

		-- validate byte 3
		if c3 < 128 or c3 > 191 then
			return 0
		end

		-- validate byte 4
		if c4 < 128 or c4 > 191 then
			return 0
		end

		return 4

	else
		return 0
	end
end

-- returns the number of characters in a UTF-8 string
function UTF8Length(s)
	-- argument checking
	if type(s) ~= "string" then
		error("bad argument #1 to 'utf8len' (string expected, got " .. type(s) .. ")")
	end

	local pos = 1
	local bytes = s:len()
	local len = 0

	while pos <= bytes do
		local c = s:byte(pos)
		len = len + 1

		local l = Utf8Charbytes(s, pos)
		-- Invalid UTF-8 character
		if (l <= 0) then
			return 0
		end
		pos = pos + Utf8Charbytes(s, pos)
	end

	return len
end

function IsUTF8(s)
	return UTF8Length(s) > 0
end

--按split分割source字符串为一个table
function Split(source, split)
	local tmp = source
	local table = {}
	local index = 1
	local pos
	while tmp ~= nil do
		pos = string.find(tmp, split)
		if (pos ~= nil) then
			if (pos ~= 1) then
				table[index] = string.sub(tmp, 1, pos - 1)
			end
			index = index + 1
			tmp = string.sub(tmp, pos + 1, string.len(tmp))
		else
			break
		end
	end

	if (tmp ~= nil and tmp ~= "") then
		table[index] = tmp
	end

	return table
end

function Format(parameter, ...)
	if (select("#", ...) > 0) then
		return string.format("%s\t%s", tostring(parameter), Format(...))
	else
		return tostring(parameter)
	end
end

function FindSystemPost(str, ...)
    local i = 1
    local count
    for _, v in ipairs({ ... }) do
        v = tostring(v)
		v = string.gsub(v, '%%', '%%%%')
        str, count = string.gsub(str, "&" .. tostring(i), v)
        if (count ~= 1) then
            error("第" .. tostring(i) .. "个参数出问题了")
        end
        i = i + 1
    end
    return str
end

function CreateMessageTable()
	local message = {}

	local function Append(...)
		if (select("#", ...) >= 1) then
			message[#message + 1] = string.format(...)
		end
	end

	local function GetString()
		return table.concat(message)
	end

	return {
		Append = Append,
		GetString = GetString,
	}
end

--处理类型skllDamageUp这种字段就可以用这个接口
function DealSplitFieldLikeSkillDamageUp(cfg, keyFieldName, valueFieldName, newFiledName, splitStr)
	if cfg[keyFieldName] and cfg[valueFieldName] then
		local keyIDs = Split(cfg[keyFieldName], splitStr)
		local values = Split(cfg[valueFieldName], splitStr)
		cfg[keyFieldName] = nil
		cfg[valueFieldName] = nil
		cfg[newFiledName] = {}

		if #keyIDs == #values and #keyIDs > 0 then
			local ID
			for i = 1, #keyIDs do
				ID = tonumber(keyIDs[i])
				cfg[newFiledName][ID] = cfg[newFiledName][ID] or 0
				cfg[newFiledName][ID] = cfg[newFiledName][ID] + tonumber(values[i])
			end
		end
	else
		cfg[keyFieldName] = nil
		cfg[valueFieldName] = nil
		cfg[newFiledName] = {}
	end
end


local byte = string.byte
local function is_cont(c, n)
	if not c or c < 128 or c > 191 then
		return
	end
	return true
end

function IsAlphabet(str)
	local cont
	local len = #str
	local i = 0
	while i < len do
		i = i + 1
		local c = byte(str, i)

		-- 可接受的ascii字符
		if not c or
				c < 48 or
				(c > 57 and c < 65) or
				(c > 90 and c < 97) or
				(c > 122 and c < 128) then
			return
		end

		-- utf 字符
		-- 双字符utf8, 一定不是中文
		--[[
		if c >= 194 and c <= 223 then
			i = i + 1
			cont = byte(str, i)
			if not is_cont(cont) then
				return
			end
		end
		]]

		-- 三字符utf8
		if c >= 224 and c <= 239 then
			i = i + 1
			cont = byte(str, i)
			if not is_cont(cont) then
				return
			end
			i = i + 1
			cont = byte(str, i)
			if not is_cont(cont) then
				return
			end
		end

		-- 四字符utf8
		if c >= 240 then
			i = i + 1
			cont = byte(str, i)
			if not is_cont(cont) then
				return
			end
			i = i + 1
			cont = byte(str, i)
			if not is_cont(cont) then
				return
			end
			i = i + 1
			cont = byte(str, i)
			if not is_cont(cont) then
				return
			end
		end
	end
	return true
end

--检测有效的字符数(非空格和非tab)
function CkeckEffectiveCharNum(str)
    local count = 0
    local len = #str
    local i = 0
    local byte = string.byte
    while i < len do
        i = i + 1
        local c = byte(str, i)
        if c ~= nil and c ~= 0x09 and c ~= 0x20 then
            count = count + 1
        end
    end
    return count
end
