# dmgbuild settings for the All Hours Bar installer window.
# Invoked by scripts/make-dmg.sh with -D app=… -D background=… -D icon=…
import os

application = defines["app"]  # noqa: F821 (provided by dmgbuild)
app_name = os.path.basename(application)

format = "UDZO"
filesystem = "HFS+"
files = [application]
symlinks = {"Applications": "/Applications"}
icon = defines.get("icon")  # noqa: F821
background = defines["background"]  # noqa: F821

# 600×400 content area; icon centres match scripts/dmg/background.swift.
window_rect = ((240, 160), (600, 400))
default_view = "icon-view"
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
icon_size = 112
text_size = 13
icon_locations = {
    app_name: (160, 200),
    "Applications": (440, 200),
}
