local Object = require("class")

local Value = require("value")

---@class Env
---@field outer Env
---@field data table
local Env = Object:extend()

---@param outer Env
---@param binds Value[]
---@param exprs Value[]
function Env:new(outer, binds, exprs)
    self.outer = outer
    self.data = {}

    if binds and exprs then
        for i, k in ipairs(binds) do
            if k.value == "&" then
                local vars = {}
                for j = i, #exprs do
                    vars[j - i + 1] = exprs[j]
                end
                self:set(binds[i + 1], Value.list(vars))
                break
            else
                self:set(k, exprs[i])
            end
        end
    end
end

---@param symbol Value
---@param value Value
function Env:set(symbol, value)
    self.data[symbol.value] = value
    return value
end

---@param symbol Value
function Env:find(symbol)
    local ret = self.data[symbol.value]
    local outer = self.outer
    while not ret and outer do
        ret = outer.data[symbol.value]
        outer = outer.outer
    end
    return ret or Value.Nil, ret and true or false
end

---@param symbol Value
function Env:get(symbol)
    return self:find(symbol)
end

return Env
