local SCREEN_W = 640
local SCREEN_H = 480

local pressed = {}
local gp_pressed = {}
local gp_lx = 0.0
local gp_ly = 0.0
local gp_rx = 0.0
local gp_ry = 0.0
local gp_gx = 0.0
local gp_gy = 0.0
local gp_gz = 0.0
local mouse_dx = 0.0
local mouse_dy = 0.0
local mouse_seen = false

local frame = 0

local cam = {
  x = 0.0,
  y = 1.7,
  z = -10.0,
  yaw = 0.0,
  pitch = 0.0,
  fov = 72.0,
}

local move_speed = 0.34
local mouse_sens = 0.0030
local pitch_limit = 1.20
local key_look_speed = 0.028
local gyro_look_sens = 3.2
local gyro_dead = 0.12

local score = 0
local ammo = 8
local max_ammo = 8
local shoot_cd = 0
local reload_timer = 0
local muzzle = 0

local pigeons = {}
local spawn_timer = 0
local max_pigeons = 12
local trees = {}

local function clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

local function len3(x, y, z)
  return math.sqrt(x * x + y * y + z * z)
end

local function norm3(x, y, z)
  local l = len3(x, y, z)
  if l < 0.0001 then return 0, 0, 1 end
  return x / l, y / l, z / l
end

local function cam_basis()
  local cy = math.cos(cam.yaw)
  local sy = math.sin(cam.yaw)
  local cp = math.cos(cam.pitch)
  local sp = math.sin(cam.pitch)

  local fx = sy * cp
  local fy = sp
  local fz = cy * cp

  local rx = cy
  local ry = 0.0
  local rz = -sy

  return fx, fy, fz, rx, ry, rz
end

local function ray_from_center()
  local fx, fy, fz = cam_basis()
  return fx, fy, fz
end

local function spawn_pigeon()
  local a = cam.yaw + (math.random() - 0.5) * 1.6
  local r = 12 + math.random() * 16
  local x = cam.x + math.sin(a) * r
  local y = 2.6 + math.random() * 4.4
  local z = cam.z + math.cos(a) * r

  local da = math.random() * math.pi * 2
  local speed = 0.08 + math.random() * 0.06
  pigeons[#pigeons + 1] = {
    x = x,
    y = y,
    z = z,
    vx = math.cos(da) * speed,
    vy = (math.random() - 0.5) * 0.03,
    vz = math.sin(da) * speed,
    r = 0.55,
    alive = true,
    falling = false,
    flap = math.random() * math.pi * 2,
  }
end

local function update_pigeons()
  if spawn_timer > 0 then
    spawn_timer = spawn_timer - 1
  end
  if spawn_timer <= 0 and #pigeons < max_pigeons then
    spawn_pigeon()
    spawn_timer = 14
  end

  for i = 1, #pigeons do
    local p = pigeons[i]
    if p.alive then
      if p.falling then
        p.vy = p.vy - 0.018
        p.y = p.y + p.vy
        if p.y < 0.0 then
          p.alive = false
        end
      else
        p.flap = p.flap + 0.36
        p.x = p.x + p.vx
        p.y = p.y + p.vy + math.sin(p.flap) * 0.018
        p.z = p.z + p.vz

        if p.y < 1.0 then p.vy = math.abs(p.vy) end
        if p.y > 7.2 then p.vy = -math.abs(p.vy) end

        if math.random() < 0.03 then
          local turn = (math.random() - 0.5) * 1.0
          local sx = p.vx
          local sz = p.vz
          p.vx = sx * math.cos(turn) - sz * math.sin(turn)
          p.vz = sx * math.sin(turn) + sz * math.cos(turn)
        end

        if len3(p.x - cam.x, 0, p.z - cam.z) > 34 then
          p.alive = false
        end
      end
    end
  end

  for i = #pigeons, 1, -1 do
    if not pigeons[i].alive then
      table.remove(pigeons, i)
    end
  end
end

