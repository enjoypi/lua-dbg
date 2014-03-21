/*
** LuaProfiler
*/

/*****************************************************************************
lua50_profiler.c:
Lua version dependent profiler interface
*****************************************************************************/


#include "dict.h"

#include <lua.h>
#include <lauxlib.h>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>

typedef struct _profiler_info
{
	long long	last_call;
	long long	total_with_children;
	long long	total;
	long long	max;
	size_t		count;
	int			linedefined;
	const char*	source;
	char		name[32];
} profiler_info;
const size_t PROFILER_INFO_SIZE = sizeof(profiler_info);
#define PROFILER_INFO_ARRAY_SIZE (2048)
profiler_info profiler_info_array[PROFILER_INFO_ARRAY_SIZE];
size_t current_profiler_position = 0;
dict* profiler_dictionary = NULL;
int backtracking = 0;
FILE* profiler_log_file = NULL;
char tab[128];
size_t tab_amount = 0;
size_t write_line_amount = 0;

typedef enum breakpoint_type
{
	breakpoint_type_normal = 0,
	breakpoint_type_condition = 1,
	breakpoint_type_temp = 2,
} breakpoint_type;
typedef struct breakpoint_info
{
	int				type;					// 断点类型
	int				line;					// 断点行号
	char			file_name[192];			// 断点文件
	int				conditionFunction;		// 条件断点表达式函数
} breakpoint_info;
size_t breakpoint_info_size = sizeof(breakpoint_info);

int break_callback = 0;
breakpoint_type bp_type = breakpoint_type_normal;
dict* breakpoint_dictionary = NULL;


extern dictType dictTypeIntHash;

int initialize()
{
	if (breakpoint_dictionary == NULL)
	{
		breakpoint_dictionary = dictCreate(&dictTypeIntHash, NULL);
	}

	if (breakpoint_dictionary == NULL)
	{
		dictRelease(profiler_dictionary);
		profiler_dictionary = NULL;
		return -3;
	}

	memset(profiler_info_array, 0, sizeof(profiler_info_array));
	memset(tab, 0, sizeof(tab));

	//profiler_log_file = fopen("profiler.log", "w");

	return 0;
}

 const char* trim_path(const char* full_path)
{
	const char* left_file_name = NULL;
	const char* right_file_name = NULL;
	if (full_path == NULL)
	{
		return NULL;
	}

	// 需要处理路径中既有/又有\的情况。所以取最短值
	left_file_name =  strrchr(full_path, '/');
	right_file_name = strrchr(full_path, '\\');

	if (left_file_name != NULL && right_file_name == NULL)
	{
		return left_file_name + 1;
	}
	else if (left_file_name == NULL && right_file_name != NULL)
	{
		return right_file_name + 1;
	}
	else if (left_file_name != NULL && right_file_name != NULL)
	{
		if (strlen(left_file_name) <= strlen(right_file_name))
		{
			return left_file_name + 1;
		}
		else
		{
			return right_file_name + 1;
		}
	}

	return full_path;
}

