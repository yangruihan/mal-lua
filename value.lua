local Object = require("class")

local Types = require("types")

---@class Value
---@field type ValueType
---@field value any
local Value = Object:extend()

--region static function

---@param b boolean
function Value.bool(b)
    return b and Value.True or Value.False
end

---@param n number
function Value.number(n)
    return Value(Types.ValueType.Number, n)
end

---@param s string
function Value.symbol(s)
    return Value(Types.ValueType.Symbol, s)
end

---@param s string
function Value.string(s)
    return Value(Types.ValueType.String, s)
end

local listMeta = Value.Nil

---@param t Value[]
function Value.list(t)
    local newList = Value(Types.ValueType.List, t)
    newList.meta = listMeta
    return newList
end

local funcMeta = Value.Nil

---@param f function
function Value.func(f)
    local newValue = Value(Types.ValueType.Function, f)
    newValue.isMacro = false
    newValue.meta = funcMeta
    return newValue
end

local vectorMeta = Value.Nil

---@param v Value[]
function Value.vector(v)
    local newVector = Value(Types.ValueType.Vector, v)
    newVector.meta = vectorMeta
    return newVector
end

---@param k string
function Value.keyword(k)
    return Value(Types.ValueType.Keyword, k)
end

local mapMeta = Value.Nil

---@param m table
function Value.map(m)
    m = m or {}
    local newValue =
        Value(
        Types.ValueType.Map,
        setmetatable(
            {},
            {
                _keys = {},
                __index = function(t, k)
                    return rawget(t, string.format("%d-%s", k.type, tostring(k.value)))
                end,
                __newindex = function(t, k, v)
                    local key = string.format("%d-%s", k.type, tostring(k.value))
                    rawset(t, key, v)
                    rawset(getmetatable(t)._keys, key, k)
                end,
                __pairs = function(t)
                    return function(t, k)
                        k = k and string.format("%d-%s", k.type, tostring(k.value)) or nil
                        local k, v = next(t, k)
                        if k then
                            return rawget(getmetatable(t)._keys, k), v
                        end
                    end, t, nil
                end
            }
        )
    )
    newValue.num = 0
    newValue.meta = mapMeta
    for i = 1, #m, 2 do
        Value.mapSet(newValue, m[i], m[i + 1])
    end
    return newValue
end

---@param v Value
function Value.atom(v)
    return Value(Types.ValueType.Atom, v)
end

---@param msg string
function Value.exception(msg)
    return Value(Types.ValueType.Exception, msg)
end

---@param v Value
---@return boolean
function Value.isNil(v)
    return v.type == Types.ValueType.Nil
end

---@param v Value
---@return boolean
function Value.isBool(v)
    return v.type == Types.ValueType.Bool
end

---@param v Value
---@return boolean
function Value.isNum(v)
    return v.type == Types.ValueType.Number
end

---@param v Value
---@return boolean
function Value.isList(v)
    return v.type == Types.ValueType.List
end

---@param v Value
---@param name string
---@return boolean
function Value.isSymbol(v, name)
    if not name then
        return v.type == Types.ValueType.Symbol
    else
        return v.type == Types.ValueType.Symbol and v.value == name
    end
end

---@param v Value
---@return boolean
function Value.isString(v)
    return v.type == Types.ValueType.String
end

---@param v Value
---@return boolean
function Value.isKeyword(v)
    return v.type == Types.ValueType.Keyword
end

---@param v Value
---@return boolean
function Value.isVector(v)
    return v.type == Types.ValueType.Vector
end

---@param v Value
---@return boolean
function Value.isFunc(v)
    return v.type == Types.ValueType.Function
end

---@param v Value
---@return boolean
function Value.isMacro(v)
    return Value.isFunc(v) and v.isMacro
end

---@param v Value
---@return boolean
function Value.isMap(v)
    return v.type == Types.ValueType.Map
end

---@param v Value
---@return boolean
function Value.isAtom(v)
    return v.type == Types.ValueType.Atom
end

---@param v Value
---@return boolean
function Value.isException(v)
    return v.type == Types.ValueType.Exception
end

---@param v Value
---@return boolean
function Value.isFalse(v)
    return Value.isNil(v) or (Value.isBool(v) and not v.value)
end

---@param v Value
---@return boolean
function Value.isTrue(v)
    return not Value.isFalse(v)
end

--- returns true if the parameter is a non-empty list
---@param v Value
---@return boolean
function Value.isPair(v)
    return (Value.isList(v) or Value.isVector(v)) and #v.value > 0
end

---@param v Value
---@return boolean
function Value.isRealFunc(v)
    return Value.isFunc(v) and not v.isMacro
end

---@param v Value
---@return boolean
function Value.isMacro(v)
    return Value.isFunc(v) and v.isMacro
end

---@param m Value
---@return Value
function Value.mapClone(m)
    local newM = Value.map()
    for k, v in pairs(m.value) do
        newM.value[k] = v
    end
    newM.num = m.num
    newM.meta = m.meta
    return newM
end

---@param m Value
---@param k Value
---@param v Value
function Value.mapSet(m, k, v)
    if v and not m.value[k] then
        m.num = m.num + 1
    elseif not v and m.value[k] then
        m.num = m.num - 1
    end

    m.value[k] = v
end

---@param f Value
---@return Value
function Value.funcClone(f)
    local newF = Value.func(f.value)
    newF.isMacro = f.isMacro
    newF.meta = f.meta
    return newF
end

--endregion

---@param type ValueType
---@param value any
function Value:new(type, value)
    self.type = type
    self.value = value
end

function Value:__eq(other)
    if self.type ~= other.type then
        return false
    end

    if self.type == Types.ValueType.List or self.type == Types.ValueType.Vector then
        if #self.value ~= #other.value then
            return false
        end

        for i, k in ipairs(self.value) do
            if k ~= other.value[i] then
                return false
            end
        end

        return true
    elseif self.type == Types.ValueType.Map then
        for k, v in pairs(self.value) do
            if v ~= other.value[k] then
                return false
            end
        end
    end

    return self.value == other.value
end

function Value:__tostring()
    return string.format(
        "<Value type: %d, %s, value: %s>",
        self.type,
        Types.ValueTypeStr[self.type],
        tostring(self.value)
    )
end

Value.Nil = Value(Types.ValueType.Nil)
Value.True = Value(Types.ValueType.Bool, true)
Value.False = Value(Types.ValueType.Bool, false)

return Value
