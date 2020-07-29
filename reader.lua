local Types = require("types")
local Value = require("value")

local M = {}

--region Reader

---@class Reader
local Reader = {}
Reader.__index = Reader

setmetatable(
    Reader,
    {
        __call = function(class, ...)
            local ins = setmetatable({}, Reader)
            ins:new(...)
            return ins
        end
    }
)

---@param tokens string[]
function Reader:new(tokens)
    self.tokens = tokens
    self.position = 1
end

--- returns the token at the current position and increments the position
function Reader:next()
    self.position = self.position + 1
    return self.tokens[self.position - 1]
end

--- just returns the token at the current position
function Reader:peek()
    return self.tokens[self.position]
end

--endregion

local tokenPattern = {
    {"^[%s,]+"}, --- whitespaces or commas
    {"^~@"}, --- Captures the special two-characters ~@
    {"^[%[%]{}%(%)'`~%^@]"}, --- Captures any special single character, one of []{}()'`~^@
    {'^"'}, --- Starts capturing at a double-quote and stops at the next double-quote unless it was preceded by a backslash in which case it includes it until the next double-quote
    {"^;"}, --- Captures any sequence of characters starting with ;
    {'^[^%s%[%]{}%(\'"`,;%)]*'} --- Captures a sequence of zero or more non special characters
}

--- forward declare
local tokenize
local readList
local readVector
local readMap
local readAtom
local readForm

--- convert source string to token array
---@param source string
---@return string[]
function tokenize(source)
    local ret = {}

    local currentIdx = 1
    local sourceLen = #source

    while currentIdx <= sourceLen do
        for i, pattern in ipairs(tokenPattern) do
            local startIdx, endIdx = string.find(source, pattern[1], currentIdx)

            if startIdx then
                if endIdx < startIdx then
                    error(string.format("error found pattern %d %s", i, string.sub(source, currentIdx)))
                end

                --- if is string, handle with \"
                if i == 4 then
                    local startFindIdx = endIdx + 1
                    while true do
                        local nextQuoteStartIdx, nextQuoteEndIdx = string.find(source, '"', startFindIdx)
                        if not nextQuoteStartIdx then
                            error(string.format('not match \'"\''))
                        end

                        if string.match(string.sub(source, nextQuoteEndIdx - 2, nextQuoteEndIdx - 1), "^[^\\]\\") then
                            startFindIdx = nextQuoteEndIdx + 1
                        else
                            endIdx = nextQuoteEndIdx
                            break
                        end
                    end
                elseif i == 5 then ---  if is comments
                    local startFindIdx = endIdx + 1
                    local nextLineStartIdx, nextLineEndIdx = string.find(source, "\n", startFindIdx)

                    if not nextLineEndIdx then
                        endIdx = #source
                    else
                        endIdx = nextLineEndIdx
                    end
                end

                currentIdx = endIdx + 1

                --- if token is whitespace or commas or comments
                if i ~= 1 and i ~= 5 then
                    table.insert(ret, string.sub(source, startIdx, endIdx))
                end

                goto continue
            end
        end

        error(string.format("not found pattern %s", string.sub(source, currentIdx)))

        ::continue::
    end

    return ret
end

---@param reader Reader
---@return Value
function readList(reader)
    -- consume '('
    local token = reader:next()

    local ret = Value.list({})

    if reader:peek() == ")" then
        goto final
    end

    while token ~= ")" do
        if not token then
            error("Error: no match ')'")
        end

        table.insert(ret.value, readForm(reader))
        token = reader:peek()
    end

    ::final::

    -- consume ')'
    reader:next()

    return ret
end

---@param reader Reader
---@return Value
function readVector(reader)
    -- consume '('
    local token = reader:next()

    local ret = Value.vector({})

    if reader:peek() == "]" then
        goto final
    end

    while token ~= "]" do
        if not token then
            error("Error: no match ']'")
        end

        table.insert(ret.value, readForm(reader))
        token = reader:peek()
    end

    ::final::

    -- consume ']'
    reader:next()

    return ret
end

---@param reader Reader
---@return Value
function readMap(reader)
    -- consume '{'
    local token = reader:next()

    local ret = Value.map({})

    if reader:peek() == "}" then
        goto final
    end

    while token ~= "}" do
        if not token then
            error("Error: no match '}'")
        end

        Value.mapSet(ret, readForm(reader), readForm(reader))
        token = reader:peek()
    end

    ::final::

    -- consume '}'
    reader:next()

    return ret
end

---@param reader Reader
---@return Value
function readAtom(reader)
    local token = reader:next()

    local ret = nil
    if string.match(token, "^-?[0-9]+%.?[0-9]*") then
        ret = Value.number(tonumber(token))
    elseif token == "true" then
        ret = Value.True
    elseif token == "false" then
        ret = Value.False
    elseif token == "nil" then
        ret = Value.Nil
    elseif string.match(token, "^:") then
        ret = Value.keyword(token)
    elseif string.match(token, '^"') then
        for i, k in ipairs(Types.EscapeChar) do
            token = string.gsub(token, k[1], k[2])
        end
        ret = Value.string(string.sub(token, 2, -2))
    else
        ret = Value.symbol(token)
    end

    return ret
end

---@param reader Reader
---@return Value
function readForm(reader)
    local token = reader:peek()
    if token == "(" then
        return readList(reader)
    elseif token == "[" then
        return readVector(reader)
    elseif token == "{" then
        return readMap(reader)
    elseif token == "'" then
        --- consume "'"
        reader:next()
        return Value.list(
            {
                Value.symbol("quote"),
                readForm(reader)
            }
        )
    elseif token == "`" then
        --- consume "`"
        reader:next()
        return Value.list(
            {
                Value.symbol("quasiquote"),
                readForm(reader)
            }
        )
    elseif token == "~" then
        --- consume "~"
        reader:next()
        return Value.list(
            {
                Value.symbol("unquote"),
                readForm(reader)
            }
        )
    elseif token == "~@" then
        --- consume "~@"
        reader:next()
        return Value.list(
            {
                Value.symbol("splice-unquote"),
                readForm(reader)
            }
        )
    elseif token == "@" then
        --- consume "@"
        reader:next()
        return Value.list(
            {
                Value.symbol("deref"),
                readForm(reader)
            }
        )
    elseif token == "^" then
        --- consume "^"
        reader:next()
        local n1Form = readForm(reader)
        local n2Form = readForm(reader)
        return Value.list(
            {
                Value.symbol("with-meta"),
                n2Form,
                n1Form
            }
        )
    else
        return readAtom(reader)
    end
end

---@param source string
---@return Value
function M.readStr(source)
    local tokens = tokenize(source)
    if #tokens == 0 then
        return Value.Nil
    end

    local reader = Reader(tokens)
    return readForm(reader)
end

return M
