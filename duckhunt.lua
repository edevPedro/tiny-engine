local SCREEN_W = 640
local SCREEN_H = 480

local pressed = {}
local gp_pressed = {}
local gp_lx = 0.0
local gp_ly = 0.0
local gp_gx = 0.0
local gp_gy = 0.0
local gp_gz = 0.0

local gyro_sens = 10.0
local gyro_dead = 0.12

local frame = 0
local score = 0
local round_idx = 1
local ducks_hit_round = 0
local ducks_spawned_round = 0
local ducks_target_round = 10

local shells = 3
local max_shells = 3
local shoot_cooldown = 0
local reload_timer = 0

local cross_x = SCREEN_W * 0.5
local cross_y = SCREEN_H * 0.45
local cross_speed = 5.0

local ducks = {}
local max_active_ducks = 2
local spawn_timer = 0

local game_over = false
local flash_timer = 0

local function clamp(v, lo, hi)
  if v < lo then
    return lo
  end
  if v > hi then
    return hi
  end
  return v
end

local function new_duck()
  local dir = (math.random() < 0.5) and 1 or -1
  local x = (dir == 1) and -24 or (SCREEN_W + 24)
  local y = math.random(60, 260)
  local speed = 2.2 + math.random() * 1.8 + round_idx * 0.18

  return {
    x = x,
    y = y,
    vx = speed * dir,
    vy = (math.random() * 1.2 - 0.6),
    alive = true,
    wing = math.random() * math.pi * 2,
    fall = 0.0,
    escaped = false,
  }
end

local function alive_ducks_count()
  local c = 0
  for i = 1, #ducks do
    if ducks[i].alive then
      c = c + 1
    end
  end
  return c
end

local function reset_round(new_round)
  ducks = {}
  ducks_hit_round = 0
  ducks_spawned_round = 0
  ducks_target_round = 10 + (new_round - 1) * 2
  shells = max_shells
  shoot_cooldown = 0
  reload_timer = 0
  spawn_timer = 18
end

local function reset_game()
  score = 0
  round_idx = 1
  game_over = false
  flash_timer = 0
  reset_round(round_idx)
end

local function draw_background()
  rectc(0, 0, SCREEN_W, SCREEN_H * 0.72, 0.48, 0.78, 0.98, 1.0)
  rectc(0, SCREEN_H * 0.72, SCREEN_W, SCREEN_H * 0.28, 0.16, 0.62, 0.20, 1.0)

  rectc(80, 56, 56, 56, 1.00, 0.94, 0.42, 1.0)

  rectc(160, 90, 64, 20, 0.95, 0.98, 1.00, 0.85)
  rectc(190, 80, 60, 18, 0.95, 0.98, 1.00, 0.85)
  rectc(216, 90, 64, 20, 0.95, 0.98, 1.00, 0.85)

  rectc(420, 120, 80, 22, 0.95, 0.98, 1.00, 0.88)
  rectc(456, 108, 68, 20, 0.95, 0.98, 1.00, 0.88)
  rectc(486, 120, 80, 22, 0.95, 0.98, 1.00, 0.88)

  rectc(0, 410, SCREEN_W, 70, 0.12, 0.46, 0.15, 1.0)
end

local function draw_duck(d)
  local sprite = "pombo_up.png"
  if not d.alive and d.fall > 0 then
    sprite = "pombo_hit.png"
  elseif math.sin(d.wing) < 0 then
    sprite = "pombo_down.png"
  end
  png(d.x, d.y, sprite)
end

local function draw_crosshair()
  rectc(cross_x - 10, cross_y - 1, 20, 2, 1.0, 0.2, 0.2, 1.0)
  rectc(cross_x - 1, cross_y - 10, 2, 20, 1.0, 0.2, 0.2, 1.0)
  rectc(cross_x - 3, cross_y - 3, 6, 6, 1.0, 1.0, 1.0, 0.9)
end

local function draw_hud()
  rectc(10, 10, 210, 78, 0.0, 0.0, 0.0, 0.55)

  rectc(18, 22, 194, 8, 0.12, 0.18, 0.26, 1.0)
  rectc(18, 22, math.min(194, score * 0.08), 8, 0.35, 0.80, 1.0, 1.0)

  rectc(18, 40, 80, 8, 0.10, 0.10, 0.10, 1.0)
  rectc(18, 40, math.min(80, ducks_hit_round * (80 / math.max(ducks_target_round, 1))), 8, 0.20, 0.85, 0.30, 1.0)

  for i = 1, max_shells do
    local c = (i <= shells) and 0.95 or 0.25
    rectc(18 + (i - 1) * 18, 56, 12, 18, c, c * 0.9, 0.22, 1.0)
  end

  rectc(122, 56, 90, 18, 0.18, 0.18, 0.22, 1.0)
  rectc(124, 58, math.min(86, round_idx * 12), 14, 0.88, 0.40, 0.22, 1.0)

  if game_over then
    rectc(120, 170, 400, 130, 0.30, 0.04, 0.04, 0.80)
    rectc(150, 206, 340, 16, 0.95, 0.18, 0.14, 0.96)
    rectc(150, 238, 200, 10, 0.95, 0.32, 0.18, 0.96)
  end
