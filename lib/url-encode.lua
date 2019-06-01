local char_to_hex = function(c)
    return string.format("%%%02X", string.byte(c))
end
  
function urlencode(url)
    if url == nil then
        return
    end
    url = url:gsub("\n", "\r\n")
    url = url:gsub("([^%w ])", char_to_hex)
    url = url:gsub(" ", "+")
    return url
end
  
local hex_to_char = function(x)
    return string.char(tonumber(x, 16))
end
  
function urldecode(url)
    if url == nil then
        return
    end
    url = url:gsub("+", " ")
    url = url:gsub("%%(%x%x)", hex_to_char)
    return url
end
  
  -- ref: https://gist.github.com/ignisdesign/4323051
  -- ref: http://stackoverflow.com/questions/20282054/how-to-urldecode-a-request-uri-string-in-lua
  -- to encode table as parameters, see https://github.com/stuartpb/tvtropes-lua/blob/master/urlencode.lua