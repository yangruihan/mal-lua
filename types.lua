local Types = {}

---@alias ValueType number|"Nil"|"Bool"|"Number"|"List"|"Symbol"|"String"|"Function"|"Keyword"|"Vector"|"Map"|"Atom"
Types.ValueType = {
    Nil = 0,
    Bool = 1,
    Number = 2,
    List = 3,
    Symbol = 4,
    String = 5,
    Function = 6,
    Keyword = 7,
    Vector = 8,
    Map = 9,
    Atom = 10,
    Exception = 11,
}

Types.ValueTypeStr = {}
for k, v in pairs(Types.ValueType) do
    Types.ValueTypeStr[v] = k
end

Types.EscapeChar = {
    {"\\\\", "\\"},
    {'\\"', '"'},
    {"\\'", "'"},
    {"\\a", "\a"},
    {"\\b", "\b"},
    {"\\f", "\f"},
    {"\\n", "\n"},
    {"\\r", "\r"},
    {"\\t", "\t"},
    {"\\v", "\v"},
    {"\\0", "\0"}
}

return Types
