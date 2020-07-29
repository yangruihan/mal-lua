local Value = require("value")
local Printer = require("printer")
local Reader = require("reader")
local Utils = require("utils")

local Core = {}

---@param symbol string
---@param func function
local function symbolWithFunc(symbol, func)
    return Value.symbol(symbol), Value.func(func)
end

local concat = function(...)
    local ret = {}
    local len = select("#", ...)
    for i = 1, len do
        local v = select(i, ...)

        if Value.isList(v) or Value.isVector(v) then
            for i, k in ipairs(v.value) do
                table.insert(ret, k)
            end
        elseif Value.isMap(v) then
            table.insert(ret, v)
        elseif not Value.isNil(v) then
            table.insert(ret, v)
        end
    end

    return ret
end

---@param a any
local function luaToL(a)
    if a == nil then
        return Value.Nil
    elseif type(a) == "boolean" then
        return Value.bool(a)
    elseif type(a) == "number" then
        return Value.number(a)
    elseif type(a) == "string" then
        return Value.string(a)
    elseif type(a) == "table" then
        local firstKey, _ = next(a)
        if firstKey == nil then
            return Value.list({})
        elseif type(firstKey) == "number" then
            local list = {}
            for i, v in ipairs(a) do
                list[i] = luaToL(v)
            end
            return Value.list(list)
        else
            local map = Value.map()
            for k, v in pairs(a) do
                Value.mapSet(map, luaToL(k), luaToL(v))
            end
            return map
        end
    end

    error(string.format("not support value (%s)", tostring(a)))
end

