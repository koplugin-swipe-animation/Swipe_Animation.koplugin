local ok, err = pcall(function()
    local Device = require("device")
    if not Device:canDoSwipeAnimation() then
        return
    end

    local ReaderMenu = require("apps/reader/modules/readermenu")
    local reader_menu_order = require("ui/elements/reader_menu_order")
    local Screen = Device.screen
    local UIManager = require("ui/uimanager")
    local T = require("ffi/util").template

    local MENU_KEY = "swipe_animation_settings"   

    if ReaderMenu._swipe_animation_settings_patch_applied then  
        return
    end
    ReaderMenu._swipe_animation_settings_patch_applied = true

    local function ensureMenuKey(order_table)
        if type(order_table) ~= "table" then
            return
        end

        for i = #order_table, 1, -1 do
            if order_table[i] == MENU_KEY then
                table.remove(order_table, i)
            end
        end

        for index, key in ipairs(order_table) do
            if key == "page_turns" then
                table.insert(order_table, index + 1, MENU_KEY)
                return
            end
        end

        table.insert(order_table, MENU_KEY)
    end

    ensureMenuKey(reader_menu_order.taps_and_gestures)

    local function getAutomaticSwipeAnimationDelayMs()
        local screen_w = Screen.bb:getWidth()
        local screen_h = Screen.bb:getHeight()
        local is_landscape = screen_w > screen_h
        if is_landscape then
            return 10
        end

        local rotation_mode = Screen:getRotationMode()
        local native_rotation_mode = Screen.native_rotation_mode or Screen.DEVICE_ROTATED_UPRIGHT
        local is_opposite_portrait = bit.band(rotation_mode - native_rotation_mode, 3) == 2
        return is_opposite_portrait and 16 or 22
    end

    local function isLandscapeScreen()
        return Screen.bb:getWidth() > Screen.bb:getHeight()
    end

    local function getSwipeAnimationDelaySettingKey()
        if isLandscapeScreen() then
            return "swipe_animation_delay_ms_horizontal", "横屏"
        end
        return "swipe_animation_delay_ms_vertical", "竖屏"
    end

    local function getConfiguredSwipeAnimationDelayMs()
        local key = getSwipeAnimationDelaySettingKey()
        local delay_ms = tonumber(G_reader_settings:readSetting(key)) or 0
        if delay_ms <= 0 then
            delay_ms = tonumber(G_reader_settings:readSetting("swipe_animation_delay_ms")) or 0
        end
        if delay_ms > 0 then
            return delay_ms
        end
        return nil
    end

    local function saveConfiguredSwipeAnimationDelayMs(delay_ms)
        local key = getSwipeAnimationDelaySettingKey()
        local legacy_delay_ms = tonumber(G_reader_settings:readSetting("swipe_animation_delay_ms")) or 0
        if legacy_delay_ms > 0 then
            if (tonumber(G_reader_settings:readSetting("swipe_animation_delay_ms_vertical")) or 0) <= 0 then
                G_reader_settings:saveSetting("swipe_animation_delay_ms_vertical", legacy_delay_ms)
            end
            if (tonumber(G_reader_settings:readSetting("swipe_animation_delay_ms_horizontal")) or 0) <= 0 then
                G_reader_settings:saveSetting("swipe_animation_delay_ms_horizontal", legacy_delay_ms)
            end
            G_reader_settings:delSetting("swipe_animation_delay_ms")
        end
        if delay_ms and delay_ms > 0 then
            G_reader_settings:saveSetting(key, delay_ms)
        else
            G_reader_settings:delSetting(key)
        end
    end

    -- ==================== Refresh mode for software swipe animation ====================
    -- Allows user to choose between "ui", "partial", "fast" for the strip refreshes
    -- in the software page-turn animation (implemented in UIManager:_repaint).
    local function getSwipeAnimationRefreshMode()
        local mode = G_reader_settings:readSetting("swipe_animation_refresh_mode")
        if mode == "partial" or mode == "fast" then
            return mode
        end
        return "ui"
    end

    local function saveSwipeAnimationRefreshMode(mode)
        if mode == "ui" then
            G_reader_settings:delSetting("swipe_animation_refresh_mode")
        elseif mode == "partial" or mode == "fast" then
            G_reader_settings:saveSetting("swipe_animation_refresh_mode", mode)
        end
    end

    local function showSwipeAnimationDelayInputDialog(touchmenu_instance)
        local InputDialog = require("ui/widget/inputdialog")
        local current_value = tostring(getConfiguredSwipeAnimationDelayMs() or getAutomaticSwipeAnimationDelayMs())
        local default_delay_ms = getAutomaticSwipeAnimationDelayMs()
        local _, orientation_label = getSwipeAnimationDelaySettingKey()
        local input_dialog

        input_dialog = InputDialog:new{
            title = "动画帧延迟",
            input = current_value,
            input_type = "number",
            description = T([[
输入每一帧之间的延迟，单位为毫秒。

数值越低，速度越快，但可能残影更明显。
数值越高，速度越慢，但显示可能更干净。

当前保存方向：%1
当前默认值：%2 毫秒]], orientation_label, default_delay_ms),
            buttons = {
                {
                    {
                        text = "取消",
                        callback = function()
                            UIManager:close(input_dialog)
                        end,
                    },
                    {
                        text = "恢复默认",
                        callback = function()
                            saveConfiguredSwipeAnimationDelayMs(nil)
                            if touchmenu_instance then touchmenu_instance:updateItems() end
                            UIManager:close(input_dialog)
                        end,
                    },
                    {
                        text = "保存",
                        is_enter_default = true,
                        callback = function()
                            local value = input_dialog:getInputValue()
                            if not value or value < 1 then
                                saveConfiguredSwipeAnimationDelayMs(nil)
                            else
                                saveConfiguredSwipeAnimationDelayMs(value)
                            end
                            if touchmenu_instance then touchmenu_instance:updateItems() end
                            UIManager:close(input_dialog)
                        end,
                    },
                },
            },
        }
        UIManager:show(input_dialog)
        input_dialog:onShowKeyboard()
    end

    local function buildSwipeAnimationSubItems()
        return {
            -- NEW: Refresh mode chooser for the animation strips (put above delay as requested)
            {
                text = "翻页动画刷新模式",
                enabled_func = function()
                    return G_reader_settings:isTrue("swipe_animations")
                end,
                help_text = [[
选择软件翻页动画中，每一小条画面更新时使用的刷新类型。

• UI刷新（默认）：平衡画质与速度，适合大多数情况。
• Partial刷新：对纯文字/白底内容优化，残影控制较好。
• Fast刷新：速度最快，适合追求流畅度但可接受较多残影的场景。

更改后立即生效。]],
                sub_item_table = {
                    {
                        text = "UI刷新（默认，推荐）",
                        checked_func = function()
                            return getSwipeAnimationRefreshMode() == "ui"
                        end,
                        callback = function(touchmenu_instance)
                            saveSwipeAnimationRefreshMode("ui")
                            if touchmenu_instance then
                                touchmenu_instance:updateItems()
                            end
                        end,
                    },
                    {
                        text = "Partial刷新（文字优化）",
                        checked_func = function()
                            return getSwipeAnimationRefreshMode() == "partial"
                        end,
                        callback = function(touchmenu_instance)
                            saveSwipeAnimationRefreshMode("partial")
                            if touchmenu_instance then
                                touchmenu_instance:updateItems()
                            end
                        end,
                    },
                    {
                        text = "Fast刷新（最快，易残影）",
                        checked_func = function()
                            return getSwipeAnimationRefreshMode() == "fast"
                        end,
                        callback = function(touchmenu_instance)
                            saveSwipeAnimationRefreshMode("fast")
                            if touchmenu_instance then
                                touchmenu_instance:updateItems()
                            end
                        end,
                    },
                },
            },
            -- Delay setting (existing, now below refresh mode)
            {
                text_func = function()
                    local configured = getConfiguredSwipeAnimationDelayMs()
                    local _, orientation_label = getSwipeAnimationDelaySettingKey()
                    if configured then
                        return T("%1动画帧延迟：%2 毫秒", orientation_label, configured)
                    end
                    return T("%1动画帧延迟：默认 %2 毫秒", orientation_label, getAutomaticSwipeAnimationDelayMs())
                end,
                enabled_func = function()
                    return G_reader_settings:isTrue("swipe_animations")
                end,
                keep_menu_open = true,
                callback = function(touchmenu_instance)
                    showSwipeAnimationDelayInputDialog(touchmenu_instance)
                end,
                help_text = [[
调整翻页动画每一帧之间的停顿时间。

直接输入毫秒数即可。竖屏和横屏会分别记住各自的数值。未自定义时，会显示当前方向使用的默认值。]],
            },
        }
    end

    local function buildSettingsMenu()
        return {
            text = "翻页动画设置",        
            enabled_func = function()
                return G_reader_settings:isTrue("swipe_animations")
            end,
            help_text = [[
调整软件翻页动画的速度（帧延迟）和画面更新刷新模式（UI / Partial / Fast）。

刷新模式直接影响动画期间每条画面的更新质量与残影表现。]],   
            sub_item_table = buildSwipeAnimationSubItems(),
        }
    end

    local function injectSettingsMenu(menu_items)
        if type(menu_items) ~= "table" then
            return false
        end

        local existing = menu_items[MENU_KEY]
        if type(existing) == "table" and existing._swipe_animation_settings_patch_item then
            existing.sub_item_table = buildSwipeAnimationSubItems()
            return true
        end

        local item = buildSettingsMenu()
        item._swipe_animation_settings_patch_item = true
        menu_items[MENU_KEY] = item
        return true
    end

    local orig_setUpdateItemTable = ReaderMenu.setUpdateItemTable
    ReaderMenu.setUpdateItemTable = function(self, ...)
        injectSettingsMenu(self.menu_items)
        return orig_setUpdateItemTable(self, ...)
    end
end)

if not ok then
    require("logger").warn("[SwipeAnimationSettingsPatch] failed:", err)
end
