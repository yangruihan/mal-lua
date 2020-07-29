local Types = require("types")
local Value = require("value")
local Utils = require("utils")

local M = {}

---@param value Value
---@param printReadably boolean
---@param sb table
function M.printStr(value, printReadably)
    printReadably = printReadably or false
    if Value.isList(value) then
        return string.format(
            "(%s)",
            table.concat(
                Utils.map(
                    value.value,
                    function(i)
                        return M.printStr(i, printReadably)
                    end
                ),
                " "
            )
        )
    elseif Value.isVector(value) then
        return string.format(
            "[%s]",
            table.concat(
                Utils.map(
                    value.value,
                    function(i)
                        return M.printStr(i, printReadably)
                    end
                ),
                " "
            )
        )
    elseif Value.isMap(value) then
        local sb = {}
        table.insert(sb, "{")
        local i = 0
        for k, v in pairs(value.value) do
            i = i + 1
            table.insert(sb, M.printStr(k, printReadably))
            table.insert(sb, " ")
            table.insert(sb, M.printStr(v, printReadably))

            if i ~= value.num then
                table.insert(sb, ", ")
            end
        end
        table.insert(sb, "}")
        return table.concat(sb)
    elseif Value.isString(value) then
        if printReadably then
            local ret = value.value
            for i, k in ipairs(Types.EscapeChar) do
                ret = string.gsub(ret, k[2], k[1])
            end
            return string.format('"%s"', ret)
        else
            return value.value
        end
    elseif Value.isFunc(value) then
        return string.format("#<function> %s", tostring(value.value))
    else
        return tostring(value.value)
    end
end

return M
