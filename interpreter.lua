local Object = require("class")
local Types = require("types")
local Utils = require("utils")

local Value = require("value")
local Env = require("env")
local Core = require("core")
local Reader = require("reader")
local Printer = require("printer")

---@class Interpreter
---@field replEnv Env
local Interpreter = Object:extend()

function Interpreter:new()
    self.replEnv = Env(nil)
    for _, i in ipairs(Core.ns) do
        self.replEnv:set(i[1], i[2])
    end

    --- set eval function
    self.replEnv:set(
        Value.symbol("eval"),
        Value.func(
            function(value)
                return self:EVAL(value, self.replEnv)
            end
        )
    )
    --- set *host-language* symbol
    self.replEnv:set(Value.symbol("*host-language*"), Value.string("Lua"))
    self:rep('(def! load-file (fn* (f) (eval (read-string (str "(do " (slurp f) "\nnil)")))))', self.replEnv)
end

---@private
---@param value Value
---@param env Env
function Interpreter:evalAst(value, env)
    if Value.isSymbol(value) then
        local ret, found = env:get(value)
        if not found then
            error(string.format("'%s' not found", value.value))
        end
        return ret
    elseif Value.isList(value) then
        local ret = Value.list({})
        for i, k in ipairs(value.value) do
            table.insert(ret.value, self:EVAL(k, env))
        end
        return ret
    else
        return value
    end
end

---@private
---@param s string
---@return Value
function Interpreter:READ(s)
    return Reader.readStr(s)
end

---@param value Value
---@param env Env
local function isMacroCall(value, env)
    if not Value.isList(value) or not Value.isSymbol(value.value[1]) then
        return false
    end

    local func = env:get(value.value[1])
    return Value.isMacro(func)
end

---@param value Value
---@param env Env
local function macroExpand(value, env)
    while isMacroCall(value, env) do
        local macroFunc = env:get(value.value[1])
        value = macroFunc.value(table.unpack(Utils.tableSlice(value.value, 2)))
    end
    return value
end

---@private
---@param value Value
---@param env Env
---@return string
function Interpreter:EVAL(value, env)
    while true do
        if Value.isList(value) then
            if #value.value == 0 then
                return value
            else
                value = macroExpand(value, env)
                if not Value.isList(value) then
                    return self:evalAst(value, env)
                end

                ---@type string
                local firstValue = value.value[1].value

                if firstValue == "def!" then
                    return env:set(value.value[2], self:EVAL(value.value[3], env))
                elseif firstValue == "defmacro!" then
                    local func = self:EVAL(value.value[3], env)
                    local newFunc = Value.funcClone(func)
                    newFunc.isMacro = true
                    return env:set(value.value[2], newFunc)
                elseif firstValue == "let*" then
                    --- create new env
                    local newEnv = Env(env)
                    ---@type Value
                    local bindingList = value.value[2].value

                    --- binding varibles
                    for i = 1, #bindingList, 2 do
                        local key = bindingList[i]
                        local value = self:EVAL(bindingList[i + 1], newEnv)
                        newEnv:set(key, value)
                    end

                    --- eval expr
                    value = value.value[3]
                    env = newEnv
                elseif firstValue == "do" then
                    local seq = Utils.tableSlice(value.value, 2, #value.value - 1)
                    if #seq > 0 then
                        self:evalAst(Value.list(seq), env)
                    end
                    value = value.value[#value.value]
                elseif firstValue == "if" then
                    local condition = self:EVAL(value.value[2], env)
                    if Value.isTrue(condition) then
                        value = value.value[3]
                    else
                        value = value.value[4] or Value.Nil
                    end
                elseif firstValue == "fn*" then
                    return Value.func(
                        function(...)
                            local newEnv = Env(env, value.value[2].value, table.pack(...))
                            return self:EVAL(value.value[3], newEnv)
                        end
                    )
                elseif firstValue == "quote" then
                    return value.value[2]
                elseif firstValue == "quasiquote" then
                    local quasiquote = nil
                    ---@param a Value
                    quasiquote = function(a)
                        if not Value.isPair(a) then
                            return Value.list({Value.symbol("quote"), a})
                        else
                            local firstValue = a.value[1]
                            if Value.isSymbol(firstValue, "unquote") then
                                return a.value[2]
                            elseif Value.isPair(firstValue) and Value.isSymbol(firstValue.value[1], "splice-unquote") then
                                return Value.list(
                                    {
                                        Value.symbol("concat"),
                                        firstValue.value[2],
                                        quasiquote(Value.list(Utils.tableSlice(a.value, 2)))
                                    }
                                )
                            else
                                return Value.list(
                                    {
                                        Value.symbol("cons"),
                                        quasiquote(a.value[1]),
                                        quasiquote(Value.list(Utils.tableSlice(a.value, 2)))
                                    }
                                )
                            end
                        end
                    end
                    value = quasiquote(value.value[2])
                elseif firstValue == "macroexpand" then
                    return macroExpand(value.value[2], env)
                elseif firstValue == "try*" then
                    local exception, result = nil, nil
                    xpcall(
                        function()
                            result = self:EVAL(value.value[2], env)
                        end,
                        function(msg)
                            exception = msg
                        end
                    )

                    if exception then
                        if type(exception) == "string" then
                            exception = Value.exception(exception)
                        end

                        --- check there is a catch
                        if
                            value.value[3] and Value.isPair(value.value[3]) and
                                Value.isSymbol(value.value[3].value[1], "catch*")
                         then
                            result =
                                self:EVAL(value.value[3].value[3], Env(env, {value.value[3].value[2]}, {exception}))
                        else
                            error(exception)
                        end
                    end

                    return result
                else
                    local ret = self:evalAst(value, env)
                    local func = ret.value[1]
                    assert(Value.isFunc(func), string.format("Error: Symbol (%s) not callable", func))

                    local params = Utils.tableSlice(ret.value, 2)
                    return func.value(table.unpack(params))
                end
            end
        elseif Value.isVector(value) then
            local newV = {}
            for i, k in ipairs(value.value) do
                table.insert(newV, self:EVAL(k, env))
            end
            return Value.vector(newV)
        elseif Value.isMap(value) then
            local newMap = Value.map()
            for k, v in pairs(value.value) do
                Value.mapSet(newMap, k, self:EVAL(v, env))
            end
            return newMap
        else
            return self:evalAst(value, env)
        end
    end
end

---@private
---@param s string
---@return string
function Interpreter:PRINT(s)
    print(Printer.printStr(s, true))
end

---@param input string
---@return string
function Interpreter:rep(input)
    local value = self:READ(input)
    if value then
        return self:PRINT(self:EVAL(value, self.replEnv))
    end
end

return Interpreter
