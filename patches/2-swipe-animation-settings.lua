local ok, err = pcall(function()
    local Device = require("device")

    -- Force-enable the software swipe animation capability.
    -- The generic framebuffer has no hardware animation support, but the
    -- software animation in UIManager:_repaint handles the effect, so we
    -- always claim the capability to expose the "Page turn animations"
    -- toggle and keep the PageChangeAnimation event plumbing active.
    Device.canDoSwipeAnimation = function()
        return true
    end

    local ReaderMenu = require("apps/reader/modules/readermenu")
    local reader_menu_order = require("ui/elements/reader_menu_order")
    local Screen = Device.screen
    local UIManager = require("ui/uimanager")
    local T = require("ffi/util").template

    -- Localized strings. English is the gettext source language; until these
    -- strings are added to KOReader's l10n catalogs, provide a built-in
    -- Chinese translation for Chinese interfaces so both locales read fine.
    local GetText = require("gettext")
    local interface_lang = G_reader_settings:readSetting("language") or ""
    local zh_ui = interface_lang:match("^zh") and true or false
    local pt_BR_ui = interface_lang:match("^pt_BR") and true or false

    -- Built-in Chinese translations, used only while KOReader's l10n
    -- catalogs have no translation for a msgid yet.
    local zh_fallback = {
        ["Animation frame delay"] = "动画帧延迟",
        ["Cancel"] = "取消",
        ["Restore default"] = "恢复默认",
        ["Save"] = "保存",
        ["Swipe animation refresh mode"] = "翻页动画刷新模式",
        ["UI refresh (default, recommended)"] = "UI刷新（默认，推荐）",
        ["Fast refresh (fastest, more ghosting)"] = "Fast刷新（最快，易残影）",
        ["%1 animation frame delay: %2 ms"] = "%1动画帧延迟：%2 毫秒",
        ["%1 animation frame delay: default %2 ms"] = "%1动画帧延迟：默认 %2 毫秒",
        ["Mild global refresh"] = "轻度全局刷新",
        ["Swipe animation settings"] = "翻页动画设置",
        ["Landscape"] = "横屏",
        ["Portrait"] = "竖屏",
        [ [[
Enter the delay between animation frames, in milliseconds.
0 = no extra pause (pace with strip refresh).
Lower is faster, higher is slower.

Current orientation: %1
Current default: %2 ms]] ] = [[
输入每一帧之间的延迟，单位为毫秒。
0 = 不再额外停顿（节奏交给条带刷新）。
数值越低，速度越快，数值越高，速度越慢。

当前保存方向：%1
当前默认值：%2 毫秒]],
        [ [[
Choose the refresh type used for each strip of the software swipe animation.

• UI refresh (default): balanced quality and speed, suitable for most cases.
• Fast refresh: fastest, best for smoothness when some ghosting is acceptable.

Changes take effect immediately.]] ] = [[
选择软件翻页动画中，每一小条画面更新时使用的刷新类型。

• UI刷新（默认）：平衡画质与速度，适合大多数情况。
• Fast刷新：速度最快，适合追求流畅度但可接受较多残影的场景。

更改后立即生效。]],
        [ [[
Adjust the pause between animation frames.

Enter a value in milliseconds. Portrait and landscape remember their own values.
When unset, the default for the current orientation is shown.]] ] = [[
调整翻页动画每一帧之间的停顿时间。

直接输入毫秒数即可。竖屏和横屏会分别记住各自的数值。未自定义时，会显示当前方向使用的默认值。]],
        [ [[
• Checked: use partial refresh (for text-only content)

• Unchecked: use full refresh (for content with images)]] ] = [[
• 勾选：使用 Partial 刷新（适用于纯文字内容）

• 未勾选：使用 Full 刷新（适用于图文内容）]],
        [ [[
Adjust the speed (frame delay) and refresh mode (UI / Fast) of the software swipe animation.

The refresh mode directly affects the quality and ghosting of each strip update during the animation.]] ] = [[
调整软件翻页动画的速度（帧延迟）和画面更新刷新模式（UI / Fast）。

刷新模式直接影响动画期间每条画面的更新质量与残影表现。]],
    }
    local pt_BR_fallback = {
        ["Animation frame delay"] = "Intervalo entre quadros da animação",
        ["Cancel"] = "Cancelar",
        ["Restore default"] = "Restaurar padrão",
        ["Save"] = "Salvar",
        ["Swipe animation refresh mode"] = "Modo de atualização da animação de deslizar",
        ["UI refresh (default, recommended)"] = "Atualização da interface (padrão, recomendado)",
        ["Fast refresh (fastest, more ghosting)"] = "Atualização rápida (mais veloz, mais ghosting)",
        ["%1 animation frame delay: %2 ms"] = "%1 - intervalo entre quadros: %2 ms",
        ["%1 animation frame delay: default %2 ms"] = "%1 - intervalo entre quadros: padrão (%2 ms)",
        ["Mild global refresh"] = "Atualização global moderada",
        ["Swipe animation settings"] = "Configurações da animação de deslizar",
        ["Landscape"] = "Modo paisagem",
        ["Portrait"] = "Modo retrato",
        [ [[
Enter the delay between animation frames, in milliseconds.
0 = no extra pause (pace with strip refresh).
Lower is faster, higher is slower.

Current orientation: %1
Current default: %2 ms]] ] = [[
Insira o intervalo entre quadros da animação, em milissegundos.
0 = sem pausa extra (ritmo pela atualização das faixas).
Menor é mais rápido, maior é mais lento.

Orientação atual: %1
Padrão atual: %2 ms]],
        [ [[
Choose the refresh type used for each strip of the software swipe animation.

• UI refresh (default): balanced quality and speed, suitable for most cases.
• Fast refresh: fastest, best for smoothness when some ghosting is acceptable.

Changes take effect immediately.]] ] = [[
Escolha o tipo de atualização utilizado para cada segmento da animação de deslizar por software.

• Atualização da interface (padrão): qualidade e velocidade balanceadas, apropriada para a maioria dos casos.
• Atualização rápida: mais rápida, melhor para a suavização quando pouco ghosting é aceitável.

As alterações são aplicadas imediatamente.]],
        [ [[
Adjust the pause between animation frames.

Enter a value in milliseconds. Portrait and landscape remember their own values.
When unset, the default for the current orientation is shown.]] ] = [[
Ajusta a pausa entre quadros da animação.

Insira um valor em milissegundos. Os modos retrato e paisagem memorizam seus respectivos valores. 
Quando inalterado, o padrão para a orientação atual é exibido.]],
        [ [[
• Checked: use partial refresh (for text-only content)

• Unchecked: use full refresh (for content with images)]] ] = [[
• Marcado: utiliza atualização parcial (para conteúdos textuais)

• Desmarcado: utiliza atualização total (para conteúdos com imagens)]],
        [ [[
Adjust the speed (frame delay) and refresh mode (UI / Fast) of the software swipe animation.

The refresh mode directly affects the quality and ghosting of each strip update during the animation.]] ] = [[
Ajusta a velocidade (intervalo de quadros) e o modo de atualização (Interface / Rápido) da animação de deslizar por software.

O modo de atualização impacta diretamente na qualidade e no ghosting de cada faixa de atualização durante a animação.]],
    }

    local function _(msgid)
        -- Prefer a catalog translation once these strings are in l10n.
        local translated = GetText(msgid)
        if translated ~= msgid then
            return translated
        end
        -- Built-in fallback for Chinese interfaces.
        if zh_ui then
            local zh = zh_fallback[msgid]
            if zh then
                return zh
            end
        end
        -- Built-in fallback for Portuguese (Brazil) interfaces.
        if pt_BR_ui then
            local pt_BR= pt_BR_fallback[msgid]
            if pt_BR then
                return pt_BR
            end
        end
        return msgid
    end

    local MENU_KEY = "swipe_animation_settings"

    if ReaderMenu._swipe_animation_settings_patch_applied then
        return
    end
    ReaderMenu._swipe_animation_settings_patch_applied = true

    -- One-time legacy setting migration (runs only once when patch loads)
    do
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
    end

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

    local function isLandscapeScreen()
        return Screen.bb:getWidth() > Screen.bb:getHeight()
    end

    -- Simplified defaults come from UIManager.swipe_animation_defaults
    -- (the single source of truth for the animation tuning).
    local function getAutomaticSwipeAnimationDelayMs()
        local delay_defaults = (UIManager.swipe_animation_defaults or {}).delay_ms or {}
        if isLandscapeScreen() then
            return delay_defaults.landscape or 10
        else
            return delay_defaults.portrait or 20
        end
    end

    local function getSwipeAnimationDelaySettingKey()
        if isLandscapeScreen() then
            return "swipe_animation_delay_ms_horizontal", _("Landscape")
        end
        return "swipe_animation_delay_ms_vertical", _("Portrait")
    end

    local function getConfiguredSwipeAnimationDelayMs()
        local key = getSwipeAnimationDelaySettingKey()
        local delay_ms = tonumber(G_reader_settings:readSetting(key))
        if delay_ms == nil then
            delay_ms = tonumber(G_reader_settings:readSetting("swipe_animation_delay_ms"))
        end
        if delay_ms == nil or delay_ms < 0 then
            return nil
        end
        return delay_ms
    end

    local function saveConfiguredSwipeAnimationDelayMs(delay_ms)
        local key = getSwipeAnimationDelaySettingKey()
        if delay_ms == nil or delay_ms < 0 then
            G_reader_settings:delSetting(key)
        else
            G_reader_settings:saveSetting(key, delay_ms)
        end
    end
    -- ==================== Mild global refresh for the independent counter ====================
    -- When enabled, the periodic clearing refresh (triggered by the independent
    -- counter) uses a partial refresh instead of a true full refresh.
    -- The swipe animation is always skipped on the clearing page.
    local function isMildGlobalRefreshEnabled()
        return G_reader_settings:isTrue("swipe_animation_mild_global_refresh")
    end

    local function toggleMildGlobalRefresh()
        local enabled = not isMildGlobalRefreshEnabled()
        if enabled then
            G_reader_settings:saveSetting("swipe_animation_mild_global_refresh", true)
        else
            G_reader_settings:delSetting("swipe_animation_mild_global_refresh")
        end
    end
    -- ==================== Refresh mode for software swipe animation ====================
    -- Allows user to choose between "ui", "fast" for the strip refreshes
    -- in the software swipe animation (implemented in UIManager:_repaint).
    local function getSwipeAnimationRefreshMode()
        local mode = G_reader_settings:readSetting("swipe_animation_refresh_mode")
        if mode == "fast" then
            return mode
        end
        return "ui"
    end
    
    local function saveSwipeAnimationRefreshMode(mode)
        if mode == "ui" then
            G_reader_settings:delSetting("swipe_animation_refresh_mode")
        elseif mode == "fast" then
            G_reader_settings:saveSetting("swipe_animation_refresh_mode", mode)
        end
    end

    local function showSwipeAnimationDelayInputDialog(touchmenu_instance)
        local InputDialog = require("ui/widget/inputdialog")
        local current_value = tostring(getConfiguredSwipeAnimationDelayMs() or getAutomaticSwipeAnimationDelayMs())
        local default_delay_ms = getAutomaticSwipeAnimationDelayMs()
        local orientation_label = select(2, getSwipeAnimationDelaySettingKey())
        local input_dialog

        input_dialog = InputDialog:new{
            title = _("Animation frame delay"),
            input = current_value,
            input_type = "number",
            description = T(_([[
Enter the delay between animation frames, in milliseconds.
0 = no extra pause (pace with strip refresh).
Lower is faster, higher is slower.

Current orientation: %1
Current default: %2 ms]]), orientation_label, default_delay_ms),
            buttons = {
                {
                    {
                        text = _("Cancel"),
                        callback = function()
                            UIManager:close(input_dialog)
                        end,
                    },
                    {
                        text = _("Restore default"),
                        callback = function()
                            saveConfiguredSwipeAnimationDelayMs(nil)
                            if touchmenu_instance then touchmenu_instance:updateItems() end
                            UIManager:close(input_dialog)
                        end,
                    },
                    {
                        text = _("Save"),
                        is_enter_default = true,
                        callback = function()
                            local value = input_dialog:getInputValue()
                            if value == nil or value < 0 then
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
            -- Refresh mode chooser
            {
                text = _("Swipe animation refresh mode"),
                enabled_func = function()
                    return G_reader_settings:isTrue("swipe_animations")
                end,
                help_text = _([[
Choose the refresh type used for each strip of the software swipe animation.

• UI refresh (default): balanced quality and speed, suitable for most cases.
• Fast refresh: fastest, best for smoothness when some ghosting is acceptable.

Changes take effect immediately.]]),
                sub_item_table = {
                    {
                        text = _("UI refresh (default, recommended)"),
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
                        text = _("Fast refresh (fastest, more ghosting)"),
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
            -- Delay setting 
            {
                text_func = function()
                    local configured = getConfiguredSwipeAnimationDelayMs()
                    local orientation_label = select(2, getSwipeAnimationDelaySettingKey())
                    if configured then
                        return T(_("%1 animation frame delay: %2 ms"), orientation_label, configured)
                    end
                    return T(_("%1 animation frame delay: default %2 ms"), orientation_label, getAutomaticSwipeAnimationDelayMs())
                end,
                enabled_func = function()
                    return G_reader_settings:isTrue("swipe_animations")
                end,
                keep_menu_open = true,
                callback = function(touchmenu_instance)
                    showSwipeAnimationDelayInputDialog(touchmenu_instance)
                end,
                help_text = _([[
Adjust the pause between animation frames.

Enter a value in milliseconds. Portrait and landscape remember their own values.
When unset, the default for the current orientation is shown.]]),
            },
            -- Clearing page mode chooser 
            {
                text = _("Mild global refresh"),
                enabled_func = function()
                    return G_reader_settings:isTrue("swipe_animations")
                end,
                checked_func = function()
                    return isMildGlobalRefreshEnabled()
                end,
                callback = function(touchmenu_instance)
                    toggleMildGlobalRefresh()
                    if touchmenu_instance then
                        touchmenu_instance:updateItems()
                    end
                end,
                help_text = _([[
• Checked: use partial refresh (for text-only content)

• Unchecked: use full refresh (for content with images)]]),
            },
        }
    end

    local function buildSettingsMenu()
        return {
            text = _("Swipe animation settings"),
            enabled_func = function()
                return G_reader_settings:isTrue("swipe_animations")
            end,
            help_text = _([[
Adjust the speed (frame delay) and refresh mode (UI / Fast) of the software swipe animation.

The refresh mode directly affects the quality and ghosting of each strip update during the animation.]]),
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
