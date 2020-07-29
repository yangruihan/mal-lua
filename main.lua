local Interpreter = require("interpreter")
local Value = require("value")
local Printer = require("printer")

local interpreter = Interpreter()

local function safeCall(func, ...)
    xpcall(
        func,
        function(msg)
            if type(msg) == "string" then
                print(msg)
            else
                print(Printer.printStr(msg, true))
            end
            print(debug.traceback())
        end,
        ...
    )
end

safeCall(interpreter.rep, interpreter, string.format('(load-file "%s")', "init.lisp"))

local function repl()
    interpreter:rep('(println (str "Mal [" *host-language* "]"))')

    while true do
        io.write("user> ")
        local input = io.read()
        if not input then
            break
        end

        if input == "" then
            goto continue
        end

        safeCall(interpreter.rep, interpreter, input)

        ::continue::
    end
end

local function doFile(path)
    --- set command list args
    local args = {}
    for i = 2, #arg do
        table.insert(args, Value.string(arg[i]))
    end
    safeCall(interpreter.replEnv.set, interpreter.replEnv, Value.symbol("*ARGV*"), Value.list(args))

    --- do file
    safeCall(interpreter.rep, interpreter, string.format('(load-file "%s")', path))
end

if #arg == 0 then
    repl()
else
    doFile(arg[1])
end