local function fire()
  if shoot_cd > 0 or reload_timer > 0 or ammo <= 0 then
    return
  end

  shoot_cd = 8
  muzzle = 3
  ammo = ammo - 1

  local ox, oy, oz = cam.x, cam.y, cam.z
  local dx, dy, dz = ray_from_center()
  local best_i = nil
  local best_t = 1e9

  for i = 1, #pigeons do
    local p = pigeons[i]
    if p.alive and not p.falling then
      local lx = ox - p.x
      local ly = oy - p.y
      local lz = oz - p.z
      local b = 2.0 * (dx * lx + dy * ly + dz * lz)
      local c = lx * lx + ly * ly + lz * lz - p.r * p.r
      local disc = b * b - 4.0 * c
      if disc >= 0.0 then
        local sq = math.sqrt(disc)
        local t0 = (-b - sq) * 0.5
        local t1 = (-b + sq) * 0.5
        local t = nil
        if t0 > 0.02 then
          t = t0
        elseif t1 > 0.02 then
          t = t1
        end
        if t and t < best_t then
          best_t = t
          best_i = i
        end
      end
    end
  end

  if best_i then
    local p = pigeons[best_i]
    p.falling = true
    p.vx = p.vx * 0.2
    p.vz = p.vz * 0.2
    p.vy = 0.04
    score = score + 100
  end

  if ammo <= 0 then
    reload_timer = 26
  end
end

function key(name, is_pressed)
  if (name == "space" or name == "enter") and is_pressed then
    fire()
  end
  if name == "r" and is_pressed then
    if reload_timer <= 0 and ammo < max_ammo then
      reload_timer = 24
    end
  end
  pressed[name] = is_pressed
end

function gamepad_button(name, is_pressed)
  if (name == "a" or name == "x" or name == "rb") and is_pressed then
    fire()
  end
  if (name == "y" or name == "lb") and is_pressed then
    if reload_timer <= 0 and ammo < max_ammo then
      reload_timer = 24
    end
  end
  gp_pressed[name] = is_pressed
end

function gamepad_axis(name, value)
  if name == "lx" then gp_lx = value end
  if name == "ly" then gp_ly = value end
  if name == "rx" then gp_rx = value end
  if name == "ry" then gp_ry = value end
  if name == "gyro_x" then gp_gx = value end
  if name == "gyro_y" then gp_gy = value end
  if name == "gyro_z" then gp_gz = value end
end

local function gyro_clamped(v)
  if v > -gyro_dead and v < gyro_dead then
    return 0.0
  end
  return v
end

function mouse(dx, dy)
  mouse_seen = true
  mouse_dx = dx
  mouse_dy = dy
  cam.yaw = cam.yaw + dx * mouse_sens
  cam.pitch = clamp(cam.pitch - dy * mouse_sens, -pitch_limit, pitch_limit)
end

function mouse_button(button, is_pressed)
  if button == "left" and is_pressed then
    fire()
  end
end

local function update_camera()
  local fwd = 0.0
  local side = 0.0
  local look_yaw = 0.0
  local look_pitch = 0.0

  if pressed["w"] or gp_pressed["dpad_up"] then fwd = fwd + 1.0 end
  if pressed["s"] or gp_pressed["dpad_down"] then fwd = fwd - 1.0 end
  if pressed["a"] or gp_pressed["dpad_left"] then side = side - 1.0 end
  if pressed["d"] or gp_pressed["dpad_right"] then side = side + 1.0 end

  if pressed["left"] then look_yaw = look_yaw + 1.0 end
  if pressed["right"] then look_yaw = look_yaw - 1.0 end
  if pressed["up"] then look_pitch = look_pitch + 1.0 end
  if pressed["down"] then look_pitch = look_pitch - 1.0 end

  side = side + gp_lx
  fwd = fwd - gp_ly
  cam.yaw = cam.yaw + gp_rx * 0.045 + look_yaw * key_look_speed
  cam.pitch = clamp(cam.pitch + gp_ry * 0.035 + look_pitch * key_look_speed, -pitch_limit, pitch_limit)

  local gscale = gyro_look_sens * 0.011
  cam.yaw = cam.yaw + gyro_clamped(gp_gz) * gscale
  cam.pitch = clamp(cam.pitch + gyro_clamped(gp_gx) * gscale, -pitch_limit, pitch_limit)

  local cy = math.cos(cam.yaw)
  local sy = math.sin(cam.yaw)
  cam.x = cam.x + (sy * fwd + cy * side) * move_speed
  cam.z = cam.z + (cy * fwd - sy * side) * move_speed

  if cam.x < -42 then cam.x = -42 end
  if cam.x > 42 then cam.x = 42 end
  if cam.z < -42 then cam.z = -42 end
  if cam.z > 42 then cam.z = 42 end
