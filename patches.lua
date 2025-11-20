local table = require 'ext.table'
local string = require 'ext.string'
local path_instance = require 'ext.path' -- 这是一个实例
local os = require 'ext.os'
local Iter = require 'ext-boost.iter'
local coroutine = require 'ext.coroutine'

-- === 1. Table 增强 ===
local t_meta = getmetatable(table()) or table

function t_meta:iter()
    local i = 0
    local n = #self
    return Iter(function()
        i = i + 1
        if i <= n then return self[i] end
    end)
end

function table.zip(...)
    local args = table.pack(...)
    local res = table()
    local len = math.huge
    for i = 1, args.n do
        len = math.min(len, #args[i])
    end
    for i = 1, len do
        local row = table()
        for j = 1, args.n do
            row:insert(args[j][i])
        end
        res:insert(row)
    end
    return res
end

-- === 2. String 增强 ===

function string.dedent(s)
    local lines = string.split(s, '\n')
    local min_indent = math.huge
    local has_content = false
    
    for _, l in ipairs(lines) do
        if string.trim(l) ~= "" then
            local _, _, space = l:find("^(%s*)")
            min_indent = math.min(min_indent, #space)
            has_content = true
        end
    end
    
    if not has_content or min_indent == 0 then return s end
    
    local res = table()
    for _, l in ipairs(lines) do
        if #l >= min_indent then
            res:insert(l:sub(min_indent + 1))
        else
            res:insert(l)
        end
    end
    return res:concat('\n')
end

-- [FIX] 纯 Lua 实现的 wrap
function string.wrap(s, width)
    width = width or 70
    local lines = {}
    local current_line = {}
    local current_len = 0

    for word in s:gmatch("%S+") do
        local word_len = #word
        if current_len + word_len + #current_line > width and current_len > 0 then
            table.insert(lines, table.concat(current_line, " "))
            current_line = {word}
            current_len = word_len
        else
            table.insert(current_line, word)
            current_len = current_len + word_len
        end
    end
    
    if #current_line > 0 then
        table.insert(lines, table.concat(current_line, " "))
    end
    
    return table.concat(lines, "\n") .. "\n"
end

-- === 3. Path 增强 ===
-- [FIX] 获取 Path 类元表
local path_class = getmetatable(path_instance)

function path_class:walk_files()
    local list = table()
    for f in os.rlistdir(self.path) do
        list:insert(path_instance(f))
    end
    return list
end

function path_class:walk()
    return coroutine.wrap(function()
        local function yield_tree(curr)
            local dirs, files = table(), table()
            for fname in os.listdir(curr.path) do
                local p = curr / fname
                if os.isdir(p.path) then 
                    dirs:insert(p) 
                else 
                    files:insert(p) 
                end
            end
            coroutine.yield(curr, dirs, files)
            for _, d in ipairs(dirs) do yield_tree(d) end
        end
        yield_tree(self)
    end)
end

function path_class:rmtree()
    if not os.isdir(self.path) then 
        os.remove(self.path)
        return
    end

    if os.rmdir then
        for fname in os.listdir(self.path) do
            local p = self / fname
            if os.isdir(p.path) then
                p:rmtree()
            else
                os.remove(p.path)
            end
        end
        os.rmdir(self.path)
    end
end