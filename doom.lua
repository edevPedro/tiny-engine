local SCREEN_W = 640
local SCREEN_H = 480

local FOV = math.rad(66)
local HALF_FOV_TAN = math.tan(FOV * 0.5)

local RAY_COUNT = 160
local COLUMN_W = SCREEN_W / RAY_COUNT
local MAX_RAY_STEPS = 64

local MOVE_SPEED = 0.085
local STRAFE_SPEED = 0.075
local TURN_SPEED = 0.055

local FLOOR_R = 0.10
local FLOOR_G = 0.08
local FLOOR_B = 0.07
local CEIL_R = 0.06
local CEIL_G = 0.06
local CEIL_B = 0.09

local PLAYER_MAX_HP = 100
local PLAYER_INVULN_FRAMES = 18
local PLAYER_CONTACT_DAMAGE = 8

local WEAPON_COOLDOWN_FRAMES = 11
local WEAPON_DAMAGE = 25
local WEAPON_RANGE = 10.5
local WEAPON_AIM_SPREAD = 0.18

local ENEMY_SPEED = 0.020
local ENEMY_HP = 55
local ENEMY_RADIUS = 0.21
local ENEMY_CONTACT_RANGE = 0.58
local ENEMY_CONTACT_COOLDOWN = 28
local ENEMY_SPAWN_SPEED = 0.05
local MAX_ACTIVE_ENEMIES = 8

local world = {
  "1111111111111111",
  "1000000000000001",
  "1011110111111001",
  "1010010100001001",
  "1010010111101001",
  "1010010000101001",
  "1010011110101001",
  "1010000010101001",
  "1011111010101001",
  "1000001010000001",
  "1011101011111101",
  "1010101000000101",
  "1010111110110101",
  "1000000000110001",
  "1011111111111101",
  "1111111111111111",
}

local wall_palette = {
  [1] = {0.64, 0.62, 0.58},
}

local map_h = #world
local map_w = #world[1]

local player_x = 3.5
local player_y = 3.5
local player_dir = 0.0
local player_radius = 0.20

local pressed = {}
local gp_pressed = {}
local gp_lx = 0.0
local gp_ly = 0.0
local gp_rx = 0.0

local frame = 0
local weapon_flash = 0
local weapon_cooldown = 0
local damage_flash = 0
local invuln = 0
local player_hp = PLAYER_MAX_HP
local kills = 0
local game_over = false
local show_map = true

local wall_depths = {}
local enemies = {}
local spawn_points = {
  {10.5, 2.5}, {13.5, 5.5}, {8.5, 9.5}, {3.5, 12.5}, {12.5, 13.0},
  {6.5, 2.5}, {5.5, 6.5}, {11.5, 8.5}, {2.5, 10.5}, {9.5, 12.5},
  {14.0, 2.5}, {2.5, 4.5}, {6.5, 13.5}, {13.0, 10.0}, {8.0, 4.0},
}

math.randomseed(os.time())

local function clamp(v, lo, hi)
  if v < lo then
    return lo
  end
  if v > hi then
    return hi
  end
  return v
end

local function is_wall(mx, my)
  if mx < 1 or my < 1 or mx > map_w or my > map_h then
    return true
  end
  return world[my]:sub(mx, mx) ~= "0"
end

local function circle_fits(x, y, radius)
  local min_x = math.floor(x - radius) + 1
  local max_x = math.floor(x + radius) + 1
  local min_y = math.floor(y - radius) + 1
  local max_y = math.floor(y + radius) + 1
  return not is_wall(min_x, min_y)
    and not is_wall(max_x, min_y)
    and not is_wall(min_x, max_y)
    and not is_wall(max_x, max_y)
end

local function try_move(nx, ny)
  if circle_fits(nx, player_y, player_radius) then
    player_x = nx
  end

  if circle_fits(player_x, ny, player_radius) then
    player_y = ny
  end
end

local function tone_for_dist(base, dist, side)
  local shade = 1.0 / (1.0 + dist * 0.16)
  shade = clamp(shade, 0.20, 1.0)
  if side == 1 then
    shade = shade * 0.72
  end
  return base[1] * shade, base[2] * shade, base[3] * shade
end