int debugger_step_count = 0;
int debugger_next_count = 0;
int debugger_next_start_frame = 0;
int debugger_next_linedefined = 0;
char debugger_next_source[128] = { 0 };
lua_Debug last_breaked = {0};

 void do_break(lua_State* L, lua_Debug* ar)
{
	printf("进入断点\n");
	int n = lua_gettop(L);
	debugger_step_count = 0;
	debugger_next_count = 0;
	debugger_next_start_frame = 0;
	debugger_next_linedefined = 0;
	debugger_next_source[0] = '\0';
	memcpy(&last_breaked, ar, sizeof(last_breaked));

	lua_rawgeti(L, LUA_REGISTRYINDEX, break_callback);
	if (lua_type(L, -1) == LUA_TFUNCTION)
	{
		// 调用函数
		if (lua_pcall(L, lua_gettop(L) - 1 - n, LUA_MULTRET, 0))
		{
			printf("脚本执行错误，请检查脚本代码:%s\n", luaL_checkstring(L, -1));
		}
	}

	lua_pop(L, lua_gettop(L) - n);
}

 void hook_line(lua_State* L, lua_Debug* ar)
{
	dict* file_dictionary = NULL;

	if (L == NULL || ar == NULL)
	{
		return;
	}

	lua_getinfo(L, "Sn", ar);

	if (ar->currentline <= 0)
	{
		return;
	}

	if (debugger_step_count > 0)
	{
		// 避免总在同一行打转
		if (last_breaked.currentline != ar->currentline || last_breaked.source != ar->source)
		{
			--debugger_step_count;
			if (debugger_step_count <= 0)
			{
				do_break(L, ar);
				return;
			}
		}
	}

	if (debugger_next_count > 0)
	{
		// 避免总在同一行打转
		if (last_breaked.currentline != ar->currentline || last_breaked.source != ar->source)
		{
			lua_Debug caller;
			int frame = debugger_next_start_frame;
			int ok = 0;
			int be_checked = 0;
			int be_called = 0;

			// 检查整个栈判断是否走到当前函数内部
			while ((ok = lua_getstack(L, frame, &caller)) == 1 && lua_getinfo(L, "S", &caller))
			{
				be_checked = 1;
				if (debugger_next_linedefined == caller.linedefined && strcmp(debugger_next_source, caller.source) == 0)
				{
					be_called = 1;
					break;
				}
				++frame;
			}

			// 此时ok == 0，表示自己已经是顶层调用，next应该被取消
			if (be_checked == 0)
			{
				debugger_next_count = 0;
			}
			else
			{
				if (be_called == 0)
				{
					--debugger_next_count;
					debugger_next_linedefined = ar->linedefined;
					strncpy(debugger_next_source, ar->source, sizeof(debugger_next_source) - 1);
				}

				if (debugger_next_count <= 0)
				{
					do_break(L, ar);
					return;
				}
			}
		}

	}

	file_dictionary = dictFetchValue(breakpoint_dictionary, (const void*)ar->currentline);
	if (file_dictionary != NULL)
	{
		int needBreak = 0;
		const char* file_name = trim_path(ar->source);
		breakpoint_info* bp = dictFetchValue(file_dictionary, file_name);
		if (bp == NULL)
		{
			return;
		}

		if (bp->type & breakpoint_type_condition)
		{
			int n = lua_gettop(L);

			lua_rawgeti(L, LUA_REGISTRYINDEX, bp->conditionFunction);
			if (lua_type(L, -1) == LUA_TFUNCTION)
			{
				// 测试条件是否为true
				if (lua_pcall(L, lua_gettop(L) - 1 - n, LUA_MULTRET, 0) == 0)
				{
					int resultAmount = lua_gettop(L) - n;
					if (resultAmount > 0 && lua_type(L, -resultAmount) == LUA_TBOOLEAN)
					{
						if (lua_toboolean(L, -resultAmount))
						{
							needBreak = 1;
						}
					}
				}
			}

			lua_pop(L, lua_gettop(L) - n);
		}
		else
		{
			needBreak = 1;
		}

		// 释放临时断点
		if (bp->type & breakpoint_type_temp)
		{
			dictDelete(file_dictionary, file_name);
			luaL_unref(L, LUA_REGISTRYINDEX, bp->conditionFunction);
			free(bp);
		}

		if (needBreak)
		{
			do_break(L, ar);
		}

	}
}

