-- This is a stage-2 patch because Device.screen must already be initialized.
-- Keep the generic software-animation direction in sync with the MTK
-- framebuffer's hardware swipe direction.
--
-- framebuffer_mxcfb replaces framebuffer:setSwipeDirection() on MTK devices.
-- Its implementation only updates update_data.swipe_data.direction, while the
-- software animation reads Screen.swipe_forward. Preserve both interfaces so
-- MTK Kindles use the same forward/backward animation directions as the other
-- Kindles, without disabling the native MTK ioctl setup.
local ok, err = pcall(function()
    local Device = require("device")

    if not Device.isMTK or not Device:isMTK() then
        return
    end

    local Screen = Device.screen
    if not Screen or type(Screen.setSwipeDirection) ~= "function"
            or Screen._mtk_swipe_direction_sync_patch_applied then
        return
    end

    local original_set_swipe_direction = Screen.setSwipeDirection

    function Screen:setSwipeDirection(direction)
        -- Let the MTK backend retain its rotation-aware hardware direction.
        original_set_swipe_direction(self, direction)

        -- Match ffi/framebuffer.lua's generic interface for software animation.
        self.swipe_forward = direction
    end

    Screen._mtk_swipe_direction_sync_patch_applied = true
end)

if not ok then
    require("logger").warn("[MTKSwipeDirectionPatch] failed:", err)
end
