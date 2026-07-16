-- Compatibility tombstone for the broken early-stage version of this patch.
--
-- Stage-1 patches run before Device.screen and UIManager are ready, so the
-- actual MTK direction adapter now lives in 2-mtk-swipe-direction.lua.
-- Keep this harmless file so an overwrite/merge installation also replaces
-- the old startup-breaking copy on existing devices.
return true
