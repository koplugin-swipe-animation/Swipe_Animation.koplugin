--[[
    2-swipe-animation-core.lua

    Runtime core of the Swipe_Animation patch (merged from the former
    2-mtk-swipe-direction.lua, 2-swipe-animation-framebuffer.lua and
    2-swipe-full-refresh-judgment.lua):

    1. framebuffer integration: wrap Screen methods so ffi/framebuffer.lua
       stays 100% upstream (snapshot the pre-paint screen, persist the swipe
       state). The setSwipeDirection wrapper also covers MTK: on MTK devices
       the original method is the rotation-aware hardware ioctl setup, which
       we preserve, and we additionally store swipe_forward for the software
       animation.
    2. the SwipeAnimation module: full-refresh / clearing decisions and the
       wipe animation itself (runSwipeAnimation), called from
       UIManager:_repaint after the new page is painted.
    3. post-resume display warm-up on MTK Kobos: the display controller is
       still cold after wake-up, so the first software wipe animation would
       run in slow motion because every UI-waveform strip refresh blocks on
       the still-cold controller. Right after resume we issue a few invisible
       full-screen UI refreshes to warm the controller up, so the first page
       turn animates normally at full speed.

    Prefer original data sources, but trigger Screen:refreshFull / refreshPartial
    directly (because we are inside _repaint, where setDirty would be deferred
    and ineffective).
]]

