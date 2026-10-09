local appearance = ac.storage({
  panel = rgbm(0.018, 0.035, 0.075, 0.54),
  accent = rgbm(0.12, 0.82, 1, 1),
  secondary = rgbm(0.95, 0.2, 0.72, 1),
}, 'playerAppearance')

local defaultAppearance = {
  panel = rgbm(0.018, 0.035, 0.075, 0.54),
  accent = rgbm(0.12, 0.82, 1, 1),
  secondary = rgbm(0.95, 0.2, 0.72, 1),
}

local colorPickerFlags = bit.bor(
  ui.ColorPickerFlags.AlphaBar,
  ui.ColorPickerFlags.AlphaPreview,
  ui.ColorPickerFlags.PickerHueBar
)

local emptyMedia = {
  sourceID = '',
  title = '',
  artist = '',
  album = '',
  hasCover = false,
  isPlaying = false,
  trackPosition = -1,
  trackDuration = -1,
}

local function getCurrentMedia()
  if type(ac.currentlyPlaying) ~= 'function' then return emptyMedia end
  local ok, media = pcall(ac.currentlyPlaying)
  return ok and media ~= nil and media or emptyMedia
end

local coverTrackKey
local coverMedia

local function updateCover(playing, hasCover)
  playing = playing or getCurrentMedia()
  local trackKey = table.concat({
    tostring(playing.sourceID or ''),
    tostring(playing.title or ''),
    tostring(playing.album or ''),
    tostring(playing.artist or ''),
  }, '|')

  if coverTrackKey ~= trackKey then
    coverTrackKey = trackKey
    coverMedia = nil
  end

  if hasCover == false then
    coverMedia = nil
  elseif hasCover == true or playing.hasCover then
    coverMedia = playing
  end
  return coverMedia
end

updateCover()
if type(ac.onAlbumCoverUpdate) == 'function' then
  ac.onAlbumCoverUpdate(function (hasCover)
    updateCover(getCurrentMedia(), hasCover)
  end)
end

local positionTrackKey
local displayedPosition

local function updateDisplayedPosition(playing, dt)
  local duration = tonumber(playing.trackDuration) or -1
  local reportedPosition = tonumber(playing.trackPosition) or -1
  local trackKey = table.concat({
    tostring(playing.sourceID or ''),
    tostring(playing.title or ''),
    tostring(playing.artist or ''),
    tostring(duration),
  }, '|')

  if positionTrackKey ~= trackKey then
    positionTrackKey = trackKey
    displayedPosition = reportedPosition >= 0 and reportedPosition or nil
  elseif playing.isPlaying and displayedPosition ~= nil then
    displayedPosition = displayedPosition + math.max(0, math.min(dt or 0, 1))
  end

  if reportedPosition >= 0 then
    if displayedPosition == nil or math.abs(reportedPosition - displayedPosition) > 2 then
      displayedPosition = reportedPosition
    elseif not playing.isPlaying then
      displayedPosition = reportedPosition
    else
      displayedPosition = math.lerp(displayedPosition, reportedPosition, 0.2)
    end
  end

  if displayedPosition and duration > 0 then
    displayedPosition = math.min(math.max(displayedPosition, 0), duration)
  end
  return displayedPosition or -1, duration
end

local function formatTime(value)
  value = tonumber(value)
  if value == nil or value < 0 then return '--:--' end
  return string.format('%d:%02d', math.floor(value / 60), math.floor(value % 60))
end

local function iconButton(id, icon, pos, size, color)
  ui.setCursor(pos + vec2((size - 24) / 2, (size - 24) / 2))
  ui.icon(icon, 24, color)
  ui.setCursor(pos)
  ui.invisibleButton(id, vec2(size, size))
  return ui.itemClicked()
end

local function drawColorSetting(label, key)
  ui.text(label)
  ui.sameLine(150)
  local editedColor = (appearance[key] or defaultAppearance[key]):clone()
  ui.colorButton('##'..key, editedColor, colorPickerFlags)
  if editedColor ~= appearance[key] then
    appearance[key] = editedColor
  end
end

function script.windowSettings(dt)
  ui.header('MK\'s Music Player')
  drawColorSetting('Panel and transparency', 'panel')
  drawColorSetting('Neon accent', 'accent')
  drawColorSetting('Secondary glow', 'secondary')

  ui.offsetCursorY(8)
  if ui.button('Reset colors') then
    appearance.panel = defaultAppearance.panel:clone()
    appearance.accent = defaultAppearance.accent:clone()
    appearance.secondary = defaultAppearance.secondary:clone()
  end
end

