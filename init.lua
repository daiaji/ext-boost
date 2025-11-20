-- ext-boost/init.lua

-- 1. 确保 lua-ext 的环境补丁已应用
require 'ext.ext' 

local ext = {}

-- === 挂载 lua-ext 原有核心模块 ===
ext.table     = require 'ext.table'
ext.string    = require 'ext.string'
ext.io        = require 'ext.io'
ext.os        = require 'ext.os'
ext.path      = require 'ext.path'
ext.math      = require 'ext.math'
ext.coroutine = require 'ext.coroutine'
ext.class     = require 'ext.class'
ext.tolua     = require 'ext.tolua'
ext.cmdline   = require 'ext.cmdline'
ext.op        = require 'ext.op'
ext.assert    = require 'ext.assert'

-- === 挂载 ext-boost 增强模块 ===

-- 核心数据结构
ext.Iter       = require 'ext-boost.iter'
ext.Set        = require 'ext-boost.set'
ext.OrderedMap = require 'ext-boost.ordered_map'
ext.MultiMap   = require 'ext-boost.multimap'

-- 根据环境加载 Array2D (FFI/Table)
ext.Array2D    = require 'ext-boost.array2d_ffi'

-- 函数式编程
local func     = require 'ext-boost.func'
ext.func       = func
ext._1         = func._1
ext._2         = func._2
ext._3         = func._3
ext._4         = func._4
ext._5         = func._5
ext.P          = func.P

-- 实用工具
ext.Date       = require 'ext-boost.date'
ext.cli        = require 'ext-boost.cli'
ext.config     = require 'ext-boost.config'
ext.template   = require 'ext-boost.template'
ext.csv        = require 'ext-boost.csv'
ext.xml        = require 'ext-boost.xml'

-- 注入补丁 (修改原生对象)
require 'ext-boost.patches'

return ext