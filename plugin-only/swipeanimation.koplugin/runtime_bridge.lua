-- Runtime bridge for Swipe_Animation v4.3.
-- Keep the three original upstream patch files untouched, but place the animation
-- handoff at the exact stage where UIManager dispatches queued repaint refreshes.
-- No frontend/ file is ever overwritten.
--
-- KOReader's UIManager._repaint uses a local `refresh_methods` mapping. Unlike
-- replacing Screen.refreshXXImp, wrapping *this specific mapping* only affects
-- queued refreshes from UIManager._repaint. It does not intercept the direct
-- Screen:refreshUI calls made by the upstream wipe engine itself.
local UIManager = require('ui/uimanager')
local Screen = require('device').screen
local logger = require('logger')
local bridge = {}
local state = { in_repaint = false, handled = false, in_animation = false }

local function find_refresh_table()
    if type(UIManager._repaint) ~= 'function' or
        type(debug) ~= 'table' or type(debug.getupvalue) ~= 'function' then
        return nil, 'KOReader _repaint/debug.getupvalue unavailable'
    end
    for i = 1, 60 do
        local name, value = debug.getupvalue(UIManager._repaint, i)
        if name == nil then break end
        if name == 'refresh_methods' and type(value) == 'table' then
            if type(value.partial) == 'function' and type(value.ui) == 'function' then
                return value
            end
            return nil, 'refresh_methods lacks required modes'
        end
    end
    return nil, 'KOReader changed _repaint; cannot locate refresh_methods upvalue'
end

function bridge.preflight()
    if not Screen or not Screen.bb or not Screen.bb.copy or not Screen.bb.blitFrom then
        return false, 'Framebuffer blitbuffer API missing'
    end
    if Screen._swipe_animation_core_patch_applied then
        return false, 'The old Swipe Animation patch/plugin is already active; remove its patches and restart'
    end
    local tbl, err = find_refresh_table()
    if not tbl then return false, err end
    return true
end

local function free_safely(buffer)
    if buffer then pcall(function() buffer:free() end) end
end

function bridge.install()
    if UIManager._swipeanimation_v43_runtime_installed then return true end
    -- The core sets its own one-time marker after preflight; do not
    -- reject this expected marker during installation.
    local refresh_table, refresh_error = find_refresh_table()
    if not refresh_table then return false, refresh_error end
    if not _G.SwipeAnimation or type(_G.SwipeAnimation.runSwipeAnimation) ~= 'function' then
        return false, 'The upstream animation engine was not initialized'
    end
    local refresh_methods = assert(find_refresh_table())
    local original_repaint = UIManager._repaint
    local original_methods = {}
    local count = 0

    -- This closure runs after the new framebuffer image has been painted,
    -- but before the refresh to the physical e-ink panel. The core v4.3
    -- can therefore reveal the saved page in strips exactly as upstream does.
    for mode, original in pairs(refresh_methods) do
        if type(original) == 'function' then
            original_methods[mode] = original
            refresh_methods[mode] = function(screen, ...)
                if not state.in_repaint or state.in_animation then
                    return original(screen, ...)
                end
                if state.handled then
                    -- Once the wipe sends its own updates, suppress all queued
                    -- refreshes from the *same* repaint, as upstream does by
                    -- replacing the refresh stack before draining it.
                    return
                end
                if not screen.swipe_animations then
                    return original(screen, ...)
                end

                -- Consume the request only when an earlier framebuffer
                -- snapshot exists. If the repaint contained no paintTo, the
                -- regular refresh must be preserved.
                screen.swipe_animations = false
                if not screen.saved_bb then
                    logger.dbg('[SwipeAnimation:v4.3] No saved frame; ordinary refresh')
                    return original(screen, ...)
                end

                -- Take a rollback snapshot to avoid leaving a partially
                -- restored framebuffer on exceptions in upstream Lua code.
                local snapshot_ok, final_bb = pcall(function() return screen.bb:copy() end)
                if not snapshot_ok or not final_bb then
                    logger.warn('[SwipeAnimation:v4.3] Cannot snapshot final frame; ordinary refresh')
                    free_safely(screen.saved_bb)
                    screen.saved_bb = nil
                    return original(screen, ...)
                end
                local old_bb = screen.saved_bb
                UIManager.refresh_counted = true
                state.in_animation = true
                local run_ok, run_error = pcall(_G.SwipeAnimation.runSwipeAnimation, UIManager)
                state.in_animation = false
                if run_ok then
                    state.handled = true
                    free_safely(final_bb)
                    return
                end
                logger.warn('[SwipeAnimation:v4.3] Animation failed; restoring frame:', run_error)
                -- The engine may have painted old-page stripes into the real
                -- framebuffer by the time it fails; put the new page back.
                local restored, restore_error = pcall(function()
                    screen.bb:blitFrom(final_bb, 0, 0, 0, 0,
                        final_bb:getWidth(), final_bb:getHeight())
                end)
                free_safely(final_bb)
                -- Upstream removes screen.saved_bb before running, so release
                -- the previously captured old frame on the error path.
                if screen.saved_bb == old_bb then screen.saved_bb = nil end
                free_safely(old_bb)
                if not restored then
                    logger.warn('[SwipeAnimation:v4.3] Frame restore failed:', restore_error)
                end
                return original(screen, ...)
            end
            count = count + 1
        end
    end
    if count == 0 then return false, 'No refresh methods available to hook' end

    UIManager._repaint = function(self, ...)
        -- _repaint should not be recursively called, but keep a previous-state
        -- reference to avoid making a nested repaint corrupt the outer scope.
        if state.in_repaint then return original_repaint(self, ...) end
        state.in_repaint = true
        state.handled = false
        local rep_ok, result = pcall(original_repaint, self, ...)
        state.in_repaint = false
        state.handled = false
        state.in_animation = false
        -- Clean up stale old-frame snapshots after nonstandard update paths.
        -- This does not touch core Screen.bb and won't lose the new page.
        if Screen.saved_bb then
            free_safely(Screen.saved_bb)
            Screen.saved_bb = nil
        end
        Screen.swipe_animations = false
        if not rep_ok then error(result, 0) end
        return result
    end
    UIManager._swipeanimation_v43_runtime_installed = true
    logger.info('[SwipeAnimation:v4.3] Runtime plugin active; hooked repaint modes:', count)
    return true
end

return bridge