end

local function draw_sky_shell()
  local b = 52.0
  local h = 46.0
  local sr, sg, sb = 0.48, 0.70, 0.94
  quad3d(-b, 0, -b, b, 0, -b, b, h, -b, -b, h, -b, sr, sg, sb, 1.0)
  quad3d(-b, 0, b, b, 0, b, b, h, b, -b, h, b, sr, sg, sb, 1.0)
  quad3d(-b, 0, -b, -b, 0, b, -b, h, b, -b, h, -b, sr * 0.93, sg * 0.96, sb, 1.0)
  quad3d(b, 0, -b, b, 0, b, b, h, b, b, h, -b, sr * 0.93, sg * 0.96, sb, 1.0)
  quad3d(-b, h, -b, b, h, -b, b, h, b, -b, h, b, sr * 0.82, sg * 0.86, sb, 1.0)
end

local function draw_world()
  cam3d(cam.x, cam.y, cam.z, cam.yaw, cam.pitch, cam.fov)

  draw_sky_shell()

  -- true 3D floor tiles
  for x = -44, 44, 4 do
    for z = -44, 44, 4 do
      local shade = (((x + z) / 4) % 2 == 0) and 0.18 or 0.14
      quad3d(x, 0.0, z, x + 4, 0.0, z, x + 4, 0.0, z + 4, x, 0.0, z + 4,
             shade, 0.45, shade, 1.0)
    end
  end

  -- trees for depth reference
  for i = 1, #trees do
    local t = trees[i]
    local tx = t.x
    local tz = t.z

    quad3d(tx - 0.25, 0.0, tz, tx + 0.25, 0.0, tz, tx + 0.25, 2.6, tz, tx - 0.25, 2.6, tz,
           0.34, 0.22, 0.12, 1.0)

    quad3d(tx - 1.5, 2.0, tz - 0.3, tx + 1.5, 2.0, tz - 0.3, tx + 1.5, 4.6, tz - 0.3, tx - 1.5, 4.6, tz - 0.3,
           0.14, 0.46, 0.18, 1.0)
    quad3d(tx - 0.3, 2.0, tz - 1.5, tx - 0.3, 2.0, tz + 1.5, tx - 0.3, 4.6, tz + 1.5, tx - 0.3, 4.6, tz - 1.5,
           0.14, 0.46, 0.18, 1.0)
  end

  -- arena columns
  for a = 0, 360, 20 do
    local r = math.rad(a)
    local px = math.cos(r) * 28
    local pz = math.sin(r) * 28
    local w = 0.9
    quad3d(px - w, 0.0, pz - w, px + w, 0.0, pz - w, px + w, 6.0, pz - w, px - w, 6.0, pz - w,
           0.35, 0.35, 0.40, 1.0)
  end

  for i = 1, #pigeons do
    local p = pigeons[i]
    if p.alive then
      local sprite = "pombo_up.png"
      if p.falling then
        sprite = "pombo_hit.png"
      else
        local fx, _, fz, rx, _, rz = cam_basis()
        local vdot_f = p.vx * fx + p.vz * fz
        local vdot_r = p.vx * rx + p.vz * rz
        if math.abs(vdot_r) > math.abs(vdot_f) then
          sprite = (vdot_r > 0) and "pombo_down.png" or "pombo_up.png"
        else
          if math.sin(p.flap) < 0 then
            sprite = "pombo_down.png"
          else
            sprite = "pombo_up.png"
          end
        end
      end
      sprite3d(p.x, p.y, p.z, sprite, 2.2)
    end
  end
