-- tests/test_ext_boost.lua

-- 如果没有通过环境变量设置路径（本地手动运行时），尝试自动添加 vendor 路径
if not os.getenv("LUA_PATH") then
    package.path = "vendor/lua-ext/?.lua;vendor/lua-ext/?/init.lua;" .. package.path
    package.path = "vendor/luaunit/?.lua;" .. package.path
    -- 允许本地直接运行，找到 ./ext-boost/init.lua
    package.path = "./?.lua;./?/init.lua;" .. package.path
end

local lu = require('luaunit')

-- 尝试加载被测模块
local status, ext = pcall(require, 'ext-boost')

if not status then
    print("\n[ERROR] 模块加载失败！")
    print("当前的 package.path: " .. package.path)
    error("\n无法加载 ext-boost。请检查 CI 配置或本地 submodule。\n错误详情: " .. tostring(ext))
end

-- ============================================================================
-- 辅助函数
-- ============================================================================

local function assertTableEquals(actual, expected, msg)
    if type(actual) == 'table' and actual.toTable then actual = actual:toTable() end
    if type(actual) == 'table' then
        local t = {}
        for k,v in pairs(actual) do t[k] = v end
        actual = t
    end
    lu.assertEquals(actual, expected, msg)
end

-- ============================================================================
-- 1. 函数式编程 (Func)
-- ============================================================================
TestFunc = {}
    function TestFunc:testBasicMap()
        local nums = ext.table{1, 2, 3, 4}
        local res = nums:map(ext._1 * 2 + 1)
        lu.assertEquals(res:concat(","), "3,5,7,9", "Basic Map (_1 * 2 + 1)")
    end

    function TestFunc:testMultiArg()
        local add3 = ext._1 + ext._2 + ext._3
        lu.assertEquals(add3(1, 2, 3), 6, "Multi-arg (_1+_2+_3)")
    end

    function TestFunc:testComparison()
        local nums = ext.table{1, 2, 3, 4}
        -- [JIT 修复] 混合类型比较必须用 ext.func.Gt 等函数
        local filter_res = nums:filter(ext.func.Gt(ext._1, 2))
        lu.assertEquals(filter_res:concat(","), "3,4", "Comparison (Gt(_1, 2))")
    end

    function TestFunc:testLogicNot()
        local not_fn = ext.func.Not(ext._1)
        lu.assertIsFalse(not_fn(true), "Logic Not")
    end

    function TestFunc:testStringConcat()
        local concat_fn = ext._1 .. " World"
        lu.assertEquals(concat_fn("Hello"), "Hello World", "String Concat")
    end

    function TestFunc:testLen()
        -- [JIT 修复] 长度操作符需用 Len 函数
        local len_fn = ext.func.Len(ext._1)
        lu.assertEquals(len_fn("abc"), 3, "Length function (Len)")
    end

-- ============================================================================
-- 2. 流式迭代 (Iter)
-- ============================================================================
TestIter = {}
    function TestIter:testRange()
        assertTableEquals(ext.Iter.range(1, 3):toTable(), {1, 2, 3}, "Range Normal")
        assertTableEquals(ext.Iter.range(1, 5, 2):toTable(), {1, 3, 5}, "Range Step")
        lu.assertEquals(ext.Iter.range(5, 1):count(), 0, "Range Empty")
    end

    function TestIter:testChain()
        -- [JIT 修复] 使用 ext.func.Eq
        local chain = ext.Iter.range(1, 10)
            :filter(ext.func.Eq(ext._1 % 2, 0)) -- 偶数
            :map(ext._1 * 10)
            :toTable()
        lu.assertEquals(chain:concat(","), "20,40,60,80,100", "Chain Filter/Map")
    end

    function TestIter:testReduce()
        local empty_iter = ext.Iter.of({})
        lu.assertIsNil(empty_iter:reduce(function(a,b) return a+b end), "Reduce Empty (nil)")
        lu.assertEquals(empty_iter:reduce(function(a,b) return a+b end, 100), 100, "Reduce Empty (Init)")
        lu.assertEquals(ext.Iter.range(1, 4):reduce(ext._1 + ext._2), 10, "Reduce Normal")
    end

    function TestIter:testPairs()
        local dict = {a=1, b=2}
        local dict_count = 0
        for k,v in ext.Iter.pairs(dict) do dict_count = dict_count + v end
        lu.assertEquals(dict_count, 3, "Iter Pairs")
    end

