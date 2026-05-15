local SCREEN_W = 640
local SCREEN_H = 480

local frame = 0
local pressed = {}
local gp_pressed = {}
local gp_lx = 0.0
local gp_ly = 0.0

local score = 0
local ammo = 3
local max_ammo = 3
local shoot_cd = 0
local reload_timer = 0
local flash = 0

local game_over = false
local round_idx = 1
local required_hits = 6
local hits = 0

local cross_x = SCREEN_W * 0.5
local cross_y = SCREEN_H * 0.5

local birds = {}
local spawn_timer = 0

local cam = {
  x = 0.0,
  y = 0.0,
  z = 0.0,
  yaw = 0.0,
  pitch = 0.0,
  fov = 60.0,
}

local function vec3_len(x, y, z)
  return math.sqrt(x * x + y * y + z * z)
end

local function vec3_norm(x, y, z)
  local l = vec3_len(x, y, z)
  if l < 0.0001 then
    return 0, 0, 1
  end
  return x / l, y / l, z / l
end

local function ray_from_crosshair()
  local nx = (cross_x / SCREEN_W) * 2.0 - 1.0
  local ny = 1.0 - (cross_y / SCREEN_H) * 2.0

  local tan_half = math.tan(math.rad(cam.fov) * 0.5)
  local aspect = SCREEN_W / SCREEN_H

  local vx = nx * tan_half * aspect
  local vy = ny * tan_half
  local vz = 1.0
  vx, vy, vz = vec3_norm(vx, vy, vz)

  local cy = math.cos(cam.yaw)
  local sy = math.sin(cam.yaw)
  local cp = math.cos(cam.pitch)
  local sp = math.sin(cam.pitch)

  local wx = cy * vx + sy * vz
  local wz = -sy * vx + cy * vz
  local wy = cp * vy + sp * wz
  wz = -sp * vy + cp * wz

  return vec3_norm(wx, wy, wz)
end

local function clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

local function project(wx, wy, wz)
  local dx = wx - cam.x
  local dy = wy - cam.y
  local dz = wz - cam.z

  local cy = math.cos(cam.yaw)
  local sy = math.sin(cam.yaw)
  local cp = math.cos(cam.pitch)
  local sp = math.sin(cam.pitch)

  local x1 = cy * dx - sy * dz
  local z1 = sy * dx + cy * dz
  local y1 = cp * dy - sp * z1
  local z2 = sp * dy + cp * z1

  if z2 <= 0.01 then
    return nil, nil, z2
  end

  local f = 1.0 / math.tan(math.rad(cam.fov) * 0.5)
  local sx = (x1 / z2) * (SCREEN_W * 0.5) * f + SCREEN_W * 0.5
  local sy2 = (-y1 / z2) * (SCREEN_H * 0.5) * f + SCREEN_H * 0.5
  return sx, sy2, z2
end

local function spawn_bird()
  local dir = (math.random() < 0.5) and -1 or 1
  local x = dir == 1 and -26 or 26
  local y = -6 + math.random() * 7
  local z = 26 + math.random() * 22
  local speed = 9.0 + round_idx * 0.9 + math.random() * 2.0

  birds[#birds + 1] = {
    x = x,
    y = y,
    z = z,
    vx = speed * dir,
    vy = (math.random() - 0.5) * 0.6,
    vz = (math.random() - 0.5) * 0.5,
    alive = true,
    falling = false,
    flap = math.random() * math.pi * 2,
    r = 1.2,
  }
end

local function reset_round()
  birds = {}
  spawn_timer = 20
  hits = 0
  required_hits = 6 + (round_idx - 1)
  ammo = max_ammo
  shoot_cd = 0
  reload_timer = 0
end

local function reset_game()
  score = 0
  round_idx = 1
  game_over = false
  reset_round()
end

local function do_shoot()
  if game_over then
    reset_game()
    return
  end
  if shoot_cd > 0 or reload_timer > 0 or ammo <= 0 then
    return
  end

  ammo = ammo - 1
  shoot_cd = 8
  flash = 3

  local best_i = nil
  local best_t = 1e9
  local rx, ry, rz = ray_from_crosshair()

  for i = 1, #birds do
    local b = birds[i]
    if b.alive and not b.falling then
      local ox = cam.x
      local oy = cam.y
      local oz = cam.z
      local cx = b.x
      local cy = b.y
      local cz = b.z

      local lx = ox - cx
      local ly = oy - cy
      local lz = oz - cz

      local bcoef = 2.0 * (rx * lx + ry * ly + rz * lz)
      local ccoef = lx * lx + ly * ly + lz * lz - b.r * b.r
      local disc = bcoef * bcoef - 4.0 * ccoef
      if disc >= 0.0 then
        local sq = math.sqrt(disc)
        local t0 = (-bcoef - sq) * 0.5
        local t1 = (-bcoef + sq) * 0.5
        local t = nil
        if t0 > 0.0 then t = t0 elseif t1 > 0.0 then t = t1 end
        if t and t < best_t then
          best_t = t
          best_i = i
        end
      end
    end
  end

  if best_i then
    local b = birds[best_i]
    b.falling = true
    b.vx = b.vx * 0.2
    b.vz = b.vz * 0.2
    b.vy = 0.5
    hits = hits + 1
    score = score + 100 + (round_idx - 1) * 20
  end

  if ammo <= 0 then
    reload_timer = 30
  end
end

function key(name, is_pressed)
  pressed[name] = is_pressed
  if (name == "space" or name == "enter") and is_pressed then
    do_shoot()
  end
end

function gamepad_button(name, is_pressed)
  gp_pressed[name] = is_pressed
  if (name == "a" or name == "x" or name == "rb") and is_pressed then
    do_shoot()
  end
