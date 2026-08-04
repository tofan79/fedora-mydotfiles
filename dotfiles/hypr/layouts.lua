-- Layout & Workspace Configuration

hl.config({
    dwindle = {
        preserve_split = true,
        force_split    = 2,
        smart_split    = false,
        smart_resizing = true,
    },
    master = {
        mfact = 0.60,
        new_status = "master",
        smart_resizing = true,
    },
    scrolling = {
        fullscreen_on_one_column = false,
    },
})

hl.layer_rule({
    name         = "noctalia",
    match        = {
        namespace = "^noctalia-(bar-.+|notification|dock|panel|attached-panel|osd)$",
    },
    ignore_alpha = 0.5,
    blur         = true,
    blur_popups  = true,
})

for i = 1, 9 do
    hl.workspace_rule({ workspace = tostring(i), monitor = "eDP-1", persistent = true })
end

hl.config({ general = { layout = "scrolling" } })
