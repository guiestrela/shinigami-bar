// Common behavior for variant-specific presentations.
.pragma library

function handleButton(riseOwner, riseEnvironment, button) {
    riseEnvironment.tip.hide()
    if (button === riseEnvironment.Qt.MiddleButton)
        return riseOwner.root.wallpaperManagerServiceApi.nextAll()
    return riseOwner.root.toggleWallpaperManager(riseOwner.screen, riseOwner)
}
