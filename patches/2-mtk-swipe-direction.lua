-- Compatibility tombstone.
--
-- The MTK direction sync now lives in 2-swipe-animation-core.lua (the
-- setSwipeDirection wrapper preserves the backend's rotation-aware hardware
-- direction and stores swipe_forward for the software animation).
-- Keep this harmless file so an overwrite/merge installation also replaces
-- the old adapter on upgraded devices.
return true