local function has_wall_between(x1, y1, x2, y2)
  local dx = x2 - x1
  local dy = y2 - y1
  local distance = math.sqrt(dx * dx + dy * dy)
  if distance <= 0.001 then
    return false
  end

  local step = 0.08
  local steps = math.floor(distance / step)
  local inv = 1.0 / math.max(steps, 1)
  for i = 1, steps do
    local t = i * inv
    local px = x1 + dx * t
    local py = y1 + dy * t
    if is_wall(math.floor(px) + 1, math.floor(py) + 1) then
      return true
    end
  end
  return false
end

local function active_enemy_count()
  local n = 0
  for i = 1, #enemies do
    if enemies[i].alive then
      n = n + 1
    end
  end
  return n
end

local function can_spawn_at(x, y)
  if not circle_fits(x, y, ENEMY_RADIUS) then
    return false
  end

  local pdx = x - player_x
  local pdy = y - player_y
  if (pdx * pdx + pdy * pdy) < 7.0 then
    return false
  end

  for i = 1, #enemies do
    local e = enemies[i]
    if e.alive then
      local dx = x - e.x
      local dy = y - e.y
      if (dx * dx + dy * dy) < 0.65 then
        return false
      end
    end
  end

  return true
end

local function spawn_score(x, y)
  local dx = x - player_x
  local dy = y - player_y
  local dist = math.sqrt(dx * dx + dy * dy)
  if dist < 0.001 then
    return -1e9
  end

  local dir_x = math.cos(player_dir)
  local dir_y = math.sin(player_dir)
  local front = (dx * dir_x + dy * dir_y) / dist
  local visible = not has_wall_between(player_x, player_y, x, y)

  local score = 0.0
  score = score + math.min(dist, 14.0) * 2.0
  score = score + (-front) * 4.0
  if visible then
    score = score - 6.0
  else
    score = score + 4.0
  end
  score = score + (math.random() * 1.5)
  return score
end

local function spawn_enemy()
  local best_idx = nil
  local best_score = -1e9
  for i = 1, #spawn_points do
    local p = spawn_points[i]
    local sx = p[1]
    local sy = p[2]
    if can_spawn_at(sx, sy) then
      local score = spawn_score(sx, sy)
      if score > best_score then
        best_score = score
        best_idx = i
      end
    end
  end

  if not best_idx then
    return false
  end

  local p = spawn_points[best_idx]
  enemies[#enemies + 1] = {
    x = p[1],
    y = p[2],
    hp = ENEMY_HP,
    alive = true,
    contact_cd = 0,
    hit_flash = 0,
    spawn_progress = 0.0,
  }
  return true
end

for _ = 1, MAX_ACTIVE_ENEMIES do
  if not spawn_enemy() then
    break
  end
end

local function maintain_enemy_population()
  for i = #enemies, 1, -1 do
    if not enemies[i].alive then
      table.remove(enemies, i)
    end
  end

  while active_enemy_count() < MAX_ACTIVE_ENEMIES do
    if not spawn_enemy() then
      break
    end
  end
end

local function draw_enemy_face(x, y, w, h, shade, hit)
  local tone = hit and 0.95 or (0.90 * shade)
  local br = hit and 1.0 or (0.98 * shade)
  local bg = hit and 0.90 or (0.82 * shade)
  local bb = hit and 0.82 or (0.64 * shade)

  rectc(x, y, w, h, br, bg, bb, 1.0)
  rectc(x + w * 0.18, y + h * 0.26, w * 0.18, h * 0.14, 0.10, 0.08, 0.07, 1.0)
  rectc(x + w * 0.64, y + h * 0.26, w * 0.18, h * 0.14, 0.10, 0.08, 0.07, 1.0)
  rectc(x + w * 0.27, y + h * 0.53, w * 0.46, h * 0.12, 0.18 * tone, 0.10 * tone, 0.08 * tone, 1.0)
  rectc(x + w * 0.20, y + h * 0.68, w * 0.60, h * 0.16, 0.96 * tone, 0.18 * tone, 0.16 * tone, 1.0)
  rectc(x + w * 0.10, y + h * 0.10, w * 0.80, h * 0.10, 0.34 * tone, 0.22 * tone, 0.14 * tone, 1.0)
