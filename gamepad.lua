local x = 320
local y = 240
local size = 28
local speed = 6

local ax_lx = 0.0
local ax_ly = 0.0
local dpad = { up = false, down = false, left = false, right = false }
local turbo = false
local show_logo = false

local logo = "dvd.png"
local logo_x = 220
local logo_y = 40

local function clamp(v, lo, hi)
  if v < lo then
    return lo
  end
  if v > hi then
    return hi
  end
  return v
end

function gamepad_button(name, pressed)
  if name == "a" then
    turbo = pressed
  elseif (name == "x" or name == "2") and pressed then
    show_logo = not show_logo
  elseif name == "dpad_up" then
    dpad.up = pressed
  elseif name == "dpad_down" then
    show_logo = not show_logo
    dpad.down = pressed
  elseif name == "dpad_left" then
    dpad.left = pressed
  elseif name == "dpad_right" then
    dpad.right = pressed
  end
end

function gamepad_axis(name, value)
  if name == "lx" then
    ax_lx = value
  elseif name == "ly" then
    ax_ly = value
  end
end

function tick()
  local mul = turbo and 2 or 1
  local vx = ax_lx
  local vy = ax_ly
  if dpad.left then
    vx = vx - 1.0
  end
  if dpad.right then
    vx = vx + 1.0
  end
  if dpad.up then
    vy = vy - 1.0
  end
  if dpad.down then
    vy = vy + 1.0
  end
  x = x + vx * speed * mul
  y = y + vy * speed * mul

  x = clamp(x, 0, 640 - size)
  y = clamp(y, 0, 480 - size)

  rect(x, y, size, size)
  if show_logo then
    png(logo_x, logo_y, logo)
  end
end
