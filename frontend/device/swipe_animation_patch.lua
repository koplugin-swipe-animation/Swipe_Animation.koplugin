-- 通用 MTK 设备补丁
-- 作用：强制把 isMTK() 返回 false，让 uimanager.lua 走软件翻页动画

local Device = require("device")

if Device.isMTK and G_reader_settings:isTrue("swipe_animations") then
    Device.isMTK = function(self)
        return false
    end
end

return true