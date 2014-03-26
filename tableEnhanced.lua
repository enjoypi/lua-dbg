local require = require
local pairs = pairs
local ipairs = ipairs
local tostring = tostring
local table = table
local type = type
local string = string
local print = print or rawprint
local select = select
local Get2StringLastBy = Get2StringLastBy
local tonumber = tonumber
local next = next
local debug = require("debug")
local io = require("io")
local error = error

module(...)

--[[
   Author: Julio Manuel Fernandez-Diaz
   Date:   January 12, 2007
   (For Lua 5.1)

   Modified slightly by RiciLake to avoid the unnecessary table traversal in tablecount()

   Formats tables with cycles recursively to any depth.
   The output is returned as a string.
   References to other tables are shown as values.
   Self references are indicated.

   The string returned is "Lua code", which can be procesed
   (in the case in which indent is composed by spaces or "--").
   Userdata and function keys and values are shown as strings,
   which logically are exactly not equivalent to the original code.

   This routine can serve for pretty formating tables with
   proper indentations, apart from printing them:

	  print(table.show(t, "t"))   -- a typical use

   Heavily based on "Saving tables with cycles", PIL2, p. 113.

   Arguments:
	  t is the table.
	  name is the name of the table (optional)
	  indent is a first indentation (optional).
--]]
function ToString(t, name, indent, level)
	local cart -- a container
	local autoref -- for self references

	--[[ counts the number of elements in a table
	   local function tablecount(t)
		  local n = 0
		  for _, _ in pairs(t) do n = n+1 end
		  return n
	   end
	   ]]
	-- (RiciLake) returns true if the table is empty
	local function isemptytable(t) return next(t) == nil end

	local function basicSerialize(o)
		local so = tostring(o)
		if type(o) == "function" then
			local info = debug.getinfo(o, "S")
			-- info.name is nil because o is not a calling level
			if info.what == "C" then
				return string.format("%q", so .. ", C function")
			else
				-- the information is defined through lines
				return string.format("%q", so .. ", defined in (" ..
						info.linedefined .. "-" .. info.lastlinedefined ..
						")" .. info.source)
			end
		elseif type(o) == "number" or type(o) == "boolean" then
			return so
		else
			return string.format("%q", so)
		end
	end

	local function addtocart(value, name, indent, saved, field, level)
		indent = indent or ""
		saved = saved or {}
		field = field or name
		level = level or 1

		cart = cart .. indent .. field

		if type(value) ~= "table" then
			cart = cart .. " = " .. basicSerialize(value) .. ";\n"
		else
			if saved[value] then
				cart = cart .. " = {}; -- " .. saved[value]
						.. " (self reference)\n"
				autoref = autoref .. name .. " = " .. saved[value] .. ";\n"
			elseif level > 0 then
				saved[value] = name
				--if tablecount(value) == 0 then
				if isemptytable(value) then
					cart = cart .. " = {};\n"
				else
					cart = cart .. " = {\n"
					for k, v in pairs(value) do
						k = basicSerialize(k)
						local fname = string.format("%s[%s]", name, k)
						field = string.format("[%s]", k)
						-- three spaces between levels
						addtocart(v, fname, indent .. "   ", saved, field, level - 1)
					end
					cart = cart .. indent .. "};\n"
				end
			else
				cart = cart .. " = " .. basicSerialize(value) .. ";\n"
			end
		end
	end

	name = name or "__unnamed__"
	if type(t) ~= "table" then
		return name .. " = " .. basicSerialize(t)
	end
	cart, autoref = "", ""
	addtocart(t, name, indent, nil, nil, level)
	return cart .. autoref
end

function IsSubTable(bigTable, smallTable)
	if (type(bigTable) ~= "table" or type(smallTable) ~= "table") then
		return false
	end
	for k, v in pairs(smallTable) do
		local match = false
		local subV = bigTable[k]
		if (type(v) ~= "table") then
			match = (v == subV)
		elseif (type(subV) == "table") then
			match = IsSubTable(subV, v)
		end
		if (not match) then
			return false
		end
	end
	return true
end