-- ============================================================================
-- 3. 集合数据结构 (Set)
-- ============================================================================
TestSet = {}
    function TestSet:setUp()
        self.s1 = ext.Set{'a', 'b', 'c'}
        self.s2 = ext.Set{'b', 'c', 'd'}
    end

    function TestSet:testContains()
        lu.assertTrue(self.s1:contains('a'), "Contains Existing")
        lu.assertIsFalse(self.s1:contains('z'), "Not Contains")
    end

    function TestSet:testUnion()
        local s_union = self.s1 + self.s2
        lu.assertEquals(s_union:len(), 4, "Set Union Len")
        lu.assertTrue(s_union:contains('d'), "Set Union Content")
    end

    function TestSet:testIntersection()
        local s_inter = self.s1 * self.s2
        lu.assertEquals(s_inter:len(), 2, "Set Inter Len")
        lu.assertTrue(s_inter:contains('b'), "Inter contains b")
        lu.assertTrue(s_inter:contains('c'), "Inter contains c")
    end

    function TestSet:testDifference()
        local s_diff = self.s1 - self.s2
        lu.assertEquals(s_diff:len(), 1, "Set Diff Len")
        lu.assertTrue(s_diff:contains('a'), "Set Diff Content")
    end

    function TestSet:testEmpty()
        local s_empty = ext.Set()
        lu.assertEquals(s_empty:len(), 0, "Empty Set Len")
        s_empty:remove('ghost') -- Should not error
        lu.assertTrue(true, "Remove non-exist")
    end

-- ============================================================================
-- 4. 有序字典 (OrderedMap)
-- ============================================================================
TestOrderedMap = {}
    function TestOrderedMap:testBasics()
        local omap = ext.OrderedMap()
        omap.b = 2
        omap.a = 1
        omap.c = 3

        local keys = omap:keys()
        lu.assertEquals(keys:concat(","), "b,a,c", "Insertion Order")

        omap:sort(function(k1, k2) return k1 < k2 end)
        lu.assertEquals(omap:keys():concat(","), "a,b,c", "Sorted Keys")
        lu.assertEquals(omap.b, 2, "Value Access")

        omap.b = nil
        omap.a = 10
        lu.assertEquals(omap:keys():concat(","), "a,c", "Delete & Update keys")
        lu.assertEquals(omap.a, 10, "Delete & Update val")
    end

    function TestOrderedMap:testInit()
        local omap2 = ext.OrderedMap({x=10, y=20})
        -- 注意：table 初始化顺序不定，只能检查值是否存在
        lu.assertEquals(omap2.x, 10)
        lu.assertEquals(omap2.y, 20)
    end

