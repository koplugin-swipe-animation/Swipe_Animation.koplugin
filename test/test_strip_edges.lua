-- Spec for swipe strip geometry (keep in sync with
-- patches/2-swipe-animation-core.lua :: buildStripEdges).
-- Run: luajit test/test_strip_edges.lua

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

local failures = 0
local function check(name, cond, extra)
    if cond then
        print("ok  " .. name)
    else
        failures = failures + 1
        print("FAIL  " .. name .. (extra and ("  " .. extra) or ""))
    end
end

local function dump(t)
    local parts = {}
    for i = 1, #t do
        parts[i] = tostring(t[i])
    end
    return "{" .. table.concat(parts, ",") .. "}"
end

-- Unaligned path: same cut points as the old i/steps loop.
do
    local edges = buildStripEdges(1448, 8, 0)
    check("unaligned count", #edges == 9, dump(edges))
    check("unaligned first", edges and edges[1] == 0, dump(edges))
    check("unaligned last", edges and edges[#edges] == 1448, dump(edges))
    if edges then
        for i = 2, #edges do
            check("unaligned mono " .. i, edges[i] > edges[i - 1])
        end
        check("unaligned step1", edges[2] == math.floor(1448 * 1 / 8))
    end
end

-- MTK 16px: interior edges on the grid, last edge is the real width.
do
    local align = 16
    local edges = buildStripEdges(1448, 8, align)
    check("aligned first", edges and edges[1] == 0, dump(edges))
    check("aligned last", edges and edges[#edges] == 1448, dump(edges))
    if edges then
        for i = 2, #edges - 1 do
            check("interior aligned " .. i, edges[i] % align == 0, tostring(edges[i]))
            check("interior increasing " .. i, edges[i] > edges[i - 1])
        end
        check("last wider than prev", edges[#edges] > edges[#edges - 1])
        -- Forward first strip is the rightmost slot: x must be on-grid.
        local first_forward_x = edges[#edges - 1]
        check("forward first x aligned", first_forward_x % align == 0, tostring(first_forward_x))
        check("forward first w > 1", (1448 - first_forward_x) > 1)
    end
end

-- Width already on-grid (Libra Colour 1680).
do
    local edges = buildStripEdges(1680, 8, 16)
    check("1680 last", edges and edges[#edges] == 1680)
    if edges then
        for i = 1, #edges do
            check("1680 all aligned " .. i, edges[i] % 16 == 0, tostring(edges[i]))
        end
    end
end

-- Degenerate: snapping must not collapse to a single strip or overshoot.
do
    local edges = buildStripEdges(200, 8, 16)
    check("small first", edges and edges[1] == 0)
    check("small last", edges and edges[#edges] == 200)
    check("small at least 2 slots", edges and #edges >= 3, dump(edges))
end

-- Forward wipe consumes slots right-to-left; first strip x is last interior edge.
do
    local edges = buildStripEdges(1448, 8, 16)
    local nslots = #edges - 1
    local first_x = edges[nslots]
    local first_w = edges[nslots + 1] - edges[nslots]
    check("forward first slot x", first_x == edges[#edges - 1])
    check("forward first slot on grid", first_x % 16 == 0, tostring(first_x))
    check("forward first slot covers remainder", first_x + first_w == 1448)
end

-- Production copy must stay identical to this spec function.
do
    local src_path = "patches/2-swipe-animation-core.lua"
    local f = io.open(src_path, "rb")
    check("production file readable", f ~= nil, src_path)
    if f then
        local src = f:read("*a")
        f:close()
        src = src:gsub("\r\n", "\n")
        local prod = src:match("local function buildStripEdges%(screen_w, steps, align%)\n(.-)\n    end\n")
        local spec_src = [[
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
]]
        -- Normalize indent to the production 8-space body.
        local spec_body = spec_src:gsub("\r\n", "\n"):gsub("^%s*\n", ""):gsub("\n+$", "")
        check("production body present", type(prod) == "string" and #prod > 0)
        if prod then
            check("production matches spec", prod == spec_body,
                "\nPROD:\n" .. prod .. "\nSPEC:\n" .. spec_body)
        end
    end
end

if failures > 0 then
    print(failures .. " failure(s)")
    os.exit(1)
end
print("all passed")