end

local function draw_weapon_and_hud()
  begin2d()

  local bob = math.sin(frame * 0.16) * 3.0
  local wy = 388 + bob
  local flash = muzzle > 0 and 0.20 or 0.0

  rectc(236, wy, 168, 90, 0.10 + flash, 0.10 + flash, 0.12 + flash, 0.96)
  rectc(264, wy + 14, 112, 56, 0.36 + flash, 0.36 + flash, 0.40 + flash, 1.0)
  rectc(298, wy + 6, 44, 18, 0.24 + flash, 0.22 + flash, 0.18 + flash, 1.0)

  rectc(SCREEN_W * 0.5 - 10, SCREEN_H * 0.5 - 1, 20, 2, 1.0, 0.18, 0.18, 1.0)
  rectc(SCREEN_W * 0.5 - 1, SCREEN_H * 0.5 - 10, 2, 20, 1.0, 0.18, 0.18, 1.0)

  rectc(10, 10, 176, 74, 0.0, 0.0, 0.0, 0.56)
  rectc(14, 16, 168, 8, 0.12, 0.16, 0.24, 1.0)
  rectc(14, 16, math.min(168, score * 0.07), 8, 0.32, 0.78, 1.0, 1.0)
  rectc(14, 34, 84, 8, 0.10, 0.10, 0.10, 1.0)
  rectc(14, 34, 84 * (ammo / max_ammo), 8, 0.92, 0.86, 0.20, 1.0)
  rectc(14, 52, 120, 7, 0.14, 0.14, 0.16, 1.0)
  rectc(14, 52, math.min(120, #pigeons * 10), 7, 0.30, 0.84, 0.40, 1.0)

  local yaw_bar = (cam.yaw % (math.pi * 2)) / (math.pi * 2)
  rectc(14, 64, 160, 4, 0.10, 0.10, 0.12, 1.0)
  rectc(14, 64, 160 * yaw_bar, 4, 0.84, 0.42, 0.28, 1.0)

  local pitch_bar = (cam.pitch + pitch_limit) / (pitch_limit * 2)
  rectc(14, 70, 160, 4, 0.10, 0.10, 0.12, 1.0)
  rectc(14, 70, 160 * pitch_bar, 4, 0.28, 0.74, 0.95, 1.0)

  rectc(210, 18, 220, 16, 0.12, 0.18, 0.24, 0.88)
  if mouse_seen then
    local mag = math.min(1.0, (math.abs(mouse_dx) + math.abs(mouse_dy)) / 8.0)
    rectc(214, 22, 212 * mag, 8, 0.24, 0.88, 0.42, 0.95)
  end

  if reload_timer > 0 then
    rectc(240, 400, 160, 10, 0.85, 0.55, 0.12, 0.85)
  end
end

function tick()
  frame = frame + 1
  if shoot_cd > 0 then shoot_cd = shoot_cd - 1 end
  if muzzle > 0 then muzzle = muzzle - 1 end
  if reload_timer > 0 then
    reload_timer = reload_timer - 1
    if reload_timer <= 0 then ammo = max_ammo end
  end

  update_camera()
  update_pigeons()
  draw_world()
  draw_weapon_and_hud()
end

for x = -36, 36, 12 do
  for z = -36, 36, 12 do
    if math.abs(x) > 6 or math.abs(z) > 6 then
      trees[#trees + 1] = {x = x + (math.random() - 0.5) * 2.0, z = z + (math.random() - 0.5) * 2.0}
    end
  end
end