Core.ns = {
    --region arith
    {
        symbolWithFunc(
            "+",
            ---@param a Value
            ---@param b Value
            ---@return Value
            function(a, b)
                return Value.number(a.value + b.value)
            end
        )
    },
    {
        symbolWithFunc(
            "-",
            ---@param a Value
            ---@param b Value
            ---@return Value
            function(a, b)
                return Value.number(a.value - b.value)
            end
        )
    },
    {
        symbolWithFunc(
            "*",
            ---@param a Value
            ---@param b Value
            ---@return Value
            function(a, b)
                return Value.number(a.value * b.value)
            end
        )
    },
    {
        symbolWithFunc(
            "/",
            ---@param a Value
            ---@param b Value
            ---@return Value
            function(a, b)
                return Value.number(a.value / b.value)
            end
        )
    },
    {
        symbolWithFunc(
            "=",
            ---@param a Value
            ---@param b Value
            function(a, b)
                return a == b and Value.True or Value.False
            end
        )
    },
    {
        symbolWithFunc(
            "<",
            ---@param a Value
            ---@param b Value
            function(a, b)
                return a.value < b.value and Value.True or Value.False
            end
        )
    },
    {
        symbolWithFunc(
            "<=",
            ---@param a Value
            ---@param b Value
            function(a, b)
                return a.value <= b.value and Value.True or Value.False
            end
        )
    },
    {
        symbolWithFunc(
            ">",
            ---@param a Value
            ---@param b Value
            function(a, b)
                return a.value > b.value and Value.True or Value.False
            end
        )
    },
    {
        symbolWithFunc(
            ">=",
            ---@param a Value
            ---@param b Value
            function(a, b)
                return a.value >= b.value and Value.True or Value.False
            end
        )
    },
    --endregion
    --region list
    {
        symbolWithFunc(
            "list",
            function(...)
                return Value.list(table.pack(...))
            end
        )
    },
    {
        symbolWithFunc(
            "list?",
            ---@param a Value
            function(a)
                return Value.isList(a) and Value.True or Value.False
            end
        )
    },
    {
        symbolWithFunc(
            "empty?",
            ---@param a Value
            function(a)
                return Value.isList(a) and #a.value == 0 and Value.True or Value.False
            end
        )
    },
    {
        symbolWithFunc(
            "count",
            ---@param a Value
            function(a)
                return Value.isList(a) and Value.number(#a.value) or Value.number(0)
            end
        )
    },
    --endregion
    --region string
    {
        symbolWithFunc(
            "pr-str",
            function(...)
                return Value.string(
                    table.concat(
                        Utils.map(
                            table.pack(...),
                            function(i)
                                return Printer.printStr(i, true)
                            end
                        ),
                        " "
                    )
                )
            end
        )
    },
    {
        symbolWithFunc(
            "str",
            function(...)
                return Value.string(
                    table.concat(
                        Utils.map(
                            table.pack(...),
                            function(i)
                                return Printer.printStr(i, false)
                            end
                        ),
                        ""
                    )
                )
            end
        )
    },
    {
        symbolWithFunc(
            "prn",
            function(...)
                print(
                    table.concat(
                        Utils.map(
                            table.pack(...),
                            function(i)
                                return Printer.printStr(i, true)
                            end
                        ),
                        " "
                    )
                )
                io.flush()
                return Value.Nil
            end
        )
    },
    {
        symbolWithFunc(
            "println",
            function(...)
                print(
                    table.concat(
                        Utils.map(
                            table.pack(...),
                            function(i)
                                return Printer.printStr(i, false)
                            end
                        ),
                        " "
                    )
                )
                io.flush()
                return Value.Nil
            end
        )
    },
    {
        symbolWithFunc(
            "read-string",
            ---@param a Value
            function(a)
                return Reader.readStr(a.value)
            end
        )
    },
    {
        symbolWithFunc(
            "slurp",
            ---@param a Value
            function(a)
                local file = io.open(a.value)
                if not file then
                    error(string.format("no file exists %s", a.value))
                end
                local content = file:read("a")
                return Value.string(content .. "\n")
            end
        )
    },
    --endregion
    --region atom
    {
        symbolWithFunc(
            "atom",
            ---@param value Value
            function(value)
                return Value.atom(value)
            end
        )
    },
    {
        symbolWithFunc(
            "atom?",
            ---@param value Value
            function(value)
                return Value.isAtom(value) and Value.True or Value.False
            end
        )
    },
    {
        symbolWithFunc(
            "deref",
            ---@param atom Value
            function(atom)
                return atom.value
            end
        )
    },
    {
        symbolWithFunc(
            "reset!",
            ---@param atom Value
            ---@param newValue Value
            function(atom, newValue)
                atom.value = newValue
                return newValue
            end
        )
    },
    {
        symbolWithFunc(
            "swap!",
            ---@param atom Value
            ---@param func Value
            function(atom, func, ...)
                atom.value = func.value(atom.value, ...)
                return atom.value
            end
        )
    },
    --endregion
    --region meta
    {
        symbolWithFunc(
            "cons",
            ---@param first Value
            ---@param list Value
            function(first, list)
                local newTable = Utils.tableSlice(list.value)
                table.insert(newTable, 1, first)
                return Value.list(newTable)
            end
        )
    },
    {
        symbolWithFunc(
            "concat",
            function(...)
                return Value.list(concat(...))
            end
        )
    },
    --endregion
    --region list
    {
        symbolWithFunc(
            "nth",
            ---@param list Value
            ---@param index Value
            function(list, index)
                local i = index.value
                if i < 0 or i >= #list.value then
                    error(string.format("index out of range (%d/%d)", i, #list.value))
                end

                return list.value[i + 1]
            end
        )
    },
    {
        symbolWithFunc(
            "first",
            ---@param list Value
            function(list)
                if Value.isNil(list) or #list.value == 0 then
                    return Value.Nil
                end

                return list.value[1]
            end
        )
    },
    {
        symbolWithFunc(
            "rest",
            ---@param list Value
            function(list)
                if Value.isNil(list) or #list.value <= 1 then
                    return Value.list({})
                end

                return Value.list(Utils.tableSlice(list.value, 2))
            end
        )
    },
    --endregion
    --region exception
    {
        symbolWithFunc(
            "throw",
            ---@param exc Value
            function(exc)
                error(exc)
            end
        )
    },
    --endregion
    --region functional
    {
        symbolWithFunc(
            "apply",
            ---@param func Value
            function(func, ...)
                return func.value(table.unpack(concat(...)))
            end
        )
    },
    {
        symbolWithFunc(
            "map",
            ---@param func Value
            function(func, ...)
                local args = concat(...)
                return Value.list(Utils.map(args, func.value))
            end
        )
    },
    --endregion
    --region predicate
    {
        symbolWithFunc(
            "nil?",
            ---@param a Value
            function(a)
                return Value.bool(Value.isNil(a))
            end
        )
    },
    {
        symbolWithFunc(
            "true?",
            ---@param a Value
            function(a)
                return Value.bool(Value.isBool(a) and a.value)
            end
        )
    },
    {
        symbolWithFunc(
            "false?",
            ---@param a Value
            function(a)
                return Value.bool(Value.isBool(a) and not a.value)
            end
        )
    },
    {
        symbolWithFunc(
            "symbol?",
            ---@param a Value
            function(a)
                return Value.bool(Value.isSymbol(a))
            end
        )
    },
    --endregion
    --region other
    {
        symbolWithFunc(
            "symbol",
            ---@param s Value
            function(s)
                return Value.symbol(s.value)
            end
        )
    },
    {
        symbolWithFunc(
            "keyword",
            ---@param s Value
            function(s)
                return Value.keyword(":" .. s.value)
            end
        )
    },
    {
        symbolWithFunc(
            "keyword?",
            ---@param k Value
            function(k)
                return Value.bool(Value.isKeyword(k))
            end
        )
    },
    {
        symbolWithFunc(
            "vector",
            function(...)
                return Value.vector(table.pack(...))
            end
        )
    },
    {
        symbolWithFunc(
            "vector?",
            ---@param v Value
            function(v)
                return Value.bool(Value.isVector(v))
            end
        )
    },
    {
        symbolWithFunc(
            "sequential?",
            ---@param v Value
            function(v)
                return Value.bool(Value.isList(v) or Value.isVector(v))
            end
        )
    },
    {
        symbolWithFunc(
            "hash-map",
            function(...)
                return Value.map(table.pack(...))
            end
        )
    },
    {
        symbolWithFunc(
            "map?",
            ---@param m Value
            function(m)
                return Value.bool(Value.isMap(m))
            end
        )
    },
    {
        symbolWithFunc(
            "assoc",
            ---@param m Value
            function(m, ...)
                assert(Value.isMap(m), string.format("assoc type error, %s", tostring(m)))
                local newM = Value.mapClone(m)
                for i = 1, select("#", ...), 2 do
                    Value.mapSet(newM, select(i, ...), select(i + 1, ...))
                end
                return newM
            end
        )
    },
    {
        symbolWithFunc(
            "dissoc",
            ---@param m Value
            function(m, ...)
                local newM = Value.mapClone(m)
                for i = 1, select("#", ...) do
                    Value.mapSet(newM, select(i, ...), nil)
                end
                return newM
            end
        )
    },
    {
        symbolWithFunc(
            "get",
            ---@param m Value
            function(m, key)
                return m.value[key] or Value.Nil
            end
        )
    },
    {
        symbolWithFunc(
            "contains?",
            ---@param m Value
            ---@param key Value
            function(m, key)
                return m.value[key] and Value.True or Value.False
            end
        )
    },
    {
        symbolWithFunc(
            "keys",
            ---@param m Value
            function(m)
                assert(Value.isMap(m), string.format("%s not a map", tostring(m)))

                local keys = {}
                for k, v in pairs(m.value) do
                    table.insert(keys, k)
                end
                return Value.list(keys)
            end
        )
    },
    {
        symbolWithFunc(
            "vals",
            ---@param m Value
            function(m)
                assert(Value.isMap(m), string.format("%s not a map", tostring(m)))

                local vals = {}
                for k, v in pairs(m.value) do
                    table.insert(vals, v)
                end
                return Value.list(vals)
            end
        )
    },
    {
        symbolWithFunc(
            "readline",
            ---@param s Value
            function(s)
                io.write(s.value)
                local ret, input = pcall(io.read)
                return input and Value.string(input) or Value.Nil
            end
        )
    },
    {
        symbolWithFunc(
            "time-ms",
            function()
                return Value.number(os.time() * 1000)
            end
        )
    },
    {
        symbolWithFunc(
            "meta",
            ---@param f Value
            function(f)
                return f.meta or Value.Nil
            end
        )
    },
    {
        symbolWithFunc(
            "with-meta",
            ---@param f Value
            ---@param v Value
            function(f, v)
                local newF = Value.funcClone(f)
                newF.meta = v
                return newF
            end
        )
    },
    {
        symbolWithFunc(
            "fn?",
            ---@param f Value
            function(f)
                return Value.bool(Value.isRealFunc(f))
            end
        )
    },
    {
        symbolWithFunc(
            "macro?",
            ---@return f Value
            function(f)
                return Value.bool(Value.isMacro(f))
            end
        )
    },
    {
        symbolWithFunc(
            "string?",
            ---@param s Value
            function(s)
                return Value.bool(Value.isString(s))
            end
        )
    },
    {
        symbolWithFunc(
            "number?",
            ---@param n Value
            function(n)
                return Value.bool(Value.isNum(n))
            end
        )
    },
    {
        symbolWithFunc(
            "seq",
            ---@param v Value
            function(v)
                if Value.isNil(v) then
                    return v
                elseif Value.isList(v) then
                    if #v.value == 0 then
                        return Value.Nil
                    end
                    return v
                elseif Value.isVector(v) then
                    if #v.value == 0 then
                        return Value.Nil
                    end
                    return Value.list(Utils.tableSlice(v.value))
                elseif Value.isString(v) then
                    if #v.value == 0 then
                        return Value.Nil
                    end
                    local ret = {}
                    for i = 1, #v.value do
                        ret[i] = Value.string(string.sub(v.value, i, i))
                    end
                    return Value.list(ret)
                end
            end
        )
    },
    {
        symbolWithFunc(
            "conj",
            ---@param l Value
            function(l, ...)
                local ret = Utils.tableSlice(l.value)
                if Value.isList(l) then
                    for i = 1, select("#", ...) do
                        table.insert(ret, 1, (select(i, ...)))
                    end
                    return Value.list(ret)
                elseif Value.isVector(l) then
                    for i = 1, select("#", ...) do
                        table.insert(ret, (select(i, ...)))
                    end
                    return Value.vector(ret)
                end
            end
        )
    },
    {
        symbolWithFunc(
            "lua-eval",
            ---@param s Value
            function(s)
                local f, err = load("return " .. s.value)
                if err then
                    error(string.format("lua-eval: can't load code: %s", err))
                end
                return luaToL(f())
            end
        )
    }
    --endregion
}

return Core