-- ============================================================================
-- 5. 多值字典 (MultiMap)
-- ============================================================================
TestMultiMap = {}
    function TestMultiMap:testOperations()
        local mm = ext.MultiMap()
        mm:set('key1', 'val1')
        mm:set('key1', 'val2')
        mm:set('key2', 'val3')

        local k1_vals = mm:get('key1')
        lu.assertEquals(#k1_vals, 2, "Multi Values Len")
        -- 检查包含关系
        local found1, found2 = false, false
        for _, v in ipairs(k1_vals) do
            if v == 'val1' then found1 = true end
            if v == 'val2' then found2 = true end
        end
        lu.assertTrue(found1 and found2, "Multi Values Content")
        
        lu.assertEquals(#mm:get('ghost'), 0, "Get Non-exist")
    end

-- ============================================================================
-- 6. 二维数组 (Array2D)
-- ============================================================================
TestArray2D = {}
    function TestArray2D:testBasics()
        local arr = ext.Array2D.new(3, 3, 0)
        arr:set(1, 1, 10)
        arr:set(2, 2, 20)
        arr:set(3, 3, 30)

        lu.assertEquals(arr:get(1,1), 10, "Get (1,1)")
        lu.assertEquals(arr:get(2,2), 20, "Get (2,2)")
        lu.assertEquals(arr:get(1,2), 0, "Get Default")
        lu.assertIsNil(arr:get(0, 0), "Get Out of Bounds")

        local col2 = arr:column(2)
        lu.assertEquals(col2:concat(","), "0,20,0", "Column Extract")

        local iter_count = 0
        for r, c, v in arr:iter() do iter_count = iter_count + 1 end
        lu.assertEquals(iter_count, 9, "Iterator Count")
    end

-- ============================================================================
-- 7. 字符串增强 (String Patches)
-- ============================================================================
TestStringPatches = {}
    function TestStringPatches:testDedent()
        local raw_code = [[
            line1
              line2
            line3
        ]]
        local dedented = ext.string.dedent(raw_code)
        lu.assertStrContains(dedented, "line1\n  line2\nline3", "Dedent Mixed")
    end

    function TestStringPatches:testWrap()
        local long_str = "12345 67890 abcde fghij"
        local wrapped = ext.string.wrap(long_str, 5)
        -- 验证是否换行
        lu.assertStrContains(wrapped, "\n", "String Wrap contains newline")
        lu.assertStrContains(wrapped, "12345", "String Wrap content")
    end

-- ============================================================================
-- 8. 表增强 (Table Patches)
-- ============================================================================
TestTablePatches = {}
    function TestTablePatches:testZip()
        local t1 = ext.table{1, 2, 3}
        local t2 = ext.table{'a', 'b'}
        local zipped = ext.table.zip(t1, t2)
        lu.assertEquals(#zipped, 2, "Zip Length")
        lu.assertEquals(zipped[1]:concat("-"), "1-a", "Zip Content 1")
    end

    function TestTablePatches:testIter()
        local t1 = ext.table{1, 2, 3}
        local t_iter_sum = 0
        for v in t1:iter() do t_iter_sum = t_iter_sum + v end
        lu.assertEquals(t_iter_sum, 6, "Table:iter() patch")
    end

-- ============================================================================
-- 9. 路径与文件 (Path & IO)
-- ============================================================================
TestPathIO = {}
    function TestPathIO:setUp()
        self.root_name = "test_temp_dir_unit"
        self.p_root = ext.path(self.root_name)
        -- 清理之前可能残留的目录
        if self.p_root:isdir() then self.p_root:rmtree() end
    end

    function TestPathIO:tearDown()
        -- 测试后清理
        if self.p_root:isdir() then self.p_root:rmtree() end
    end

    function TestPathIO:testFileSystemOps()
        local p_sub = self.p_root / "subdir"
        local p_file = p_sub / "test.txt"

        -- 创建目录和文件
        ext.os.mkdir(p_sub.path, true)
        ext.io.writefile(p_file.path, "content")

        lu.assertTrue(p_sub:isdir(), "Dir Exists")
        lu.assertTrue(p_file:exists(), "File Exists")

        -- 测试 Walk
        local walked_files = 0
        for root, dirs, files in self.p_root:walk() do
            walked_files = walked_files + #files
        end
        lu.assertTrue(walked_files >= 1, "Walk Files Count")

        -- Walk Files (Flat)
        local flat_list = self.p_root:walk_files()
        lu.assertEquals(#flat_list, 1, "Walk Files Flat Count")
        lu.assertStrContains(flat_list[1].path, "test.txt", "Walk Files Flat Name")

        -- 测试删除树
        self.p_root:rmtree()
        lu.assertIsFalse(self.p_root:exists(), "Rmtree verify")
    end

-- ============================================================================
-- 10. 配置与数据格式
-- ============================================================================
TestDataFormats = {}
    function TestDataFormats:testConfig()
        local ini_str = [[
global_val = 100
[section1]
key = true
val = 3.14
]]
        local ini_file = "test_unit.ini"
        ext.io.writefile(ini_file, ini_str)
        
        local conf, err = ext.config.read(ini_file)
        ext.os.remove(ini_file)
        
        lu.assertNotIsNil(conf, "Config read failed: " .. tostring(err))
        lu.assertEquals(conf._.global_val, 100, "INI Global")
        lu.assertEquals(conf.section1.val, 3.14, "INI Number")
        lu.assertTrue(conf.section1.key, "INI Boolean")
    end

    function TestDataFormats:testCSV()
        local csv_str = 'id,val\n1,"hello, world"'
        local csv_file = "test_unit.csv"
        ext.io.writefile(csv_file, csv_str)
        
        local csv_data = ext.csv.read(csv_file)
        ext.os.remove(csv_file)
        
        lu.assertEquals(#csv_data, 1, "CSV Rows")
        lu.assertEquals(csv_data[1].val, "hello, world", "CSV Quote")
    end

    function TestDataFormats:testXML()
        local xml_str = [[<root><item id="1">A</item></root>]]
        local xml_doc = ext.xml.parse(xml_str)
        lu.assertEquals(xml_doc.tag, "root", "XML Tag")
        lu.assertEquals(#xml_doc.children, 1, "XML Children")
        lu.assertEquals(xml_doc.children[1].tag, "item")
        lu.assertEquals(xml_doc.children[1].attr.id, "1")
    end

    function TestDataFormats:testTemplate()
        local tpl = ext.template("Hi ${n}", {n="Lua"})
        lu.assertEquals(tpl, "Hi Lua", "Template replacement")
    end

-- ============================================================================
-- 11. CLI
-- ============================================================================
TestCLI = {}
    function TestCLI:testParse()
        local args = {"--verbose", "-l", "3", "in.txt"}
        local schema = { { "verbose", "v", type="flag" }, { "level", "l", type="number" } }
        local opts = ext.cli.parse(args, schema)
        
        lu.assertTrue(opts.verbose, "CLI Flag")
        lu.assertEquals(opts.level, 3, "CLI Number")
        lu.assertEquals(opts._rest[1], "in.txt", "CLI Rest")
    end

-- ============================================================================
-- 12. Date
-- ============================================================================
TestDate = {}
    function TestDate:testOperations()
        local d1 = ext.Date("2023-01-01 00:00:00")
        local d2 = d1 + {day=1}
        lu.assertEquals(d2:format("%Y-%m-%d"), "2023-01-02", "Date Add")
        
        local d3 = ext.Date("2023-01-02 00:00:00")
        local diff = d3 - d1
        -- 24 hours in seconds
        lu.assertEquals(diff, 24 * 3600, "Date Diff")
    end

-- ============================================================================
-- 执行测试
-- ============================================================================
os.exit(lu.LuaUnit.run())