end

local function shoot()
  if game_over or shells <= 0 or shoot_cooldown > 0 or reload_timer > 0 then
    return
  end

  shells = shells - 1
  shoot_cooldown = 8
  flash_timer = 3

  local best_i = nil
  local best_d2 = 1e9
  for i = 1, #ducks do
    local d = ducks[i]
    if d.alive then
      local cx = d.x + 11
      local cy = d.y + 6
      local dx = cx - cross_x
      local dy = cy - cross_y
      local d2 = dx * dx + dy * dy
      if d2 < (24 * 24) and d2 < best_d2 then
        best_d2 = d2
        best_i = i
      end
    end
  end

  if best_i then
    local d = ducks[best_i]
    d.alive = false
    d.fall = 1.5
    score = score + 100 + (round_idx - 1) * 20
    ducks_hit_round = ducks_hit_round + 1
  end

  if shells <= 0 then
    reload_timer = 30
  end
end

local function update_ducks()
  if game_over then
    return
  end

  if ducks_spawned_round < ducks_target_round and alive_ducks_count() < max_active_ducks then
    if spawn_timer <= 0 then
      ducks[#ducks + 1] = new_duck()
      ducks_spawned_round = ducks_spawned_round + 1
      spawn_timer = 30
    end
  end

  for i = 1, #ducks do
    local d = ducks[i]
    if d.alive then
      d.x = d.x + d.vx
      d.y = d.y + d.vy + math.sin((frame + i * 13) * 0.06) * 0.4
      d.wing = d.wing + 0.35

      if d.y < 40 then
        d.y = 40
        d.vy = math.abs(d.vy)
      elseif d.y > 330 then
        d.y = 330
        d.vy = -math.abs(d.vy)
      end

      if d.x < -40 or d.x > SCREEN_W + 40 then
        d.alive = false
        d.escaped = true
      end
    else
      if d.fall > 0 then
        d.y = d.y + d.fall
        d.fall = d.fall + 0.45
      end
    end
  end

  if ducks_spawned_round >= ducks_target_round and alive_ducks_count() == 0 then
    if ducks_hit_round >= math.floor(ducks_target_round * 0.6) then
      round_idx = round_idx + 1
      max_active_ducks = clamp(1 + math.floor(round_idx / 2), 2, 4)
      reset_round(round_idx)
    else
      game_over = true
    end
  end
end

function key(name, is_pressed)
  if (name == "space" or name == "enter") and is_pressed then
    if game_over then
      reset_game()
    else
      shoot()
    end
  end
  pressed[name] = is_pressed
end

function gamepad_button(name, is_pressed)
  if (name == "a" or name == "x" or name == "rb") and is_pressed then
    if game_over then
      reset_game()
    else
      shoot()
    end
  end
  gp_pressed[name] = is_pressed
end

function gamepad_axis(name, value)
  if name == "lx" then
    gp_lx = value
  elseif name == "ly" then
    gp_ly = value
  elseif name == "gyro_x" then
    gp_gx = value
  elseif name == "gyro_y" then
    gp_gy = value
  elseif name == "gyro_z" then
    gp_gz = value
  end
end

local function gyro_clamped(v)
  if v > -gyro_dead and v < gyro_dead then
    return 0.0
  end
  return v
end

local function update_crosshair()
  local mx = 0.0
  local my = 0.0

  if pressed["left"] or pressed["a"] then
    mx = mx - 1.0
  end
  if pressed["right"] or pressed["d"] then
    mx = mx + 1.0
  end
  if pressed["up"] or pressed["w"] then
    my = my - 1.0
  end
  if pressed["down"] or pressed["s"] then
    my = my + 1.0
  end

  mx = mx + gp_lx
  my = my + gp_ly

  -- Giroscópio (SDL + DS4): rad/s → deslocamento por frame; gyro_z ≈ guinada, gyro_x ≈ arfagem.
  mx = mx + gyro_clamped(gp_gz) * gyro_sens
  my = my + gyro_clamped(gp_gx) * gyro_sens

  cross_x = clamp(cross_x + mx * cross_speed, 8, SCREEN_W - 8)
  cross_y = clamp(cross_y + my * cross_speed, 20, SCREEN_H - 20)
end

reset_game()

function tick()
  frame = frame + 1

  if shoot_cooldown > 0 then
    shoot_cooldown = shoot_cooldown - 1
  end
  if spawn_timer > 0 then
    spawn_timer = spawn_timer - 1
  end
  if reload_timer > 0 then
    reload_timer = reload_timer - 1
    if reload_timer <= 0 then
      shells = max_shells
    end
  end
  if flash_timer > 0 then
    flash_timer = flash_timer - 1
  end

  update_crosshair()
  update_ducks()

  draw_background()

  for i = 1, #ducks do
    draw_duck(ducks[i])
  end

  if flash_timer > 0 then
    rectc(0, 0, SCREEN_W, SCREEN_H, 1.0, 1.0, 1.0, 0.08)
  end

  draw_crosshair()
  draw_hud()
end
