
local function table_dump( object )
    if type(object) == 'table' then
        local s = '{ '
        for k,v in pairs(object) do
            if type(k) ~= 'number' then k = string.format("%q", k) end
            s = s .. '['..k..'] = ' .. table.dump(v) .. ','
        end
        return s .. '} '
    elseif type(object) == 'function' then
        return tostring(object)
    elseif type(object) == 'string' then
        return string.format("%q", object)
    else
        return tostring(object)
    end
end

table.dump = table_dump

function Remember(func)
    return setmetatable({}, {
        __mode = "kv",
        __index = func,
    })
end