local ok, err = pcall(function()
    local Device = require("device")
    local Screen = Device.screen
    if not Screen then
        return
    end

    -- ==================== 1. framebuffer integration ====================
    if not Screen._swipe_animation_core_patch_applied then
        Screen._swipe_animation_core_patch_applied = true

        -- Snapshot the current framebuffer before the new page is painted,
        -- but only once per repaint (beforePaint can be called once per dirty
        -- widget in the same repaint cycle). This is the "previous page" used
        -- by the wipe effect.
        local orig_beforePaint = Screen.beforePaint
        function Screen:beforePaint()
            if not self.painting then
                self.painting = true
                if self.swipe_animations then
                    if self.saved_bb then self.saved_bb:free() end
                    self.saved_bb = self.bb:copy()
                end
            end
            if orig_beforePaint then
                return orig_beforePaint(self)
            end
        end

        local orig_afterPaint = Screen.afterPaint
        function Screen:afterPaint()
            self.painting = false
            if orig_afterPaint then
                return orig_afterPaint(self)
            end
        end

        -- The upstream base framebuffer only declares these as stubs; persist
        -- the state so the software animation can read it.
        local orig_setSwipeAnimations = Screen.setSwipeAnimations
        function Screen:setSwipeAnimations(enabled)
            if orig_setSwipeAnimations then
                orig_setSwipeAnimations(self, enabled)
            end
            self.swipe_animations = enabled
        end

        -- On MTK devices the original setSwipeDirection is the rotation-aware
        -- hardware ioctl setup (framebuffer_mxcfb); calling it preserves the
        -- native behavior, and storing swipe_forward keeps the software
        -- animation direction in sync. This replaces the former
        -- 2-mtk-swipe-direction.lua.
        local orig_setSwipeDirection = Screen.setSwipeDirection
        function Screen:setSwipeDirection(direction)
            if orig_setSwipeDirection then
                orig_setSwipeDirection(self, direction)
            end
            self.swipe_forward = direction
        end
    end

    -- ==================== 2. SwipeAnimation module ====================
    local logger = require("logger")
    -- Module-level cache to avoid repeated requires on the _repaint hot path
    local ReaderUI = require("apps/reader/readerui")
    -- Shared animation tuning (single source of truth, defined in uimanager.lua)
    local UIManager = require("ui/uimanager")
    -- For the frame delay sleep in the animation loop
    local ffi = require("ffi")

    local SwipeAnimation = {}

    ---------------------------------------------------------------
    --     Post-resume display warm-up on MTK Kobo
    ---------------------------------------------------------------
    if not UIManager._swipe_animation_resume_warmup_patched then
        UIManager._swipe_animation_resume_warmup_patched = true

        local orig_broadcastEvent = UIManager.broadcastEvent
        function UIManager:broadcastEvent(ev)
            local ret = orig_broadcastEvent(self, ev)
            if ev and ev.handler == "onResume"
                    and Device:isKobo() and Device:isMTK()
                    and G_reader_settings:isTrue("swipe_animations") then
                UIManager:scheduleIn(0.3, function()
                    if Device.screen_saver_mode then
                        return -- device went back to sleep meanwhile
                    end
                    local bb = Screen.bb
                    if not bb then
                        return
                    end
                    local warmup_w = bb:getWidth()
                    local warmup_h = bb:getHeight()
                    if warmup_w <= 0 or warmup_h <= 0 then
                        return
                    end
                    -- Same refresh count as a portrait wipe animation, so the
                    -- controller is exercised just as much as it was during
                    -- the previously slow first turn.
                    for _ = 1, 8 do
                        Screen:refreshUI(0, 0, warmup_w, warmup_h)
                    end
                end)
            end
            return ret
        end
    end

    ---------------------------------------------------------------
    -- 2.1 Whether to skip the animation and perform a clearing refresh
    ---------------------------------------------------------------
    function SwipeAnimation.shouldDoClearing(self)
        if not (self.FULL_REFRESH_COUNT and self.FULL_REFRESH_COUNT > 0) then
            return false
        end

        self._swipe_full_refresh_count = (self._swipe_full_refresh_count or 0) + 1

        if self._swipe_full_refresh_count >= self.FULL_REFRESH_COUNT then
            self._swipe_full_refresh_count = 0
            return true
        end
        return false
    end

    ---------------------------------------------------------------
    -- 2.2 Perform the clearing refresh (supports mild global refresh)
    ---------------------------------------------------------------
    function SwipeAnimation.performClearing(self, screen_w, screen_h)
        local mild = G_reader_settings:isTrue("swipe_animation_mild_global_refresh")

        if mild then
            Screen:refreshPartial(0, 0, screen_w, screen_h)
            logger.dbg("SwipeAnimation: mild (partial) clearing refresh")
        else
            Screen:refreshFull(0, 0, screen_w, screen_h)
            logger.dbg("SwipeAnimation: full clearing refresh")
        end

        self.refresh_count = 0
        self._refresh_stack = {}
    end

    ---------------------------------------------------------------
    -- 2.3 Whether a forced full refresh is needed (images / chapter boundaries)
    --     Can be called before the animation; accurate prev_page is required
    --     to correctly detect forward/backward chapter boundaries
    ---------------------------------------------------------------
    function SwipeAnimation.shouldForceFullAfterAnimation(self, prev_page)
        local instance = ReaderUI.instance
        if not instance then
            return false
        end

        -- ===== Images(ReaderView:paintTo) =====
        local view = instance.view
        if view then
            local curr_coverage = view.img_coverage or 0
            local prev_coverage = view._swipe_prev_img_coverage or 0
            local coverage_diff = math.abs(curr_coverage - prev_coverage)

            view._swipe_prev_img_coverage = curr_coverage

            if curr_coverage >= 0.075 or coverage_diff >= 0.075 then
                if G_reader_settings:nilOrTrue("refresh_on_pages_with_images") then
                    return true
                end
            end
        end

        -- ===== Chapters (faithful recreation of ReaderToc:onPageUpdate) =====
        local toc = instance.toc
        if not toc then return false end

        if not (self.FULL_REFRESH_COUNT == -1 or G_reader_settings:isTrue("refresh_on_chapter_boundaries")) then
            return false
        end

        local paging = instance.paging
        local rolling = instance.rolling
        local current_page = (paging and paging.current_page) or (rolling and rolling.current_page)

        if not current_page then return false end

        -- If prev_page was not provided, fall back to toc.pageno
        -- (which may already be the new page, so less accurate)
        prev_page = prev_page or toc.pageno

        local flash_on_second = G_reader_settings:nilOrFalse("no_refresh_on_second_chapter_page")
        local paging_forward, paging_backward

        if flash_on_second and prev_page then
            if current_page > prev_page then
                paging_forward = true
            elseif current_page < prev_page then
                paging_backward = true
            end
        end

        if paging_backward and toc:isChapterEnd(current_page) then
            return true
        elseif toc:isChapterStart(current_page) then
            return true
        elseif paging_forward and toc:isChapterSecondPage(current_page) then
            return true
        end

        return false
    end

    ---------------------------------------------------------------
    -- 2.4 Actually trigger the full refresh
    --     Supports mild global refresh, consistent with performClearing
    ---------------------------------------------------------------
    function SwipeAnimation.forceFullAndReset(self, screen_w, screen_h)
        -- We are inside _repaint, so we must refresh directly;
        -- setDirty would be deferred to the next frame and become ineffective
        local mild = G_reader_settings:isTrue("swipe_animation_mild_global_refresh")

        if mild then
            Screen:refreshPartial(0, 0, screen_w, screen_h)
            logger.dbg("SwipeAnimation: mild (partial) forced refresh (image/chapter)")
        else
            Screen:refreshFull(0, 0, screen_w, screen_h)
            logger.dbg("SwipeAnimation: forced full refresh (image/chapter)")
        end

        self._swipe_full_refresh_count = 0
        self.refresh_count = 0
        self._refresh_stack = {}
    end

    ---------------------------------------------------------------
    -- 2.5 Run the software wipe animation
    --     Called from UIManager:_repaint (after the new page has been painted,
    --     before the queued refreshes are executed). Handles the clearing /
    --     forced-full decisions and the strip animation.
    ---------------------------------------------------------------
    -- Interior cuts snap to `align` (Screen.alignment_constraint, 16 on
    -- Kobo MTK) so getBoundedRect does not expand neighbouring strips
    -- into each other. Last edge stays the real width.
    local function buildStripEdges(screen_w, steps, align)
        local edges = {0}
        local use_align = type(align) == "number" and align >= 2
        for i = 1, steps - 1 do
            local raw = screen_w * i / steps
            local cut
            if use_align then
                cut = math.floor((raw + align / 2) / align) * align
            else
                cut = math.floor(raw)
            end
            if cut > edges[#edges] and cut < screen_w then
                edges[#edges + 1] = cut
            end
        end
        edges[#edges + 1] = screen_w
        return edges
    end

    function SwipeAnimation.runSwipeAnimation(self)
        local screen_w = Screen.bb:getWidth()
        local screen_h = Screen.bb:getHeight()

        -- Try to capture the previous page number before the animation decision
        -- Note: by the time we reach _repaint, paging/toc may already reflect the new page,
        -- so prev_page is not 100% reliable, but it is still better than not passing it
        -- and letting shouldForceFull fall back to toc.pageno.
        local prev_page = nil
        do
            local instance = ReaderUI.instance
            if instance then
                if instance.toc then
                    prev_page = instance.toc.pageno
                end
                if not prev_page then
                    prev_page = (instance.paging and instance.paging.current_page)
                             or (instance.rolling and instance.rolling.current_page)
                end
            end
        end

        -- ========== Full-refresh decision (early: skip the wipe animation
        -- when a clearing or forced full refresh is needed) ==========
        local do_clearing = SwipeAnimation.shouldDoClearing(self)
        local need_force_full = false
        if not do_clearing then
            need_force_full = SwipeAnimation.shouldForceFullAfterAnimation(self, prev_page)
        end

        local saved_bb = Screen.saved_bb
        Screen.saved_bb = nil

        if do_clearing or need_force_full then
            -- Clearing page / image page / chapter boundary:
            -- skip the animation and perform the corresponding refresh directly
            if need_force_full then
                SwipeAnimation.forceFullAndReset(self, screen_w, screen_h)
            else
                SwipeAnimation.performClearing(self, screen_w, screen_h)
            end
            if saved_bb then
                saved_bb:free()
            end
            return
        end

        if not saved_bb then
            -- No pre-paint snapshot (beforePaint did not capture one): nothing
            -- to animate; the queued refreshes will run normally.
            return
        end

        -- ==================== Normal software swipe animation path ====================
        local new_bb = Screen.bb:copy()

        -- Support custom per-orientation animation frame delay set by the external plugin.
        -- Defaults come from UIManager.swipe_animation_defaults (single source of truth).
        local is_landscape = screen_w > screen_h
        local delay_defaults = (UIManager.swipe_animation_defaults or {}).delay_ms or {}
        local delay_ms = is_landscape
            and (tonumber(G_reader_settings:readSetting("swipe_animation_delay_ms_horizontal")) or 0)
            or  (tonumber(G_reader_settings:readSetting("swipe_animation_delay_ms_vertical")) or 0)
        if delay_ms <= 0 then
            delay_ms = is_landscape
                and (delay_defaults.landscape or 10)
                or  (delay_defaults.portrait or 20)
        end
        local delay_us = delay_ms * 1000

        -- Allow user to choose "ui" or "fast" for the per-strip refreshes.
        local anim_refresh_mode = G_reader_settings:readSetting("swipe_animation_refresh_mode") or "ui"

        -- Hoisted for slight efficiency in the animation loop
        local usleep = ffi and ffi.C and ffi.C.usleep

        -- Use fewer animation steps in landscape mode for better visual feel
        local step_defaults = (UIManager.swipe_animation_defaults or {}).steps or {}
        local steps = is_landscape
            and (step_defaults.landscape or 6)
            or  (step_defaults.portrait or 8)
        local swipe_forward = Screen.swipe_forward
        if swipe_forward == nil then
            -- Some framebuffer implementations never call setSwipeDirection();
            -- default to the forward direction instead of always sweeping one way.
            swipe_forward = true
        end
        local edges = buildStripEdges(screen_w, steps, Screen.alignment_constraint)
        local nslots = #edges - 1

        -- Draw the previous page as the starting background
        Screen.bb:blitFrom(saved_bb, 0, 0, 0, 0, screen_w, screen_h)

        -- Animate page turn by progressively revealing vertical strips of the new page.
        for i = 1, nslots do
            local left, right
            if swipe_forward then
                local idx = nslots - i + 1
                left = edges[idx]
                right = edges[idx + 1]
            else
                left = edges[i]
                right = edges[i + 1]
            end
            local strip_w = right - left
            -- Sleep only after DU. UI already blocked on submission (MTK)
            -- or is a slower waveform; extra usleep just makes it feel late.
            local use_fast = anim_refresh_mode == "fast"
            if strip_w > 0 then
                Screen.bb:blitFrom(new_bb, left, 0, left, 0, strip_w, screen_h)
                local refresh_fn = use_fast and Screen.refreshFast or Screen.refreshUI
                refresh_fn(Screen, left, 0, strip_w, screen_h)
            end
            if i < nslots and usleep and use_fast then
                usleep(delay_us)
            end
        end

        -- Forced-full decision is no longer performed here on the animation path
        -- (it was moved earlier; if needed, the animation is skipped entirely)

        self._refresh_stack = {}
        new_bb:free()
        saved_bb:free()
    end

    _G.SwipeAnimation = SwipeAnimation
end)

if not ok then
    require("logger").warn("[SwipeAnimationCorePatch] failed:", err)
end