function script.windowMain(dt)
  local size = ui.windowSize()
  local playing = getCurrentMedia()
  local albumCover = updateCover(playing)
  local trackPosition, trackDuration = updateDisplayedPosition(playing, dt)
  local artSize = math.min(size.y - 28, 92)
  local artPos = vec2(12, (size.y - artSize) / 2)
  local controlsX = size.x - 160
  local controlsY = (size.y - 52) / 2
  local textX = artPos.x + artSize + 16
  local textRight = controlsX - 12
  local trackTimeY = size.y - 42
  local progressY = size.y - 22

  ui.drawRectFilled(vec2(2, 2), size - vec2(2, 2), appearance.panel, 12)
  ui.drawRect(vec2(2, 2), size - vec2(2, 2), appearance.accent, 12, ui.CornerFlags.All, 1)
  ui.drawLine(vec2(18, 4), vec2(size.x - 18, 4), appearance.secondary, 1)
  ui.drawRectFilled(vec2(3, 18), vec2(6, size.y * 0.53), appearance.secondary, 2)
  ui.drawRectFilled(vec2(3, size.y * 0.53), vec2(6, size.y - 18), appearance.accent, 2)

  ui.drawRectFilled(artPos, artPos + artSize, rgbm(0.035, 0.09, 0.14, 0.9), 8)
  ui.setCursor(artPos + vec2(25, 25))
  ui.icon(ui.Icons.Music, 34, appearance.accent)
  local coverDrawSucceeded = false
  if albumCover then
    ui.setCursor(artPos)
    coverDrawSucceeded = pcall(ui.image, albumCover, artSize, ui.ImageFit.Fit)
  end
  if albumCover and coverDrawSucceeded then
    ui.drawRect(artPos, artPos + artSize, appearance.accent, 6, ui.CornerFlags.All, 1)
  end

  local title = type(playing.title) == 'string' and playing.title ~= '' and playing.title or 'Nothing playing'
  local artist = type(playing.artist) == 'string' and playing.artist ~= '' and playing.artist or 'Assetto Corsa media player'
  local labelY = math.max(18, artPos.y - 4)
  local titleY = labelY + 17
  local artistY = titleY + 24
  ui.setCursor(vec2(textX, labelY))
  ui.dwriteText('NIGHT DRIVE  /  NOW PLAYING', 10, appearance.accent)
  ui.dwriteDrawTextClipped(title, 21, vec2(textX, titleY), vec2(textRight, titleY + 27), ui.Alignment.Start, ui.Alignment.Center, false, rgbm(0.98, 0.97, 1, 1))
  ui.dwriteDrawTextClipped(artist, 14, vec2(textX, artistY), vec2(textRight, artistY + 20), ui.Alignment.Start, ui.Alignment.Center, false, rgbm(0.68, 0.76, 0.84, 1))

  local progress = trackDuration > 0 and trackPosition >= 0 and math.saturateN(trackPosition / trackDuration) or 0
  local barStart = vec2(textX, progressY)
  local barEnd = vec2(textRight, progressY + 4)
  ui.drawRectFilled(barStart, barEnd, rgbm(0.12, 0.2, 0.28, 0.95), 2)
  if progress > 0 then
    local progressEnd = math.lerp(barStart.x, barEnd.x, progress)
    ui.drawRectFilled(barStart, vec2(progressEnd, barEnd.y), appearance.accent, 2)
    ui.drawCircleFilled(vec2(progressEnd, progressY + 2), 4, appearance.secondary)
  end
  ui.pushDWriteFont('Segoe UI;Weight=Bold')
  ui.dwriteDrawText(formatTime(trackPosition), 14, vec2(textX, trackTimeY - 2), rgbm(0.94, 0.97, 1, 1))
  ui.dwriteDrawText(formatTime(trackDuration), 14, vec2(textRight - 48, trackTimeY - 2), rgbm(0.94, 0.97, 1, 1))
  ui.popDWriteFont()

  if iconButton('previousTrack', ui.Icons.Back, vec2(controlsX, controlsY + 8), 36, rgbm(0.72, 0.84, 0.92, 1)) then
    if ac.mediaPreviousTrack then ac.mediaPreviousTrack() end
  end
  ui.drawCircle(vec2(controlsX + 74, controlsY + 26), 28, appearance.accent, 32, 1.5)
  if iconButton('playPause', playing.isPlaying and ui.Icons.Pause or ui.Icons.Play,
      vec2(controlsX + 48, controlsY), 52, rgbm.colors.white) then
    if ac.mediaPlayPause then ac.mediaPlayPause() end
  end
  if iconButton('nextTrack', ui.Icons.Next, vec2(controlsX + 112, controlsY + 8), 36, rgbm(0.72, 0.84, 0.92, 1)) then
    if ac.mediaNextTrack then ac.mediaNextTrack() end
  end
end