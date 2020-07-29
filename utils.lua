local Utils = {}

---@param t table
---@param s number
---@param e number
---@return table
function Utils.tableSlice(t, s, e)
    s = s or 1
    e = e or #t
    return table.move(t, s, e, 1, {})
end

---@param list table
---@param func function
---@return table
function Utils.map(list, func)
    local ret = {}
    for i, k in ipairs(list) do
        ret[i] = func(k)
    end
    return ret
end

return Utils
