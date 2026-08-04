-- Compatibility tombstone.
--
-- The full-refresh / clearing logic and the wipe animation now live in
-- 2-swipe-animation-core.lua. On upgraded devices this file replaces the old
-- module, which would otherwise load last and overwrite the core's
-- SwipeFullRefresh global with a version missing runSwipeAnimation,
-- breaking page turns.
return true
