require("lib/url-encode")
inspect             = require 'lib.inspect'

-- decode url paramaters into a table
function url_param_decode(param_string)
    if not param_string then
        print("param string is nil?")
        return {}
    end
    local params = string_split(param_string, "&")
    local tbl = {}
    for idx = 1, table.maxn(params) do
        local kv = string_split(params[idx], "=")
        local key = kv[1]
        local value = true
        if kv[2] then
            value = urldecode(kv[2])
        end
        tbl[key] = value
    end
    return tbl
end

-- encode a table (with string keys and values) into url paramaters
function url_param_encode(param_table)
    local len = getn(param_table)
    if len == 0 then
        return ""
    end

    local params

    for k, v in ipairs(param_table) do
        local value = urlencode(v)
        local p = k .. "=" .. value
        if not params then
            params = p
        else
            params = params .. "&" .. p
        end
    end
    return params
end

function import_test()
    print("Hello world!")
end

-- splits str into an array-like table. delimiter can be a pattern.
function string_split(str, delimiter)
    local tbl = {}
    local idx = 1
    local s_start, s_end = string.find(str, delimiter, idx)

    while s_start do
        table.insert( tbl, string.sub(str, idx, s_start - 1))
        idx = s_end + 1
        s_start, s_end = string.find(str, delimiter, idx)
    end

    table.insert( tbl, string.sub( str, idx ))
    return tbl
end


function table_patch(tbl, p)

end