/* called by Lua (via the callhook mechanism) */
 void hook(lua_State* L, lua_Debug* ar)
{
	if (ar->event == LUA_HOOKLINE)
	{
		hook_line(L, ar);
	}
}

 int debugger_start(lua_State* L)
{
	int hookmask = lua_gethookmask(L) | LUA_MASKLINE;
	lua_pushboolean(L, lua_sethook(L, hook, hookmask, 0));
	return 1;
}

 int debugger_stop(lua_State* L)
{
	int hookmask = lua_gethookmask(L) & ~LUA_MASKLINE;
	lua_pushboolean(L, lua_sethook(L, hook, hookmask, 0));
	return 1;
}

 int debugger_register_break_callback(lua_State* L)
{
	if (lua_type(L, -1) == LUA_TFUNCTION)
	{
		if (break_callback != 0)
		{
			luaL_unref(L, LUA_REGISTRYINDEX, break_callback);
		}
		break_callback = luaL_ref(L, LUA_REGISTRYINDEX);

		lua_pushboolean(L, 1);
	}
	else
	{
		lua_pushboolean(L, 0);
	}
	return 1;
}

 int debugger_set_breakpoint(lua_State* L)
{
	if (lua_type(L, 1) == LUA_TNUMBER && lua_type(L, 2) == LUA_TSTRING)
	{
		dict* linedefined_dictionary = NULL;

		int line = luaL_checkint(L, 1);
		const char* source = luaL_checkstring(L, 2);
		const char* file_name = trim_path(source);
		if (file_name == NULL)
		{
			lua_pushinteger(L, 0);
			return 1;
		}

		linedefined_dictionary = dictFetchValue(breakpoint_dictionary, &line);
		if (linedefined_dictionary == NULL)
		{
			linedefined_dictionary = dictCreate(&dictTypeHeapStringCopyKey, NULL);
			if (linedefined_dictionary == NULL || dictAdd(breakpoint_dictionary, &line, linedefined_dictionary) != DICT_OK)
			{
				lua_pushinteger(L, 0);
				return 1;
			}
		}

		if (dictFetchValue(linedefined_dictionary, file_name) == NULL)
		{
			breakpoint_info* bp = malloc(sizeof(breakpoint_info));
			if (bp == NULL)
			{
				lua_pushinteger(L, 0);
				return 1;
			}

			if (dictAdd(linedefined_dictionary, (void*)file_name,  bp) != DICT_OK)
			{
				free(bp);
				lua_pushinteger(L, 0);
				return 1;
			}

			memset(bp, 0, sizeof(*bp));

			if (lua_type(L, 3) == LUA_TSTRING)
			{
				const char* condition = lua_tostring(L, 3);

				if (luaL_loadstring(L, condition) == 0)
				{
					bp->type |= breakpoint_type_condition;
					bp->conditionFunction = luaL_ref(L, LUA_REGISTRYINDEX);
				}
				else
				{
					free(bp);
					lua_pushinteger(L, 0);
					return 1;
				}

			}

			if (lua_type(L, 4) == LUA_TBOOLEAN)
			{
				if (lua_toboolean(L, 4))
				{
					bp->type |= breakpoint_type_temp;
				}
			}

			bp->line = line;
			strncpy(bp->file_name, file_name, sizeof(bp->file_name) - 1);
		}

		lua_pushinteger(L, 1);
	}
	else
	{
		lua_pushinteger(L, 0);
	}
	return 1;
}

 int debugger_clear_breakpoint(lua_State* L)
{
	if (lua_type(L, 1) == LUA_TNUMBER && lua_type(L, 2) == LUA_TSTRING)
	{
		dict* linedefined_dictionary = NULL;

		int line = luaL_checkint(L, 1);
		const char* source = luaL_checkstring(L, 2);
		const char* file_name = trim_path(source);
		if (file_name != NULL)
		{
			linedefined_dictionary = dictFetchValue(breakpoint_dictionary, &line);
			if (linedefined_dictionary != NULL)
			{
				breakpoint_info* bp = dictFetchValue(linedefined_dictionary, file_name);
				if (bp != NULL)
				{
					dictDelete(linedefined_dictionary, file_name);
					luaL_unref(L, LUA_REGISTRYINDEX, bp->conditionFunction);
					free(bp);
					lua_pushinteger(L, 1);
					return 1;
				}
			}
		}

	}
	lua_pushinteger(L, 0);
	return 1;
}

 int debugger_step(lua_State* L)
{
	if (lua_type(L, 1) == LUA_TNUMBER)
	{
		debugger_step_count = luaL_checkint(L, 1);
	}
	else
	{
		debugger_step_count = 1;
	}

	lua_pushboolean(L, 1);
	return 1;
}

 int debugger_next_implment(lua_State* L, int count, int linedefined, const char* source, int start_frame)
{
	debugger_next_count = count;
	debugger_next_linedefined = linedefined;
	strncpy(debugger_next_source, source, sizeof(debugger_next_source) - 1);
	debugger_next_start_frame = start_frame;

	lua_pushboolean(L, 1);
	return 1;
}

 int debugger_next(lua_State* L)
{
	if (lua_type(L, 1) == LUA_TNUMBER && lua_type(L, 2) == LUA_TNUMBER && lua_type(L, 3) == LUA_TSTRING)
	{
		return debugger_next_implment(L, luaL_checkint(L, 1), luaL_checkint(L, 2), lua_tostring(L, 3), 1);
	}

	lua_pushboolean(L, 0);
	return 1;

}

 int debugger_finish(lua_State* L)
{
	if (lua_type(L, 1) == LUA_TNUMBER && lua_type(L, 2) == LUA_TSTRING)
	{
		return debugger_next_implment(L, 1, luaL_checkint(L, 1), lua_tostring(L, 2), 0);
	}

	lua_pushboolean(L, 0);
	return 1;

}

static const luaL_Reg debugger_funcs[] =
{
	{ "Start", debugger_start },
	{ "Stop", debugger_stop },
	{ "RegisterBreakCallback", debugger_register_break_callback },
	{ "SetBreakpoint", debugger_set_breakpoint },
	{ "ClearBreakpoint", debugger_clear_breakpoint },
	{ "Finish", debugger_finish },
	{ "Next", debugger_next },
	{ "Step", debugger_step },
	{ NULL, NULL }
};

int luaopen_debugger(lua_State* L)
{
	if (initialize() != 0)
	{
		return 0;
	}

	luaL_newlib(L, debugger_funcs);
	return 1;
}
