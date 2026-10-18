-- Swipe Animation v4.3: KOReader plugin-only, single Settings menu.
-- Original upstream animation/PDF/settings modules and refresh bridge remain unchanged.
local WidgetContainer = require('ui/widget/container/widgetcontainer')
local logger = require('logger')
local UIManager = require('ui/uimanager')

local SwipeAnimationPlugin = WidgetContainer:extend{
    name = 'swipeanimation',
    is_doc_only = true,
}

local function language_text(zh, en)
    local language = G_reader_settings:readSetting('language') or ''
    return language:match('^zh') and zh or en
end

local CONTROL_KEY = 'swipeanimation_control'
local UPSTREAM_KEY = 'swipe_animation_settings'

-- Both the upstream patch and MenuFix used to register under
-- Settings > Taps and gestures. Remove both registrations and register
-- only our combined entry directly under the Settings (gear) tab.
local function move_to_settings_tab()
    local order = require('ui/elements/reader_menu_order')
    for _, group_name in ipairs({ 'taps_and_gestures', 'setting' }) do
        local group = order[group_name]
        if type(group) == 'table' then
            for i = #group, 1, -1 do
                if group[i] == CONTROL_KEY or group[i] == UPSTREAM_KEY then
                    table.remove(group, i)
                end
            end
        end
    end
    local settings_order = order.setting
    if type(settings_order) ~= 'table' then
        logger.warn('[SwipeAnimation:v4.3] Settings tab order unavailable')
        return
    end
    for i, key in ipairs(settings_order) do
        if key == 'taps_and_gestures' then
            table.insert(settings_order, i + 1, CONTROL_KEY)
            return
        end
    end
    table.insert(settings_order, CONTROL_KEY)
end

function SwipeAnimationPlugin:init()
    self.active = false
    self.failure = language_text('初始化中', 'Initializing')

    -- Keep the diagnostic entry available even when initialization fails.
    if self.ui and self.ui.menu then
        self.ui.menu:registerToMainMenu(self)
    end
    -- Upstream settings also appends its old menu entry to a different tab
    -- during startup; relocate after loading the upstream module as well.
    move_to_settings_tab()

    if UIManager._swipeanimation_v43_runtime_installed then
        self.active = true
        self.failure = nil
        return
    end
    if not self.path then
        self.failure = 'Plugin path unavailable'
        logger.warn('[SwipeAnimation:v4.3] ' .. self.failure)
        return
    end

    local bridge_ok, bridge = pcall(dofile, self.path .. '/runtime_bridge.lua')
    if not bridge_ok then
        self.failure = tostring(bridge)
        logger.warn('[SwipeAnimation:v4.3] Cannot load runtime bridge:', bridge)
        return
    end
    local ok_pre, pre_err = bridge.preflight()
    if not ok_pre then
        self.failure = tostring(pre_err)
        logger.warn('[SwipeAnimation:v4.3] Incompatible environment:', pre_err)
        return
    end

    for _, filename in ipairs({
        'upstream_core.lua',
        'upstream_settings.lua',
        'upstream_pdf.lua',
    }) do
        local ok, err = pcall(dofile, self.path .. '/' .. filename)
        if not ok then
            self.failure = 'Failed to load ' .. filename .. ': ' .. tostring(err)
            logger.warn('[SwipeAnimation:v4.3] ', self.failure)
            move_to_settings_tab()
            return
        end
    end
    -- Undo the upstream settings module's old order insertion.
    move_to_settings_tab()

    local ok_install, installed, err = pcall(bridge.install)
    if not ok_install or not installed then
        self.failure = 'Runtime hook failed: ' .. tostring(err or installed)
        logger.warn('[SwipeAnimation:v4.3] ', self.failure)
        return
    end

    self.active = true
    self.failure = nil
    logger.info('[SwipeAnimation:v4.3] Plugin loaded with single Settings menu')
end

-- Hide the redundant built-in checkbox under Settings > Taps and gestures
-- > Page turns. It is inserted by KOReader solely because upstream's
-- Device.canDoSwipeAnimation override reports true. Our checkbox below
-- changes the same swipe_animations setting.
local function hide_redundant_native_toggle(menu_items)
    local page_turns = menu_items.page_turns
    if type(page_turns) ~= 'table' or type(page_turns.sub_item_table) ~= 'table' then
        return
    end
    local native_text = require('gettext')('Page turn animations')
    for i = #page_turns.sub_item_table, 1, -1 do
        local item = page_turns.sub_item_table[i]
        if type(item) == 'table' and item.text == native_text then
            table.remove(page_turns.sub_item_table, i)
        end
    end
end

function SwipeAnimationPlugin:addToMainMenu(menu_items)
    -- The upstream settings module injects the original menu item just
    -- before this plugin's addToMainMenu callback. Consume its original
    -- submenu actions, then remove the old top-level item (avoids orphaned
    -- 'NEW: Swipe animation settings' in KOReader's menu sorter).
    local upstream_item = menu_items[UPSTREAM_KEY]
    menu_items[UPSTREAM_KEY] = nil
    hide_redundant_native_toggle(menu_items)

    local subitems = {
        {
            text = language_text('启用翻页动画', 'Enable page turn animations'),
            checked_func = function()
                return self.active and G_reader_settings:readSetting('swipe_animations') ~= false
            end,
            enabled_func = function() return self.active end,
            callback = function(menu)
                if not self.active then return end
                local enable = G_reader_settings:readSetting('swipe_animations') == false
                G_reader_settings:saveSetting('swipe_animations', enable)
                if menu then menu:updateItems() end
            end,
            separator = true,
        },
    }

    -- Inline original v4.3 menu items instead of nesting a second menu.
    -- Retain each item's original callbacks, labels, descriptions, and
    -- submenus. Only add a runtime-compatible enabled check.
    if type(upstream_item) == 'table' and type(upstream_item.sub_item_table) == 'table' then
        for _, item in ipairs(upstream_item.sub_item_table) do
            local merged = {}
            for k, v in pairs(item) do merged[k] = v end
            local upstream_enabled = merged.enabled_func
            merged.enabled_func = function(...)
                return self.active and (not upstream_enabled or upstream_enabled(...))
            end
            table.insert(subitems, merged)
        end
    end

    table.insert(subitems, {
        separator = true,
        text_func = function()
            return self.active
                and language_text('运行状态：已加载', 'Status: loaded')
                or language_text('运行状态：加载失败', 'Status: load failed')
        end,
        callback = function()
            UIManager:show(require('ui/widget/infomessage'):new{
                text = self.active
                    and language_text('动画模块与刷新接口已初始化。请打开书籍实测翻页效果。',
                                      'Animation engine and repaint hook initialized; test a book on your device.')
                    or language_text('初始化失败：', 'Initialization failed: ') .. tostring(self.failure),
            })
        end,
    })
    menu_items[CONTROL_KEY] = {
        text = language_text('翻页动画设置', 'Swipe animation settings'),
        sub_item_table = subitems,
    }
end

function SwipeAnimationPlugin:stopPlugin()
    -- Runtime hooks modify process-wide Lua state; a restart clears them.
    return true
end

return SwipeAnimationPlugin