function IsSubTableWithRelation(bigTable, smallTable, level)
	if (type(bigTable) ~= "table" or type(smallTable) ~= "table") then
		return false
	end
	level = level or 1
	for k, v in pairs(smallTable) do
		local match = false
		local relation = 1
		if (1 == level) then
			local realKey
			realKey, relation = Get2StringLastBy(k, "_")
			k = realKey or k
			relation = relation or 1
			relation = tonumber(relation)
			if (not relation or relation < 0 or relation > 2) then
				relation = 1
			end
		end
		local subV = bigTable[k]
		if (type(v) ~= "table") then
			if (type(v) ~= "number" or type(subV) ~= "number") then
				match = (v == subV)
			elseif (2 == relation) then
				match = (subV >= v)
			elseif (0 == relation) then
				match = (subV <= v)
			elseif (1 == relation) then
				match = (v == subV)
			else
				match = false
			end
		elseif (type(subV) == "table") then
			match = IsSubTableWithRelation(subV, v, level + 1)
		end
		if (not match) then
			return false
		end
	end
	return true
end

function GetTableRowNumber(t)
	if (type(t) ~= "table") then
		error("GetTableRowNumber wrong:", tostring(t), "is not table.", 2)
	end
	local n = 0
	for __, __ in pairs(t) do
		n = n + 1
	end
	return n
end

function IsSameValue(t1, t2)
	if (type(t1) ~= "table" or type(t2) ~= "table") then
		return false
	end

	if (GetTableRowNumber(t1) == 0 and GetTableRowNumber(t2) == 0) then
		return true
	end

	local match = false
	for k, v in pairs(t2) do
		local subV = t1[k]
		if (type(v) ~= "table") then
			match = (v == subV)
		elseif (type(subV) == "table") then
			match = IsSameValue(subV, v)
		end
		if (not match) then
			return false
		end
	end

	if (not match) then
		return false
	end

	for k, v in pairs(t1) do
		local subV = t2[k]
		if (type(v) ~= "table") then
			match = (v == subV)
		elseif (type(subV) == "table") then
			match = IsSameValue(subV, v)
		end
		if (not match) then
			return false
		end
	end
	return true
end

--[[
返回一个src的深拷贝，不论src是否是pb::message，返回值都为一个lua table，其中包含pb定义的默认值。
包括空数组版本   空数组转化为{}  不适用于写数据库操作
--]]
function DeepCopyEx(src)
	local function _copy(object)
		local new_table = {}
		for key, value in pairs(object) do
			if (type(value) == "table" and value._parent_message ~= nil) then
				--protobuf array
				local des = {}
				new_table[key] = des
				for i = 1, #(value) do
					local v = value[i]
					if type(v) == "table" then
						table.insert(des, _copy(v))
					else
						table.insert(des, v)
					end
				end
			elseif type(value) == "table" then
				new_table[key] = _copy(value)
			else
				new_table[key] = value
			end
		end
		return new_table
	end

	return _copy(src)
end

function DeepCopyExToDst(dst, src)
	local function _copy(dst, src)
		--local new_table = {}
		for key, value in pairs(src) do
			if (type(value) == "table" and value._parent_message ~= nil) then
				--protobuf array
				local des = {}
				dst[key] = des
				for i = 1, #(value) do
					local v = value[i]
					if type(v) == "table" then
						local tmp = {}
						_copy(tmp, v)
						table.insert(des, tmp)
					else
						table.insert(des, v)
					end
				end
			elseif type(value) == "table" then
				dst[key] = {}
				_copy(dst[key], value)
			else
				dst[key] = value
			end
		end
	end

	_copy(dst, src)
end

--[[
返回一个src的深拷贝，不论src是否是pb::message，返回值都为一个lua table，其中包含pb定义的默认值。
不包括空数组版本
--]]
function DeepCopy(src)
	local function _copy(object)
		local new_table = {}
		for key, value in pairs(object) do
			if (type(value) == "table" and value._parent_message ~= nil) then
				--protobuf array
				local des = {}
				new_table[key] = des
				local size = #(value)
				if size == 0 then
					new_table[key] = nil
				else
					for i = 1, size do
						local v = value[i]
						if type(v) == "table" then
							table.insert(des, _copy(v))
						else
							table.insert(des, v)
						end
					end
				end
			elseif type(value) == "table" then
				new_table[key] = _copy(value)
			else
				new_table[key] = value
			end
		end
		return new_table
	end

	return _copy(src)