end

function gamepad_axis(name, value)
  if name == "lx" then gp_lx = value end
  if name == "ly" then gp_ly = value end
end

local function update_crosshair()
  local mx = 0.0
  local my = 0.0
  if pressed["left"] or pressed["a"] then mx = mx - 1.0 end
  if pressed["right"] or pressed["d"] then mx = mx + 1.0 end
  if pressed["up"] or pressed["w"] then my = my - 1.0 end
  if pressed["down"] or pressed["s"] then my = my + 1.0 end

  mx = mx + gp_lx
  my = my + gp_ly

  cross_x = clamp(cross_x + mx * 5.0, 8, SCREEN_W - 8)
  cross_y = clamp(cross_y + my * 5.0, 20, SCREEN_H - 20)
end

local function update_birds()
  if game_over then return end

  if spawn_timer > 0 then
    spawn_timer = spawn_timer - 1
  elseif #birds < (required_hits + 4) then
    spawn_bird()
    spawn_timer = math.random(18, 32)
  end

  local alive_nonfall = 0
  for i = 1, #birds do
    local b = birds[i]
    if b.alive then
      if b.falling then
        b.y = b.y + b.vy
        b.vy = b.vy + 0.14
        if b.y > 10 then
          b.alive = false
        end
      else
        b.x = b.x + b.vx * 0.016
        b.y = b.y + b.vy * 0.016
        b.z = b.z + b.vz * 0.016
        b.flap = b.flap + 0.35

        if b.y < -10 then b.vy = math.abs(b.vy) end
        if b.y > 5 then b.vy = -math.abs(b.vy) end
        if b.z < 14 then b.vz = math.abs(b.vz) end
        if b.z > 58 then b.vz = -math.abs(b.vz) end
        if b.x < -34 or b.x > 34 then
          b.alive = false
        else
          alive_nonfall = alive_nonfall + 1
        end
      end
    end
  end

  if #birds >= (required_hits + 4) and alive_nonfall == 0 then
    if hits >= required_hits then
      round_idx = round_idx + 1
      reset_round()
    else
      game_over = true
    end
  end
end

local function draw_background()
  rectc(0, 0, SCREEN_W, SCREEN_H * 0.72, 0.52, 0.80, 0.96, 1.0)
  rectc(0, SCREEN_H * 0.72, SCREEN_W, SCREEN_H * 0.28, 0.18, 0.62, 0.24, 1.0)
  rectc(78, 54, 56, 56, 1.00, 0.94, 0.42, 1.0)
  rectc(158, 88, 62, 20, 0.96, 0.98, 1.00, 0.88)
  rectc(184, 78, 58, 18, 0.96, 0.98, 1.00, 0.88)
  rectc(210, 88, 62, 20, 0.96, 0.98, 1.00, 0.88)
end

local function draw_world_3d()
  cam3d(cam.x, cam.y, cam.z, cam.yaw, cam.pitch, cam.fov)

  sprite3d(0.0, 3.2, 18.0, "pombo_up.png", 0.6)

  for i = 1, #birds do
    local b = birds[i]
    if b.alive then
      local sprite = "pombo_up.png"
      if b.falling then
        sprite = "pombo_hit.png"
      elseif math.sin(b.flap) < 0 then
        sprite = "pombo_down.png"
      end
      sprite3d(b.x, b.y, b.z, sprite, 1.0)
    end
  end
end

local function draw_hud()
  begin2d()

  rectc(cross_x - 10, cross_y - 1, 20, 2, 1.0, 0.20, 0.20, 1.0)
  rectc(cross_x - 1, cross_y - 10, 2, 20, 1.0, 0.20, 0.20, 1.0)
  rectc(cross_x - 3, cross_y - 3, 6, 6, 1.0, 1.0, 1.0, 0.88)

  rectc(8, 8, 170, 76, 0.0, 0.0, 0.0, 0.58)
  rectc(12, 14, 162, 8, 0.12, 0.16, 0.24, 1.0)
  rectc(12, 14, math.min(162, score * 0.08), 8, 0.32, 0.78, 1.0, 1.0)

  rectc(12, 30, 80, 8, 0.10, 0.10, 0.10, 1.0)
  rectc(12, 30, math.min(80, hits * (80 / math.max(required_hits, 1))), 8, 0.28, 0.82, 0.30, 1.0)

  for i = 1, max_ammo do
    local c = (i <= ammo) and 0.95 or 0.28
    rectc(12 + (i - 1) * 18, 46, 14, 14, c, c * 0.88, 0.22, 1.0)
  end

  rectc(100, 46, 72, 14, 0.16, 0.16, 0.20, 1.0)
  rectc(102, 48, math.min(68, round_idx * 9), 10, 0.86, 0.38, 0.20, 1.0)

  if flash > 0 then
    rectc(0, 0, SCREEN_W, SCREEN_H, 1.0, 1.0, 1.0, 0.08)
  end

  if game_over then
    rectc(120, 160, 400, 140, 0.30, 0.04, 0.04, 0.78)
    rectc(140, 200, 360, 14, 0.92, 0.18, 0.14, 0.92)
    rectc(140, 230, 180, 8, 0.95, 0.32, 0.18, 0.95)
  end
end

reset_game()

function tick()
  frame = frame + 1
  if shoot_cd > 0 then shoot_cd = shoot_cd - 1 end
  if reload_timer > 0 then
    reload_timer = reload_timer - 1
    if reload_timer <= 0 then ammo = max_ammo end
  end
  if flash > 0 then flash = flash - 1 end

  update_crosshair()
  update_birds()

  draw_background()
  draw_world_3d()
  draw_hud()
end
