local _G = _G
local loadstring = loadstring

local require = require
local tonumber = tonumber
local string = require("string")
local io = require("io")
local debug = require("debug")
local coroutineEnhanced = require("coroutineEnhanced")
local stringEnhanced = require("stringEnhanced")
local package = package
local LUA_PATH = LUA_PATH
local pairs = pairs
local unpack = unpack
local table = require("table")
local select = select
local type = type
local pcall = pcall
local tostring = tostring
local collectgarbage = collectgarbage
local tableEnhanced = require("tableEnhanced")
local os = require("os")

local dbg = require("dbg")

module(...)

local hints = {
	["advance"] = {
		brief = "Continue the program up to the given location (same form as args for break command).",
		detail = [[
Usage: advance
Execution will also stop upon exit from the current stack frame.
]],
	},
	["backtrace"] = {
		brief = "Print backtrace of all stack frames, or innermost COUNT frames.",
		detail = [[
Usage: backtrace [full]
backtrace
bt
	Print a backtrace of the entire stack: one line per frame for all frames in the stack.

backtrace full
bt full
	Print the values of the local variables also.

With a negative argument, print outermost -COUNT frames.
Use of the 'full' qualifier also prints the values of the local variables.
]],
	},
	["break"] = {
		brief = "Set breakpoint at specified line or function.",
		detail = [[
Usage: break [LOCATION] [if CONDITION]
LOCATION may be a line number, function name.
If a line number is specified, break at start of code for that line.
If a function is specified, break at start of code for that function.
If an address is specified, break at that exact address.
With no LOCATION, uses current execution address of the selected
stack frame.  This is useful for breaking on return to a stack frame.

THREADNUM is the number from "info threads".
CONDITION is a boolean expression.

break location
	Set a breakpoint at the given location, which can specify a function name, a line number, or an address of an instruction. (See Specify Location, for a list of all the possible ways to specify a location.) The breakpoint will stop your program just before it executes any of the code in the specified location.
	When using source languages that permit overloading of symbols, such as C++, a function name may refer to more than one possible place to break. See Ambiguous Expressions, for a discussion of that situation.

	It is also possible to insert a breakpoint that will stop the program only if a specific thread (see Thread-Specific Breakpoints) or a specific task (see Ada Tasks) hits that breakpoint.

break ... if cond
	Set a breakpoint with condition cond; evaluate the expression cond each time the breakpoint is reached, and stop only if the value is nonzero—that is, if cond evaluates as true. `...' stands for one of the possible arguments described above (or no argument) specifying where to break. See Break Conditions, for more information on breakpoint conditions.
]]
	},
	["cd"] = {
		brief = "Set working directory to DIR for dbg and program being debugged.",
		detail = [[
Usage: cd DIRECTORY
cd directory
	Set the gdb working directory to directory.

The change does not take effect for the program being debugged
until the next time it is started.
]],
	},
	["clear"] = {
		brief = "Clear breakpoint at specified line or function.",
		detail = [[
Usage: clear [LOCATION]
clear
	Delete any breakpoints at the next instruction to be executed in the selected stack frame (see Selecting a Frame). When the innermost frame is selected, this is a good way to delete a breakpoint where your program just stopped.

clear location
	Delete any breakpoints set at the specified location. See Specify Location, for the various forms of location; the most useful ones are listed below:
	clear function
	clear filename:function
		Delete any breakpoints set at entry to the named function.
	clear linenum
	clear filename:linenum
		Delete any breakpoints set at or within the code of the specified linenum of the specified filename.

Argument may be line number, function name, or "*" and an address.
If line number is specified, all breakpoints in that line are cleared.
If function is specified, breakpoints at beginning of function are cleared.
If an address is specified, breakpoints at that address are cleared.

With no argument, clears all breakpoints in the line that the selected frame
is executing in.

See also the "delete" command which clears breakpoints by number.
]],
	},
	["condition"] = {
		brief = "Specify breakpoint number N to break only if COND is true.",
		detail = [[
Usage: condition N [COND]
condition bnum expression
	Specify expression as the break condition for breakpoint, watchpoint, or catchpoint number bnum. After you set a condition, breakpoint bnum stops your program only if the value of expression is true (nonzero, in C). When you use condition, gdb checks expression immediately for syntactic correctness, and to determine whether symbols in it have referents in the context of your breakpoint. If expression uses symbols not referenced in the context of the breakpoint, gdb prints an error message:
			  No symbol "foo" in current context.

	gdb does not actually evaluate expression at the time the condition command (or a command that sets a breakpoint with a condition, like break if ...) is given, however. See Expressions.

condition bnum
	Remove the condition from breakpoint number bnum. It becomes an ordinary unconditional breakpoint.

Usage is `condition N COND', where N is an integer and COND is an
expression to be evaluated whenever breakpoint N is reached.
]],
	},
	["continue"] = {
		brief = "Continue program being debugged, after signal or breakpoint.",
		detail = [[
Usage: continue [N]
continue [ignore-count]
c [ignore-count]
	Resume program execution, at the address where your program last stopped; any breakpoints set at that address are bypassed. The optional argument ignore-count allows you to specify a further number of times to ignore a breakpoint at this location; its effect is like that of ignore (see Break Conditions).
	The argument ignore-count is meaningful only when your program stopped due to a breakpoint. At other times, the argument to continue is ignored.


If proceeding from breakpoint, a number N may be used as an argument,
which means to set the ignore count of that breakpoint to N - 1 (so that
the breakpoint won't break until the Nth time it is reached).

If non-stop mode is enabled, continue only the current thread,
otherwise all the threads in the program are continued.  To
continue all stopped threads in non-stop mode, use the -a option.
Specifying -a and an ignore count simultaneously is an error.
]],
	},
	["delete"] = {
		brief = "Delete some breakpoints or auto-display expressions.",
		detail = [[
Usage: delete [RANGE...]
delete [breakpoints] [range...]
	Delete the breakpoints, watchpoints, or catchpoints of the breakpoint ranges specified as arguments. If no argument is specified, delete all breakpoints (gdb asks confirmation, unless you have set confirm off). You can abbreviate this command as d.


Arguments are breakpoint numbers with spaces in between.
To delete all breakpoints, give no argument.

List of delete subcommands:

delete display -- Cancel some expressions to be displayed when program stops

delete display
Cancel some expressions to be displayed when program stops.
Arguments are the code numbers of the expressions to stop displaying.
No argument means cancel all automatic-display expressions.
Do "info display" to see current list of code numbers.
]],
	},
	["disable"] = {
		brief = "Disable some breakpoints.",
		detail = [[
Usage: disable [RANGE...]
disable [breakpoints] [range...]
	Disable the specified breakpoints—or all breakpoints, if none are listed. A disabled breakpoint has no effect but is not forgotten. All options such as ignore-counts, conditions and commands are remembered in case the breakpoint is enabled again later. You may abbreviate disable as dis.

Arguments are breakpoint numbers with spaces in between.
To disable all breakpoints, give no argument.
A disabled breakpoint is not forgotten, but has no effect until re-enabled.
]],
	},
	["display"] = {
		brief = "Print value of expression EXP each time the program stops.",
		detail = [[
Usage: display [EXP]

With no argument, display all currently requested auto-display expressions.
Use "undisplay" to cancel display requests previously made.
]],
	},
	["down"] = {
		brief = "Select and print stack frame called by this one.",
		detail = [[
Usage: down [N]
down n
	Move n frames down the stack. For positive numbers n, this advances toward the innermost frame, to lower frame numbers, to frames that were created more recently. n defaults to one. You may abbreviate down as do.

An argument says how many frames down to go.
]],
	},

	--enable [breakpoints] once range...
	--	Enable the specified breakpoints temporarily. gdb disables any of these breakpoints immediately after stopping your program.
	--
	--enable [breakpoints] delete range...
	--	Enable the specified breakpoints to work once, then die. gdb deletes any of these breakpoints as soon as your program stops there. Breakpoints set by the tbreak command start out in this state.
	["enable"] = {
		brief = "Enable some breakpoints.",
		detail = [[
Usage: enable [RANGE...]
enable [breakpoints] [range...]
	Enable the specified breakpoints (or all defined breakpoints). They become effective once again in stopping your program.

Give breakpoint numbers (separated by spaces) as arguments.
With no subcommand, breakpoints are enabled until you command otherwise.
This is used to cancel the effect of the "disable" command.
With a subcommand you can enable temporarily.

List of enable subcommands:

enable display -- Enable some expressions to be displayed when program stops

enable display
Enable some expressions to be displayed when program stops.
Arguments are the code numbers of the expressions to resume displaying.
No argument means enable all automatic-display expressions.
Do "info display" to see current list of code numbers.
]],
	},
	["finish"] = {
		brief = "Execute until selected stack frame returns.",
		detail = [[
Usage: finish
finish
fin
	Continue running until just after function in the selected stack frame returns. Print the returned value (if any). This command can be abbreviated as fin.
	Contrast this with the return command (see Returning from a Function).

Upon return, the value returned is printed and put in the value history.
]],
	},
	["frame"] = {
		brief = "Select and print a stack frame.",
		detail = [[
Usage: frame [N]
frame
f
When used without any argument, this command does not change which frame is selected, but prints a brief description of the currently selected stack frame. It can be abbreviated f. With an argument, this command is used to select a stack frame. See Selecting a Frame.

frame n
f n
	Select frame number n. Recall that frame zero is the innermost (currently executing) frame, frame one is the frame that called the innermost one, and so on. The highest-numbered frame is the one for main.

With no argument, print the selected stack frame.  (See also "info frame").
An argument specifies the frame to select.
It can be a stack frame number or the address of the frame.
With argument, nothing is printed if input is coming from
a command file or a user-defined command.
]],
	},
	["help"] = {
		brief = "List of all commands.",
		detail = [[
Usage: help [COMMAND]
Type "help" followed by command name for full documentation.
Command name abbreviations are allowed if unambiguous.
]],
	},
	["ignore"] = {
		brief = "Set ignore-count of breakpoint number N to COUNT.",
		detail = [[
Usage: ignore [N] [COUNT]
Usage is `ignore N COUNT'.
]]
	},
	["info"] = {
		brief = "Generic command for showing things about the program being debugged.",
		detail = [[
Usage: info [LOCATION] [if CONDITION]
info watchpoints [n...]
	This command prints a list of watchpoints, using the same format as info break (see Set Breaks).
info frame
info f
	This command prints a verbose description of the selected stack frame, including:
	the address of the frame
	the address of the next frame down (called by this frame)
	the address of the next frame up (caller of this frame)
	the language in which the source code corresponding to this frame is written
	the address of the frame's arguments
	the address of the frame's local variables
	The verbose description is useful when something has gone wrong that has made the stack format fail to fit the usual conventions.

info upvalues
info u
	Print the arguments of the selected frame, each on a separate line.

info locals
info l
	Print the local variables of the selected frame, each on a separate line. These are all variables (declared either static or automatic) accessible at the point of execution of the selected frame.

List of info subcommands:

info address -- Describe where symbol SYM is stored
info all-registers -- List of all registers and their contents
info args -- Argument variables of current stack frame
info auxv -- Display the inferior's auxiliary vector
info bookmarks -- Status of user-settable bookmarks
info breakpoints -- Status of specified breakpoints (all user-settable breakpoints if no argument)
info catch -- Exceptions that can be caught in the current stack frame
info classes -- All Objective-C classes
info common -- Print out the values contained in a Fortran COMMON block
info copying -- Conditions for redistributing copies of GDB
info dcache -- Print information on the dcache performance
info definitions -- Show all definitions of MACRO in the current compilation unit
info display -- Expressions to display when program stops
info extensions -- All filename extensions associated with a source language
info files -- Names of targets and files being debugged
info float -- Print the status of the floating point unit
info frame -- All about selected stack frame
info functions -- All function names
info handle -- What dbg does when program gets various signals
info inferiors -- IDs of specified inferiors (all inferiors if no argument)
info line -- Core addresses of the code for a source line
info locals -- Local variables of current stack frame
info macro -- Show the definition of MACRO
info macros -- Show the definitions of all macros at LINESPEC
info mem -- Memory region attributes
info os -- Show OS data ARG
info program -- Execution status of the program
info record -- Info record options
info registers -- List of integer registers and their contents
info scope -- List the variables local to a scope
info selectors -- All Objective-C selectors
info set -- Show all GDB settings
info sharedlibrary -- Status of loaded shared object libraries
info signals -- What dbg does when program gets various signals
info source -- Information about the current source file
info sources -- Source files in the program
info stack -- Backtrace of the stack
info static-tracepoint-markers -- List target static tracepoints markers
info symbol -- Describe what symbol is at location ADDR
info target -- Names of targets and files being debugged
info tasks -- Provide information about all known Ada tasks
info terminal -- Print inferior's saved terminal status
info threads -- Display currently known threads
info tracepoints -- Status of specified tracepoints (all tracepoints if no argument)
info tvariables -- Status of trace state variables and their values
info types -- All type names
info variables -- All global and static variable names
info vector -- Print the status of the vector unit
info w32 -- Print information specific to Win32 debugging
info warranty -- Various kinds of warranty you do not have
info watchpoints -- Status of specified watchpoints (all watchpoints if no argument)
info win -- List of all displayed windows

Type "help info" followed by info subcommand name for full documentation.
Type "apropos word" to search for commands related to "word".
Command name abbreviations are allowed if unambiguous.


(gdb) help info args
Argument variables of current stack frame.

(gdb) help info breakpoints
Status of specified breakpoints (all user-settable breakpoints if no argument).
The "Type" column indicates one of:
		breakpoint     - normal breakpoint
		watchpoint     - watchpoint
The "Disp" column contains one of "keep", "del", or "dis" to indicate
the disposition of the breakpoint after it gets hit.  "dis" means that the
breakpoint will be disabled.  The "Address" and "What" columns indicate the
address and file/line number respectively.

Convenience variable "$_" and default examine address for "x"
are set to the address of the last breakpoint listed unless the command
is prefixed with "server ".

Convenience variable "$bpnum" contains the number of the last
breakpoint set.

(gdb) info breakpoints
Num     Type           Disp Enb Address    What
1       breakpoint     keep y   0x0040117e in main at t.c:5
		breakpoint already hit 1 time


(gdb) info display
Auto-display expressions now in effect:
Num Enb Expression
1:   y  i

(gdb) info source
Current source file is t.c
Compilation directory is /cygdrive/d/myRepo/temp
Located in /cygdrive/d/myRepo/temp/t.c
Contains 8 lines.
Source language is c.
Compiled with DWARF 2 debugging format.
Does not include preprocessor macro info.
]],
	},
	["list"] = {
		brief = "List specified function or line.",
		detail = [[
Usage: list [LINES]
list linenum
	Print lines centered around line number linenum in the current source file.

list function
	Print lines centered around the beginning of function function.

list
	Print more lines. If the last lines printed were printed with a list command, this prints lines following the last lines printed; however, if the last line printed was a solitary line printed as part of displaying a stack frame (see Examining the Stack), this prints lines centered around that line.

list -
	Print lines just before the lines last printed.

list linespec
	Print lines centered around the line specified by linespec.

list first,last
	Print lines from first to last. Both arguments are linespecs. When a list command has two linespecs, and the source file of the second linespec is omitted, this refers to the same source file as the first linespec.

list ,last
	Print lines ending with last.

list first,
	Print lines starting with first.

list +
	Print lines just after the lines last printed.

list -
	Print lines just before the lines last printed.

list
	As described in the preceding table.

With no argument, lists ten more lines after or around previous listing.
"list -" lists the ten lines before a previous ten-line listing.
One argument specifies a line, and ten lines are listed around that line.
Two arguments with comma between specify starting and ending lines to list.
Lines can be specified in these ways:
  LINENUM, to list around that line in current file,
  FILE:LINENUM, to list around that line in that file,
  FUNCTION, to list around beginning of that function,
  FILE:FUNCTION, to distinguish among like-named static functions.
  *ADDRESS, to list around the line containing that address.
With two args if one is empty it stands for ten lines away from the other arg.
]],
	},
	["next"] = {
		brief = "Step program, proceeding through subroutine calls.",
		detail = [[
Usage: next [N]
next [count]
n
	Continue to the next source line in the current (innermost) stack frame. This is similar to step, but function calls that appear within the line of code are executed without stopping. Execution stops when control reaches a different line of code at the original stack level that was executing when you gave the next command. This command is abbreviated n.
	An argument count is a repeat count, as for step.

	The next command only stops at the first instruction of a source line. This prevents multiple stops that could otherwise occur in switch statements, for loops, etc.

Like the "step" command as long as subroutine calls do not happen;
when they do, the call is treated as one instruction.
Argument N means do this N times (or till program stops for another reason).


(gdb) n
6               printf("Hello world!");
1: i = 1000
]],
	},
	["print"] = {
		brief = "Print value of expression EXP.",
		detail = [[
Usage: print [EXPRESSION]
print expr
p
	expr is an expression (in the source language). By default the value of expr is printed in a format appropriate to its data type; you can choose a different format by specifying `/f', where f is a letter specifying the format; see Output Formats.

print
	If you omit expr, gdb displays the last value again (from the value history; see Value History). This allows you to conveniently inspect the same value in an alternative format.

Variables accessible are those of the lexical environment of the selected
stack frame, plus all those whose scope is global or an entire file.

$NUM gets previous value number NUM.  $ and $$ are the last two values.
$$NUM refers to NUM'th value back from the last one.
Names starting with $ refer to registers (with the values they would have
if the program were to return to the stack frame now selected, restoring
all registers saved by frames farther in) or else to dbg
"convenience" variables (any such name not a known register).
Use assignment expressions to give values to convenience variables.

{TYPE}ADREXP refers to a datum of data type TYPE, located at address ADREXP.
@ is a binary operator for treating consecutive data objects
anywhere in memory as an array.  FOO@NUM gives an array whose first
element is FOO, whose second element is stored in the space following
where FOO is stored, etc.  FOO must be an expression whose value
resides in memory.

EXP may be preceded with /FMT, where FMT is a format letter
but no count or size letter (see "x" command).
]],
	},
	["pwd"] = {
		brief = "Print working directory.  This is used for your program as well.",
		detail = [[
Usage: pwd
]],
	},
	["quit"] = {
		brief = "Exit gdb.",
		detail = [[
Usage: quit
]],
	},
	["save"] = {
		brief = "Save breakpoint definitions as a script.",
		detail = [[
Usage: save [FILENAME]
	This command saves all current breakpoint definitions together with their commands and ignore counts, into a file filename suitable for use in a later debugging session. This includes all types of breakpoints (breakpoints, watchpoints, catchpoints, tracepoints). To read the saved breakpoint definitions, use the source command (see Command Files). Note that watchpoints with expressions involving local variables may fail to be recreated because it may not be possible to access the context where the watchpoint is valid anymore. Because the saved breakpoint definitions are simply a sequence of gdb commands that recreate the breakpoints, you can edit the file in your favorite editing program, and remove the breakpoint definitions you're not interested in, or that can no longer be recreated.

Save current breakpoint definitions as a script.
This includes all types of breakpoints (breakpoints, watchpoints,
catchpoints, tracepoints).  Use the 'source' command in another debug
session to restore them.
]],
	},
	["source"] = {
		brief = "Read commands from a file named FILE.",
		detail = [[
Usage: source [-s] [-v] FILE
-s: search for the script in the source search path,
	even if FILE contains directories.
-v: each command in FILE is echoed as it is executed.

Note that the file ".ldbinit" is read automatically in this way
when GDB is started.
]],
	},
	["step"] = {
		brief = "Step program until it reaches a different source line.",
		detail = [[
Usage: step [N]
step
s
	Continue running your program until control reaches a different source line, then stop it and return control to gdb. This command is abbreviated s.

step count
	Continue running as in step, but do so count times. If a breakpoint is reached, or a signal not related to stepping occurs before count steps, stepping stops right away.

Argument N means do this N times (or till program stops for another reason).
]],
	},
	["tbreak"] = {
		brief = "Set a temporary breakpoint.",
		detail = [[
Usage: tbreak [LOCATION] [if CONDITION]
Like "break" except the breakpoint is only temporary,
so it will be deleted when hit.  Equivalent to "break" followed
by using "enable delete" on the breakpoint number.

tbreak [LOCATION] [thread THREADNUM] [if CONDITION]
LOCATION may be a line number, function name, or "*" and an address.
If a line number is specified, break at start of code for that line.
If a function is specified, break at start of code for that function.
If an address is specified, break at that exact address.
With no LOCATION, uses current execution address of the selected
stack frame.  This is useful for breaking on return to a stack frame.

THREADNUM is the number from "info threads".
CONDITION is a boolean expression.

Multiple breakpoints at one place are permitted, and useful if their
conditions are different.

Do "help breakpoints" for info on other commands dealing with breakpoints.
]],
	},
	["until"] = {
		brief = "Execute until the program reaches a source line greater than the current",
		detail = [[
Usage: until [LOCATION]
until
u
	Continue running until a source line past the current line, in the current stack frame, is reached. This command is used to avoid single stepping through a loop more than once. It is like the next command, except that when until encounters a jump, it automatically continues execution until the program counter is greater than the address of the jump.
	This means that when you reach the end of a loop after single stepping though it, until makes your program continue execution until it exits the loop. In contrast, a next command at the end of a loop simply steps back to the beginning of the loop, which forces you to step through the next iteration.

	until always stops your program if it attempts to exit the current stack frame.

	until with no argument works by means of single instruction stepping, and hence is slower than until with an argument.


until location
u location
	Continue running your program until either the specified location is reached, or the current stack frame returns. location is any of the forms described in Specify Location. This form of the command uses temporary breakpoints, and hence is quicker than until without an argument. The specified location is actually reached only if it is in the current frame. This implies that until can be used to skip over recursive function invocations. For instance in the code below, if the current location is line 96, issuing until 99 will execute the program up to line 99 in the same invocation of factorial, i.e., after the inner invocations have returned.
			  94	int factorial (int value)
			  95	{
			  96	    if (value > 1) {
			  97            value *= factorial (value - 1);
			  98	    }
			  99	    return (value);
			  100     }

or a specified location (same args as break command) within the current frame.
]],
	},
	["undisplay"] = {
		brief = "Cancel some expressions to be displayed when program stops.",
		detail = [[
Usage: undisplay [N]
Arguments are the code numbers of the expressions to stop displaying.
No argument means cancel all automatic-display expressions.
Do "info display" to see current list of code numbers.
]],
	},
	["up"] = {
		brief = "Select and print stack frame that called this one.",
		detail = [[
Usage: up [N]
up n
	Move n frames up the stack. For positive numbers n, this advances toward the outermost frame, to higher frame numbers, to frames that have existed longer. n defaults to one.

An argument says how many frames up to go.
]],
	},
	["watch"] = {
		brief = "Set a watchpoint for an expression.",
		detail = [[
Usage: watch EXPRESSION
watch [-l|-location] expr [thread threadnum]
	Set a watchpoint for an expression. gdb will break when the expression expr is written into by the program and its value changes. The simplest (and the most popular) use of this command is to watch the value of a single variable:
			  (gdb) watch foo

	Ordinarily a watchpoint respects the scope of variables in expr (see below). The -location argument tells gdb to instead watch the memory referred to by expr. In this case, gdb will evaluate expr, take the address of the result, and watch the memory at that address. The type of the result is used to determine the size of the watched memory. If the expression's result does not have an address, then gdb will print an error.

A watchpoint stops execution of your program whenever the value of
an expression changes.
]],
	},
}

--{{{  local function show(file,line,before,after)

--show +/-N lines of a file around line M

local function show(file, line, before, after)

	line = tonumber(line or 1)
	before = tonumber(before or 10)
	after = tonumber(after or before)

	if not string.find(file, '%.') then file = file .. '.lua' end

	local f = io.open(file, 'r')
	if not f then
		--{{{  try to find the file in the path

		--
		-- looks for a file in the package path
		--
		local path = package.path or LUA_PATH or ''
		for c in string.gmatch(path, "[^;]+") do
			local c = string.gsub(c, "%?%.lua", file)
			f = io.open(c, 'r')
			if f then
				break
			end
		end

		--}}}
		if not f then
			io.write('Cannot find ' .. file .. '\n')
			return
		end
	end

	local i = 0
	for l in f:lines() do
		i = i + 1
		if i >= (line - before) then
			if i > (line + after) then break end
			if i == line then
				io.write(i .. '***\t' .. l .. '\n')
			else
				io.write(i .. '\t' .. l .. '\n')
			end
		end
	end

	f:close()
	return true
end

local commands = {}

local beginFrame = 3
local stack = {}
local currentFrame = beginFrame
local currentFunction

local command
local action
local args
local locals = {}
local upvalues = {}

local function GetLocals(thread, frame)
	local locals = {}
	local i = 1
	local level = frame

	local name, value
	repeat
		name, value = debug.getlocal(thread, level, i)
		locals[i] = { name = name, value = value }
		i = i + 1
		until (name == nil)

	return locals
end

local function GetUpvalues(f)
	local upvalues = {}
	local i = 1

	local name, value
	repeat
		name, value = debug.getupvalue(f, i)
		upvalues[i] = { name = name, value = value }
		i = i + 1
		until (name == nil)

	return upvalues
end

local valueLeftFormat = "%s%-6d%-10s%-30s"
local numberValueFormat = valueLeftFormat .. "%.20g\n"
local stringValueFormat = valueLeftFormat .. "%q\n"
local functionValueFormat = valueLeftFormat .. "<%s:%d>\n"
local otherValueFormat = valueLeftFormat .. "%s\n"

local function ValueToString(name, value, prefix, index, detailedTable)
	local prefix = prefix or ""
	local index = index or 0
	if type(value) == "number" then
		return string.format(numberValueFormat, prefix, index, type(value), name, value)
	elseif type(value) == "string" then
		return string.format(stringValueFormat, prefix, index, type(value), name, tostring(value))
	elseif type(value) == "function" then
		local info = debug.getinfo(value, "nS")
		local fun_name = info.name or name or ""
		return string.format(functionValueFormat, prefix, index, type(value), name, info.source, info.linedefined)
	elseif type(value) == "table" and detailedTable == true then
		return string.format(otherValueFormat, prefix, index, type(value), name, tableEnhanced.ToString(value, "", prefix))
	else
		return string.format(otherValueFormat, prefix, index, type(value), name, tostring(value))
	end
end

local function DisplayeDiffent(thread, f)
	local news = GetLocals(thread, currentFrame)
	local headerWritten = false
	for i = 1, #news do
		if (locals[i] == nil or news[i].name ~= locals[i].name or news[i].value ~= locals[i].value) then
			if (headerWritten == false) then
				io.write("local changes:\n")
				headerWritten = true
			end
			io.write(ValueToString(news[i].name, news[i].value, "\t", i))
		end
	end
	locals = news

	local news = GetUpvalues(f)
	local headerWritten = false
	for i = 1, #news do
		if (upvalues[i] == nil or news[i].name ~= upvalues[i].name or news[i].value ~= upvalues[i].value) then
			if (headerWritten == false) then
				io.write("upvalue changes:\n")
				headerWritten = true
			end
			io.write(ValueToString(news[i].name, news[i].value, "\t", i))
		end
	end
	upvalues = news
end

local function FindLocal(thread, frame, key)
	local numberKey = tonumber(key)
	if (numberKey ~= nil) then
		return debug.getlocal(thread, frame, numberKey)
	end

	local i = 1
	local name, value = debug.getlocal(thread, frame, i)
	if (name == nil) then
		return
	end
	while name do
		if (name == key) then
			return name, value
		end
		i = i + 1
		name, value = debug.getlocal(thread, frame, i)
	end
end

local function FindUpvalue(f, key)
	if (type(f) ~= "function") then
		return
	end

	local i = 1
	local name, value = debug.getupvalue(f, i)
	if (name == nil) then
		return
	end
	while name do
		if (name == key) then
			return name, value
		end
		i = i + 1
		name, value = debug.getupvalue(f, i)
	end
end

local function RunString(expression)
	local f = loadstring("return " .. expression)
	if (type(f) == "function") then
		return pcall(f)
	end
end

local function LocalOrValueOrExpressionToString(thread, frame, expression, prefix, i)

	local indexes = {}
	if (string.find(expression, "([^()]+%(.*%))")) then
		indexes[#indexes + 1] = expression
	else
		for word in string.gmatch(expression, "([%a%_%d]+)") do
			local n = tonumber(word)
			if (n ~= nil) then
				indexes[#indexes + 1] = n
			else
				indexes[#indexes + 1] = word
			end
		end
	end

	if (#indexes <= 0) then
		return
	end

	local key = indexes[1]
	table.remove(indexes, 1)

	local name, value = FindLocal(thread, frame, key)
	if (name == nil) then
		local ar = stack[frame]
		name, value = FindUpvalue(ar.func, key)
	end

	if (name ~= nil) then
		if (#indexes >= 1) then
			if (type(value) == "table") then
				local v = tableEnhanced.Find(value, unpack(indexes))
				if (v ~= nil) then
					name = expression
					value = v
				else
					name = nil
					value = nil
				end
			else
				name = nil
				value = nil
			end
		end
	end

	if (name ~= nil) then
		return ValueToString(name, value, prefix, i, true)
	end

	local success, runResult = RunString(expression)
	if (success == true) then
		return ValueToString(expression, runResult, prefix, i, true)
	end
end

local displayList = {}
local function DisplayList(thread, frame)
	if (#displayList <= 0) then
		return
	end

	local prefix = "\t"
	io.write("displays:\n")
	local message = stringEnhanced.CreateMessageTable()
	message.Append(string.format("%s%-20s%-6s%-10s%-20s%s\n", prefix, "EXPRESSION", "INDEX", "TYPE", "NAME", "VALUE"))
	for i = 1, #displayList do
		local expression = displayList[i]

		local s = LocalOrValueOrExpressionToString(thread, frame, expression, "", i)
		if (s ~= nil) then
			message.Append(string.format("%s%-20s%s", prefix, expression, s))
		end
	end

	io.write(message.GetString())
end

local function SetCurrentFrame(n)
	if (n < 1) then
		currentFrame = 1
	elseif (n > #stack) then
		currentFrame = #stack
	else
		currentFrame = n
	end
end

local function dbg_loop(thread, breakIndex)
	breakIndex = breakIndex or 1
	if (thread == nil) then
		return
	else
	end

	stack = {}
	local frame = 1
	local ar = debug.getinfo(thread, frame)
	while (ar ~= nil) do
		stack[#stack + 1] = ar
		frame = frame + 1
		ar = debug.getinfo(thread, frame)
	end

	local ar = stack[currentFrame]
	while (show(string.sub(ar.source, 2), ar.currentline, 0, 0) ~= true) do
		SetCurrentFrame(currentFrame + 1)
		ar = stack[currentFrame]
		currentFunction = ar.func
		io.write(string.format("Breakpoint %d, %s() at %s:%d\n", breakIndex, ar.name or "(*anonymous)", ar.source, ar.currentline))
	end
	DisplayList(thread, currentFrame)

	while true do
		local ar = stack[currentFrame]
		io.write(string.format("(ldb:%7dKbytes) ", collectgarbage("count")))
		local line = io.read("*line")

		local starts, ends = string.find(line, "%S+")
		if (starts ~= nil or ends ~= nil) then
			command = string.sub(line, starts, ends)
			action = commands[command]
			args = string.gsub(line, "%S+%s*", '', 1) --strip command off line
		end

		if (action ~= nil) then
			--			if (DEBUG) then
			--				io.write(string.format("thread%q, command, args:%s %q\n", tostring(thread), command, args))
			--			end
			if (action(thread, args) == true) then
				return
			end
		end
	end
end

local function DumpLocals(thread, frame, message)
	local prefix = "\t\t"
	local i = 1
	local level = frame

	local name, value = debug.getlocal(thread, level, i)
	if (name == nil) then
		return
	end

	message.Append("\tlocals:\n")
	while name do
		message.Append(ValueToString(name, value, prefix, i))
		i = i + 1
		name, value = debug.getlocal(thread, level, i)
	end
end

local function DumpUpvalues(f, message)
	local prefix = "\t\t"
	local i = 1

	local name, value = debug.getupvalue(f, i)
	if (name == nil) then
		return
	end

	message.Append("\tupvalues:\n")
	while name do
		message.Append(ValueToString(name, value, prefix, i))
		i = i + 1
		name, value = debug.getupvalue(f, i)
	end
end

local function PrintCurrentFrameDetail(thread)
	io.write(string.format("Current frame: %d\n", currentFrame))
	local message = stringEnhanced.CreateMessageTable()
	local ar = stack[currentFrame]
	message.Append("%d%s\t%s:%d: in function '%s'\n", currentFrame, "***", ar.source, ar.currentline, ar.name or string.format("<%s:%d>", ar.source, ar.linedefined))
	DumpLocals(thread, currentFrame, message)
	DumpUpvalues(ar.func, message)
	io.write(message.GetString())
end

local function TrimPath(fullPath)
	local pattern = "[:/\\](.+)$"
	local file = fullPath
	local next = string.match(file, pattern)
	while next ~= nil do
		file = next
		next = string.match(file, pattern)
	end
	return file
end

function Break(reason, frame)
	currentFrame = beginFrame + (frame or 1)
	local thread, main = coroutineEnhanced.GetCurrentThread()
	if (type(thread) ~= "thread") then
		io.write("Can not get current thread, can not debug.\n")
		return
	end
	coroutineEnhanced.Run(dbg_loop, thread)
end

dbg.RegisterBreakCallback(Break)

--}}}

commands["backtrace"] = function(thread, full)
	local message = stringEnhanced.CreateMessageTable()
	local currentFrameStamp = ""
	for i = 1, #stack do
		local ar = stack[i]
		if (i == currentFrame) then
			currentFrameStamp = "***"
		else
			currentFrameStamp = ""
		end
		message.Append("%d%s\t%s:%d: in function '%s'\n", i, currentFrameStamp, ar.source, ar.currentline, ar.name or string.format("<%s:%d>", ar.source, ar.linedefined))
		if (full == "full") then
			DumpLocals(thread, i, message)
			DumpUpvalues(ar.func, message)
		end
	end
	io.write(message.GetString())
end
commands["bt"] = commands["backtrace"]

local function ParseBreakinfoFromLocation(thread, location)

	local line
	local functionName
	local file
	if (location ~= nil) then
		local _, _, left = string.find(location, "([^:]+)")
		local _, _, right = string.find(location, ":(.*)")
		--io.write(string.format("left:%q, right:%q\n", tostring(left), tostring(right)))
		if (right ~= nil) then
			file = left
			if (tonumber(right) ~= nil) then
				line = tonumber(right)
			else
				functionName = right
			end
		else
			if (tonumber(left) ~= nil) then
				line = tonumber(left)
			else
				functionName = left
			end
		end
	end

	-- TODO:应该在所有的栈帧及其环境中查找
	if (functionName ~= nil) then
		local name, value
		if (file ~= nil) then
			local m = _G.m[file]
			if (m ~= nil) then
				value = m[functionName]
			end
		elseif (file == nil) then
			name, value = FindLocal(thread, currentFrame, functionName)
			if (name == nil or value == nil) then
				local ar = stack[currentFrame]
				name, value = FindUpvalue(ar.func, functionName)
			end

			if (type(value) ~= "function") then
				local t = {}
				for word in string.gmatch(functionName, "%a+") do
					t[#t + 1] = word
				end

				value = tableEnhanced.Find(_G, unpack(t))
			end
		end

		if (type(value) == "function") then
			local ar = debug.getinfo(value, "S")
			if (ar.linedefined > 0) then
				line = ar.linedefined
				file = ar.source
			else
				return nil, nil, string.format("Function %q can not break.\n", functionName)
			end
		else
			return nil, nil, string.format("Function %q not defined.\n", functionName)
		end
	end

	if (file == nil and line == nil) then
		local ar = stack[currentFrame]
		file = ar.source
		line = ar.currentline
	elseif (file == nil) then
		local ar = stack[currentFrame]
		file = ar.source
	end

	--io.write(string.format("line:%q, function:%q, file:%q\n", tostring(line), tostring(functionName), tostring(file)))
	return file, line
end

local function ParseBreakParameters(thread, args)
	local _, _, location = string.find(args, "(%S*)")
	local _, _, condition = string.find(args, "if%s+(%S*)")
	if condition ~= nil then
		condition = "return " .. condition
	end

	local file, line, error = ParseBreakinfoFromLocation(thread, location)
	if (file == nil or line == nil) then
		io.write(error)
	end

	return file, line, condition
end

local breakpoints = {}

local function SetBreakpoint(line, file, condition, temp)
	local n = dbg.SetBreakpoint(line, file, condition, temp)
	if (n > 0) then
		local condition = condition or true
		tableEnhanced.Assign(breakpoints, condition, line, file)
		io.write(string.format("Breakpoint %d at: file %s, line %d.\n", n, file, line))
		return true
	end
end

function LoadBreakpoints(filename)
	local file = io.open(filename, "r")
	if (file == nil) then
		return
	end

	local success
	for line in file:lines() do
		local linenum, file, condition = string.match(line, "(%S+)%s(%S+)%s(%S+)")
		local linenum = tonumber(linenum)
		if (linenum ~= nil) then
			if (condition == "true") then
				success = SetBreakpoint(linenum, file)
			else
				success = SetBreakpoint(linenum, file, condition)
			end
		end
	end

	file:close()
	if (success) then
		dbg.Start()
	end
	return success
end

commands["break"] = function(thread, args)
	local file, line, condition = ParseBreakParameters(thread, args)
	if (file ~= nil and line ~= nil) then
		if (SetBreakpoint(line, file, condition)) then
			return
		end
	end

	io.write(string.format("Can no set breakpoint.\n"))
end
commands["b"] = commands["break"]

commands["clear"] = function(thread, args)
	local _, _, location = string.find(args, "(%S*)")
	local file, line, error = ParseBreakinfoFromLocation(thread, location)
	if (file == nil or line == nil) then
		io.write(error)
		return
	end

	local n = dbg.ClearBreakpoint(line, file)
	if (n > 0) then
		tableEnhanced.Assign(breakpoints, nil, line, file)
		io.write(string.format("Deleted breakpoint %d.\n", n))
		return
	end
end

--commands["condition"] = function(thread)
--end

commands["continue"] = function(thread, count)
	count = tonumber(count)
	if (type(count) == "number") then
		dbg.SetCurrentBPIgnoreCount(count)
	end
	return dbg.Start(thread)
end
commands["c"] = commands["continue"]
--commands["delete"] = function(thread)
--end
--
--commands["disable"] = function(thread)
--end
--

commands["display"] = function(thread, var)
	if (var == nil or var == "") then
		DisplayList(thread, currentFrame)
	else
		displayList[#displayList + 1] = var
		local s = LocalOrValueOrExpressionToString(thread, currentFrame, var)
		if (s ~= nil) then
			io.write(s)
		else
			io.write(string.format("%q not found.\n", var))
		end
	end
end

commands["down"] = function(thread, n)
	local target = currentFrame - 1

	n = tonumber(n)
	if (n ~= nil) then
		target = currentFrame - n
	end

	SetCurrentFrame(target)
	PrintCurrentFrameDetail(thread)
end
--
--commands["enable"] = function(thread)
--end
--
commands["finish"] = function(thread)
	local ar = stack[currentFrame]
	if (dbg.Finish(ar.linedefined, ar.source)) then
		return dbg.Start(thread)
	end
end
commands["fin"] = commands["finish"]

commands["frame"] = function(thread, n)
	n = tonumber(n)
	if (type(n) == "number") then
		SetCurrentFrame(n)
	end
	PrintCurrentFrameDetail(thread)
end
commands["f"] = commands["frame"]

--commands["info"] = function(thread, command)
--	if (command == "frame" or command == "f") then
--		PrintCurrentFrameDetail(thread)
--	elseif (command == "locals" or command == "l") then
--		local message = stringEnhanced.CreateMessageTable()
--		local ar = stack[currentFrame]
--		DumpLocals(thread, currentFrame, message)
--		io.write(message.GetString())
--	elseif (command == "upvalues" or command == "u") then
--		local message = stringEnhanced.CreateMessageTable()
--		local ar = stack[currentFrame]
--		DumpUpvalues(ar.func, message)
--		io.write(message.GetString())
--	end
--end

commands["list"] = function(thread)
	local ar = stack[currentFrame]
	show(string.sub(ar.source, 2), ar.currentline)
end
commands["l"] = commands["list"]

commands["next"] = function(thread, count)
	count = tonumber(count)
	local ar = stack[currentFrame]
	if (dbg.Next(count or 1, ar.linedefined, ar.source)) then
		return dbg.Start(thread)
	end
end
commands["n"] = commands["next"]

local lastExpression
commands["print"] = function(thread, expression)
	if (expression ~= nil and expression ~= "") then
		lastExpression = expression
	end
	local error_info = ""
	if (lastExpression ~= nil) then
		local s = LocalOrValueOrExpressionToString(thread, currentFrame, lastExpression)
		if (s ~= nil) then
			io.write(s)
			return
		else
			error_info = s
		end
	end

	io.write(string.format("%q not found:%s\n", tostring(lastExpression), tostring(error_info)))
end
commands["p"] = commands["print"]
--
--commands["pwd"] = function(thread)
--end
--

commands["quit"] = function(thread)
	return dbg.Stop(thread)
end
commands["q"] = commands["quit"]

commands["save"] = function(thread, filename)
	if (tableEnhanced.GetTableRowNumber(breakpoints) == 0) then
		io.write("warning: Nothing to save.\n")
		return
	end

	if (filename == nil or filename == "") then
		filename = ".ldbinit"
	end

	local file = io.open(filename, "w+")
	if (file == nil) then
		return
	end
	for linenumber, fe in pairs(breakpoints) do
		for f, condition in pairs(fe) do
			file:write(string.format("%d\t%s\t%s\n", linenumber, f, tostring(condition)))
		end
	end
	file:close()

	io.write(string.format("Saved to file '%s'.\n", filename))
end

commands["source"] = function(thread, filename)
	if (filename == nil or filename == "") then
		filename = ".ldbinit"
	end

	if (LoadBreakpoints(filename) ~= true) then
		io.write(string.format("%s: No such file or directory.\n", filename))
	end
end

commands["step"] = function(thread, count)
	count = tonumber(count)
	if (dbg.Step(count or 1)) then
		return dbg.Start(thread)
	end
end
commands["s"] = commands["step"]

commands["tbreak"] = function(thread, count)
	local file, line, condition = ParseBreakParameters(thread, args)
	if (file ~= nil and line ~= nil) then
		if (SetBreakpoint(line, file, condition, true)) then
			return
		end
	end

	io.write(string.format("Can no set breakpoint.\n"))
end
commands["tb"] = commands["tbreak"]

--commands["until"] = function(thread)
--end
--
commands["undisplay"] = function(thread, name)
	if (name == nil) then
		displayList = {}
		return
	end

	local i = tonumber(name)
	if (i ~= nil) then
		table.remove(displayList, i)
	end
end

commands["up"] = function(thread, n)
	local target = currentFrame + 1

	n = tonumber(n)
	if (n ~= nil) then
		target = currentFrame + n
	end

	SetCurrentFrame(target)
	PrintCurrentFrameDetail(thread)
end
--
--commands["watch"] = function(thread)
--end

commands["help"] = function(thread, command)
	if hints[command] then
		io.write(hints[command].brief, "\n", hints[command].detail)
	else
		local sort = {}
		for command, hint in pairs(hints) do
			if (commands[command]) then
				sort[#sort + 1] = command
			end
		end
		table.sort(sort)
		for i = 1, #sort do
			io.write(string.format("%-16s-- %s\n", sort[i], hints[sort[i]].brief))
		end
	end
end
commands["h"] = commands["help"]