end

local function draw_enemies()
  local dir_x = math.cos(player_dir)
  local dir_y = math.sin(player_dir)
  local plane_x = -dir_y * HALF_FOV_TAN
  local plane_y = dir_x * HALF_FOV_TAN
  local inv_det = 1.0 / (plane_x * dir_y - dir_x * plane_y)

  local order = {}
  for i = 1, #enemies do
    local e = enemies[i]
    if e.alive then
      local dx = e.x - player_x
      local dy = e.y - player_y
      local dist = dx * dx + dy * dy
      order[#order + 1] = {idx = i, dist = dist}
    end
  end

  table.sort(order, function(a, b)
    return a.dist > b.dist
  end)

  for n = 1, #order do
    local e = enemies[order[n].idx]
    local sprite_x = e.x - player_x
    local sprite_y = e.y - player_y

    local trans_x = inv_det * (dir_y * sprite_x - dir_x * sprite_y)
    local trans_y = inv_det * (-plane_y * sprite_x + plane_x * sprite_y)

    if trans_y > 0.12 then
      local sprite_screen_x = (SCREEN_W * 0.5) * (1.0 + trans_x / trans_y)
      local sprite_h = math.abs(SCREEN_H / trans_y)
      local sprite_w = sprite_h * 0.46
      local y_base = (SCREEN_H + sprite_h) * 0.5
      local grow = e.spawn_progress or 1.0
      local draw_h = sprite_h * grow
      local y0 = y_base - draw_h

      local x0 = sprite_screen_x - sprite_w * 0.5
      local x1 = sprite_screen_x + sprite_w * 0.5

      local shade = clamp(1.0 / (1.0 + trans_y * 0.22), 0.22, 1.0)
      local red = 0.78 * shade
      local green = 0.18 * shade
      local blue = 0.14 * shade
      if e.hit_flash > 0 then
        red, green, blue = 1.0, 0.92, 0.85
      end

      for ray = 0, RAY_COUNT - 1 do
        local col_x = ray * COLUMN_W
        if col_x + COLUMN_W >= x0 and col_x <= x1 and trans_y < wall_depths[ray + 1] then
          rectc(col_x, y0, COLUMN_W + 1, draw_h, red, green, blue, 1.0)
        end
      end

      if grow > 0.45 then
        local face_w = sprite_w * 0.82
        local face_h = draw_h * 0.68
        local fx = sprite_screen_x - face_w * 0.5
        local fy = y0 + draw_h * 0.18
        for ray = 0, RAY_COUNT - 1 do
          local col_x = ray * COLUMN_W
          if col_x + COLUMN_W >= fx and col_x <= (fx + face_w) and trans_y < wall_depths[ray + 1] then
            draw_enemy_face(col_x, fy, COLUMN_W + 1, face_h, shade, e.hit_flash > 0)
          end
        end
      end
    end
  end
end

local function cast_and_draw_columns()
  local dir_x = math.cos(player_dir)
  local dir_y = math.sin(player_dir)
  local plane_x = -dir_y * HALF_FOV_TAN
  local plane_y = dir_x * HALF_FOV_TAN

  for i = 0, RAY_COUNT - 1 do
    local cam_x = (2.0 * i / RAY_COUNT) - 1.0
    local ray_x = dir_x + plane_x * cam_x
    local ray_y = dir_y + plane_y * cam_x

    local map_x = math.floor(player_x)
    local map_y = math.floor(player_y)

    local delta_x = (ray_x == 0.0) and 1e30 or math.abs(1.0 / ray_x)
    local delta_y = (ray_y == 0.0) and 1e30 or math.abs(1.0 / ray_y)

    local step_x
    local step_y
    local side_x
    local side_y

    if ray_x < 0 then
      step_x = -1
      side_x = (player_x - map_x) * delta_x
    else
      step_x = 1
      side_x = (map_x + 1.0 - player_x) * delta_x
    end

    if ray_y < 0 then
      step_y = -1
      side_y = (player_y - map_y) * delta_y
    else
      step_y = 1
      side_y = (map_y + 1.0 - player_y) * delta_y
    end

    local hit = 0
    local side = 0
    local wall_id = 1
    local steps = 0

    while hit == 0 and steps < MAX_RAY_STEPS do
      if side_x < side_y then
        side_x = side_x + delta_x
        map_x = map_x + step_x
        side = 0
      else
        side_y = side_y + delta_y
        map_y = map_y + step_y
        side = 1
      end

      if map_x < 0 or map_y < 0 or map_x >= map_w or map_y >= map_h then
        hit = 1
        wall_id = 1
      else
        local cell = world[map_y + 1]:sub(map_x + 1, map_x + 1)
        if cell ~= "0" then
          hit = 1
          wall_id = tonumber(cell) or 1
        end
      end

      steps = steps + 1
    end

    local perp
    if side == 0 then
      perp = (map_x - player_x + (1 - step_x) * 0.5) / ray_x
    else
      perp = (map_y - player_y + (1 - step_y) * 0.5) / ray_y
    end

    perp = math.max(perp, 0.0001)
    wall_depths[i + 1] = perp

    local line_h = math.floor(SCREEN_H / perp)
    local draw_y = math.floor((SCREEN_H - line_h) * 0.5)

    local base = wall_palette[wall_id] or wall_palette[1]
    local r, g, b = tone_for_dist(base, perp, side)
    rectc(i * COLUMN_W, draw_y, COLUMN_W + 1, line_h, r, g, b, 1.0)
  end
end

local function fire_weapon()
  if weapon_cooldown > 0 or game_over then
    return
  end

  weapon_cooldown = WEAPON_COOLDOWN_FRAMES
  weapon_flash = 4

  local dir_x = math.cos(player_dir)
  local dir_y = math.sin(player_dir)
  local best_enemy = nil
  local best_dist = WEAPON_RANGE + 1.0

  for i = 1, #enemies do
    local e = enemies[i]
    if e.alive then
      local dx = e.x - player_x
      local dy = e.y - player_y
      local forward = dx * dir_x + dy * dir_y
      if forward > 0.10 and forward < WEAPON_RANGE then
        local side = math.abs(dx * dir_y - dy * dir_x)
        local hit_window = ENEMY_RADIUS + forward * WEAPON_AIM_SPREAD * 0.03
        if side <= hit_window and not has_wall_between(player_x, player_y, e.x, e.y) then
          if forward < best_dist then
            best_dist = forward
            best_enemy = e
          end
        end
      end
    end
  end

  if best_enemy then
    best_enemy.hp = best_enemy.hp - WEAPON_DAMAGE
    best_enemy.hit_flash = 4
    if best_enemy.hp <= 0 then
      best_enemy.alive = false
      kills = kills + 1
    end
  end
end

local function update_enemies()
  if game_over then
    return
  end

  for i = 1, #enemies do
    local e = enemies[i]
    if e.alive then
      if e.hit_flash > 0 then
        e.hit_flash = e.hit_flash - 1
      end
      if e.spawn_progress < 1.0 then
        e.spawn_progress = math.min(1.0, e.spawn_progress + ENEMY_SPAWN_SPEED)
      end
      if e.contact_cd > 0 then
        e.contact_cd = e.contact_cd - 1
      end

      local dx = player_x - e.x
      local dy = player_y - e.y
      local dist2 = dx * dx + dy * dy
      local dist = math.sqrt(dist2)

      if e.spawn_progress >= 0.98 and dist > 0.001 then
        local ux = dx / dist
        local uy = dy / dist
        local nx = e.x + ux * ENEMY_SPEED
        local ny = e.y + uy * ENEMY_SPEED

        if circle_fits(nx, e.y, ENEMY_RADIUS) then
          e.x = nx
        end
        if circle_fits(e.x, ny, ENEMY_RADIUS) then
          e.y = ny
        end
      end

      if e.spawn_progress >= 1.0 and dist < ENEMY_CONTACT_RANGE and e.contact_cd <= 0 and invuln <= 0 then
        player_hp = player_hp - PLAYER_CONTACT_DAMAGE
        invuln = PLAYER_INVULN_FRAMES
        damage_flash = 5
        e.contact_cd = ENEMY_CONTACT_COOLDOWN
        if player_hp <= 0 then
          player_hp = 0
          game_over = true
        end
      end
    end
  end
end

local function draw_weapon()
  local bob = math.sin(frame * 0.12) * 3.0
  local wy = 374 + bob
  local flash = weapon_flash > 0 and 0.24 or 0.0

  rectc(198, wy + 28, 244, 94, 0.08 + flash, 0.08 + flash, 0.10 + flash, 0.94)
  rectc(230, wy + 22, 180, 76, 0.22 + flash, 0.22 + flash, 0.25 + flash, 1.0)
  rectc(252, wy + 34, 132, 44, 0.66 + flash, 0.66 + flash, 0.70 + flash, 1.0)
  rectc(288, wy + 8, 62, 24, 0.36 + flash, 0.33 + flash, 0.28 + flash, 1.0)
  rectc(296, wy + 12, 46, 14, 0.18 + flash, 0.16 + flash, 0.14 + flash, 1.0)
  rectc(238, wy + 66, 34, 40, 0.42 + flash, 0.24 + flash, 0.12 + flash, 1.0)
  rectc(366, wy + 66, 34, 40, 0.42 + flash, 0.24 + flash, 0.12 + flash, 1.0)

  rectc(317, 239, 6, 2, 0.95, 0.92, 0.86, 1.0)
  rectc(319, 237, 2, 6, 0.95, 0.92, 0.86, 1.0)
end

local function draw_hud()
  local hp_ratio = clamp(player_hp / PLAYER_MAX_HP, 0.0, 1.0)
  local active = active_enemy_count()
  local pressure_ratio = clamp(active / MAX_ACTIVE_ENEMIES, 0.0, 1.0)

  rectc(14, 444, 208, 24, 0.0, 0.0, 0.0, 0.70)
  rectc(18, 450, 200, 8, 0.25, 0.10, 0.10, 1.0)
  rectc(18, 450, 200 * hp_ratio, 8, 0.86, 0.16, 0.10, 1.0)

  rectc(14, 414, 208, 20, 0.0, 0.0, 0.0, 0.60)
  rectc(18, 420, 200, 8, 0.08, 0.20, 0.10, 1.0)
  rectc(18, 420, 200 * pressure_ratio, 8, 0.24, 0.84, 0.38, 1.0)

  local kill_mod = kills % 20
  rectc(230, 444, 132, 24, 0.0, 0.0, 0.0, 0.70)
  rectc(234, 450, 124, 8, 0.08, 0.08, 0.20, 1.0)
  rectc(234, 450, 124 * (kill_mod / 20), 8, 0.30, 0.42, 0.92, 1.0)

  if invuln > 0 then
    rectc(0, 0, SCREEN_W, SCREEN_H, 1.0, 0.15, 0.10, 0.07)
  end

  if game_over then
    rectc(80, 170, 480, 140, 0.35, 0.02, 0.02, 0.72)
    rectc(120, 208, 400, 14, 0.85, 0.18, 0.16, 0.90)
    rectc(120, 236, 220, 8, 0.88, 0.24, 0.20, 0.95)
  end
end

local function draw_minimap()
  local cx = SCREEN_W - 84
  local cy = 84
  local radius = 62
  local cell = 4
  local zoom = 12.0
  local cs = math.cos(player_dir)
  local sn = math.sin(player_dir)

  rectc(cx - radius - 4, cy - radius - 4, radius * 2 + 8, radius * 2 + 8, 0.0, 0.0, 0.0, 0.40)

  for py = -radius, radius, cell do
    for px = -radius, radius, cell do
      local rr = px * px + py * py
      if rr <= radius * radius then
        local sx = px / zoom
        local sy = py / zoom
        local wx = player_x + (sx * cs - sy * sn)
        local wy = player_y + (sx * sn + sy * cs)
        local mx = math.floor(wx) + 1
        local my = math.floor(wy) + 1

        if is_wall(mx, my) then
          rectc(cx + px, cy + py, cell, cell, 0.72, 0.72, 0.78, 0.88)
        else
          rectc(cx + px, cy + py, cell, cell, 0.08, 0.09, 0.10, 0.48)
        end
      end
    end
  end

  for i = 1, #enemies do
    local e = enemies[i]
    if e.alive then
      local dx = e.x - player_x
      local dy = e.y - player_y
      local rx = (dx * cs + dy * sn) * zoom
      local ry = (-dx * sn + dy * cs) * zoom
      if (rx * rx + ry * ry) < (radius - 4) * (radius - 4) then
        rectc(cx + rx - 2, cy + ry - 2, 4, 4, 1.0, 0.18, 0.10, 1.0)
      end
    end
  end

  rectc(cx - 2, cy - 2, 4, 4, 0.20, 0.95, 0.72, 1.0)
  rectc(cx - 1, cy - radius + 10, 2, 9, 0.95, 0.95, 0.82, 1.0)

  for a = 0, 360, 12 do
    local r = math.rad(a)
    local bx = cx + math.cos(r) * radius
    local by = cy + math.sin(r) * radius
    rectc(bx, by, 2, 2, 0.30, 0.82, 0.64, 0.95)
  end
end

function key(name, is_pressed)
  if name == "tab" and is_pressed and not pressed[name] then
    show_map = not show_map
  end

  if (name == "space" or name == "enter") and is_pressed then
    fire_weapon()
  end

  pressed[name] = is_pressed
end

function gamepad_button(name, is_pressed)
  if (name == "start" or name == "back") and is_pressed and not gp_pressed[name] then
    show_map = not show_map
  end

  if (name == "a" or name == "x" or name == "rb") and is_pressed then
    fire_weapon()
  end

  gp_pressed[name] = is_pressed
end

function gamepad_axis(name, value)
  if name == "lx" then
    gp_lx = value
  elseif name == "ly" then
    gp_ly = value
  elseif name == "rx" then
    gp_rx = value
  end
end

function tick()
  frame = frame + 1

  if weapon_flash > 0 then
    weapon_flash = weapon_flash - 1
  end
  if weapon_cooldown > 0 then
    weapon_cooldown = weapon_cooldown - 1
  end
  if invuln > 0 then
    invuln = invuln - 1
  end
  if damage_flash > 0 then
    damage_flash = damage_flash - 1
  end

  if not game_over then
    local forward = 0.0
    local strafe = 0.0
    local turn = 0.0

    if pressed["w"] or gp_pressed["dpad_up"] then
      forward = forward + 1.0
    end
    if pressed["s"] or gp_pressed["dpad_down"] then
      forward = forward - 1.0
    end
    if pressed["a"] or gp_pressed["dpad_left"] then
      strafe = strafe - 1.0
    end
    if pressed["d"] or gp_pressed["dpad_right"] then
      strafe = strafe + 1.0
    end

    if gp_pressed["lb"] then
      strafe = strafe - 1.0
    end
    if gp_pressed["rb"] then
      strafe = strafe + 1.0
    end

    if pressed["left"] then
      turn = turn - 1.0
    end
    if pressed["right"] then
      turn = turn + 1.0
    end

    turn = turn + gp_rx
    forward = forward - gp_ly
    strafe = strafe + gp_lx

    player_dir = player_dir + turn * TURN_SPEED

    local dir_x = math.cos(player_dir)
    local dir_y = math.sin(player_dir)
    local right_x = math.cos(player_dir + math.pi * 0.5)
    local right_y = math.sin(player_dir + math.pi * 0.5)

    local move_x = dir_x * forward * MOVE_SPEED + right_x * strafe * STRAFE_SPEED
    local move_y = dir_y * forward * MOVE_SPEED + right_y * strafe * STRAFE_SPEED

    try_move(player_x + move_x, player_y + move_y)
    update_enemies()
    maintain_enemy_population()
  end

  rectc(0, 0, SCREEN_W, SCREEN_H * 0.5, CEIL_R, CEIL_G, CEIL_B, 1.0)
  rectc(0, SCREEN_H * 0.5, SCREEN_W, SCREEN_H * 0.5, FLOOR_R, FLOOR_G, FLOOR_B, 1.0)

  cast_and_draw_columns()
  draw_enemies()
  draw_weapon()
  draw_hud()

  if show_map then
    draw_minimap()
  end

  if damage_flash > 0 then
    rectc(0, 0, SCREEN_W, SCREEN_H, 1.0, 0.12, 0.08, 0.09)
  end
end