end

function DeepCopyToDst(dst, src)
	local function _copy(dst, src)
		for key, value in pairs(src) do
			if (type(value) == "table" and value._parent_message ~= nil) then
				local des = {}
				dst[key] = des
				local size = #(value)
				if size == 0 then
					dst[key] = nil
				else
					for i = 1, size do
						local v = value[i]
						if type(v) == "table" then
							local tmp = {}
							_copy(tmp, v)
							table.insert(des, tmp)
						else
							table.insert(des, v)
						end
					end
				end
			elseif type(value) == "table" then
				dst[key] = {}
				_copy(dst[key], value)
			else
				dst[key] = value
			end
		end
	end

	_copy(dst, src)
end

local function valueTable() end

function AssignTable(t, value, key1, ...)
	if (key1 == nil) then
		t[valueTable] = t[valueTable] or {}
		t[valueTable][#t[valueTable] + 1] = value
		return
	end

	t[key1] = t[key1] or {}
	return AssignTable(t[key1], value, ...)
end

function AccessTable(t, key, ...)
	if (type(t) ~= "table" or key == nil) then
		return
	end

	if (t[key] ~= nil and t[key][valueTable] ~= nil) then
		local valueAmount = #t[key][valueTable]
		if (valueAmount > 0 and AccessTable(t[key], ...) == nil) then
			if (valueAmount == 1) then
				return t[key][valueTable][1]
			elseif (valueAmount > 1) then
				return t[key][valueTable]
			end
		end
	end

	if (select("#", ...) <= 0) then
		return
	end

	return AccessTable(t[key], ...)
end

function AbsoluteAccessTable(t, key, ...)
	if (type(t) ~= "table" or key == nil) then
		return
	end

	if (select("#", ...) <= 0) then
		if (t[key] == nil or t[key][valueTable] == nil) then
			return
		end
		local valueAmount = #t[key][valueTable]
		if (valueAmount == 1) then
			return t[key][valueTable][1]
		elseif (valueAmount > 1) then
			return t[key][valueTable]
		end
		return
	end

	return AbsoluteAccessTable(t[key], ...)
end

function Find(t, key, ...)
	local v = t[key]
	if (v ~= nil) then
		if (select("#", ...) > 0) then
			return Find(v, ...)
		else
			return v
		end
	end
end

function Assign(t, value, key, ...)
	if (select("#", key, ...) <= 0) then
		return false
	end

	if (select("#", ...) <= 0) then
		t[key] = value
		return true
	elseif (select("#", key, ...) > 0) then
		local leaf = t[key]
		if (type(leaf) == "table") then
			return Assign(leaf, value, ...)
		elseif (leaf == nil) then
			t[key] = {}
			return Assign(t[key], value, ...)
		else
			return false
		end
	end
end


function DumpToFile(t, name, indent, level)
	local f = io.open(name .. ".txt", "w")
	if (f == nil) then
		error("can't open " .. name .. ".txt")
	end

	local cart -- a container
	local autoref -- for self references

	--[[ counts the number of elements in a table
	   local function tablecount(t)
		  local n = 0
		  for _, _ in pairs(t) do n = n+1 end
		  return n
	   end
	   ]]
	-- (RiciLake) returns true if the table is empty
	local function isemptytable(t) return next(t) == nil end

	local function basicSerialize(o)
		local so = tostring(o)
		if type(o) == "function" then
			local info = debug.getinfo(o, "S")
			-- info.name is nil because o is not a calling level
			if info.what == "C" then
				return string.format("%q", so .. ", C function")
			else
				-- the information is defined through lines
				return string.format("%q", so .. ", defined in (" ..
						info.linedefined .. "-" .. info.lastlinedefined ..
						")" .. info.source)
			end
		elseif type(o) == "number" or type(o) == "boolean" then
			return so
		else
			return string.format("%q", so)
		end
	end

	local function addtocart(value, name, indent, saved, field, level)
		indent = indent or ""
		saved = saved or {}
		field = field or name
		level = level or 1

		f:write(indent .. field)

		if type(value) ~= "table" then
			if type(value) == "function" then
				f:write(" = " .. basicSerialize(value))
				local i = 1
				local k, v = debug.getupvalue(value, i)
				if (k == nil) then
					f:write(";\n")
				else
					f:write(" upvalues = {\n")
					while k ~= nil do
						if (type(v) ~= "function") then
							k = basicSerialize(k)
							local fname = string.format("%s[%s]", name, k)
							field = string.format("[%s]", k)
							-- three spaces between levels
							addtocart(v, fname, indent .. "\t", saved, field, level - 1)
						end
						i = i + 1
						k, v = debug.getupvalue(value, i)
					end
					f:write(indent .. "};\n")
				end
				saved[value] = name
			else
				f:write(" = " .. basicSerialize(value) .. ";\n")
			end
		else
			if saved[value] then
				f:write(" = {}; -- " .. saved[value] .. " (self reference)\n")
				autoref = autoref .. name .. " = " .. saved[value] .. ";\n"
			elseif level > 0 then
				saved[value] = name
				--if tablecount(value) == 0 then
				if isemptytable(value) then
					f:write(" = {};\n")
				else
					f:write(" = {\n")
					for k, v in pairs(value) do
						k = basicSerialize(k)
						local fname = string.format("%s[%s]", name, k)
						field = string.format("[%s]", k)
						-- three spaces between levels
						addtocart(v, fname, indent .. "\t", saved, field, level - 1)
					end
					f:write(indent .. "};\n")
				end
			else
				f:write(" = " .. basicSerialize(value) .. ";\n")
			end
		end
	end

	name = name or "__unnamed__"
	if type(t) ~= "table" then
		return name .. " = " .. basicSerialize(t)
	end
	cart, autoref = "", ""

	addtocart(t, name, indent, nil, nil, level)
	f:write(autoref)
	f:close()
end

--- 对数组 array i ~ j 以关键字key为访问标志做一次快排 从大到小
--- 请确保array i ~ j 为数组， 并有关键字 key并且对应的value可以是可比较的 , 本函数不做任何非法性检测
function QuickSort(array, i, j, key)
	if not key then return end
	if i >= j then return end
	if type(array) ~= "table" then return end
	local l, r = i, j
	local value = array[l]
	while l < r do
		while array[r][key] <= value[key] do
			r = r - 1
			if l >= r then
				break
			end
		end
		if l < r then
			array[l] = array[r]
			l = l + 1
			if l >= r then
				break
			end
		else
			break
		end

		while array[l][key] >= value[key] do
			l = l + 1
			if l >= r then
				break
			end
		end
		if l < r then
			array[r] = array[l]
			r = r - 1
			if l >= r then
				break
			end
		end
	end
	array[l] = value
	QuickSort(array, i, l - 1, key)
	QuickSort(array, l + 1, j, key)
end

--- 对数组 array 按关键字 keys 从大到小排序
--- 如果一级关键字对应的值相等 按二级排序 。。。 以此类推
--- 请确保数组 array 中的table有相应的所有key, 对应的value也是可比较的。 这里不错任何非法性检测
function MultiSort(array, keys)
	--- 别的函数也用不了所以就放在这里了
	local function _MultiSort(array, i, j, keys, index)
		if keys[index] and i < j then
			local l, r = i, i
			local value = array[i][keys[index]]
			for k = i, j do
				if array[k][keys[index]] == value then
					r = k
				else
					if l ~= r then
						QuickSort(array, l, r, keys[index + 1])
						_MultiSort(array, l, r, keys, index + 1)
					end
					l = k
					r = k
					value = array[k][keys[index]]
				end
			end
			if l ~= r then
				QuickSort(array, l, r, keys[index + 1])
				_MultiSort(array, l, r, keys, index + 1)
			end
		end
	end

	if type(array) == "table" and type(keys) == "table" then
		QuickSort(array, 1, #array, keys[1])
		_MultiSort(array, 1, #array, keys, 1)
	end
end
