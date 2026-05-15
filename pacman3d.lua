local SCREEN_W = 640
local SCREEN_H = 480

local FOV = math.rad(66)
local HALF_FOV_TAN = math.tan(FOV * 0.5)
local RAY_COUNT = 160
local COLUMN_W = SCREEN_W / RAY_COUNT
local MAX_RAY_STEPS = 80

local MOVE_SPEED = 0.078
local TURN_SPEED = 0.060
local PLAYER_RADIUS = 0.18

local GHOST_SPEED = 0.034
local GHOST_FRIGHT_SPEED = 0.026
local GHOST_EATEN_SPEED = 0.052
local GHOST_HIT_RANGE = 0.42

local POWER_FRAMES = 60 * 7
local POWER_WARN_FRAMES = 60 * 2
local RESPAWN_INVULN_FRAMES = 60

local FRUIT_LIFETIME = 60 * 10

local map_rows = {
  "#################",
  "#o.............o#",
  "#..##..###..##..#",
  "#...............#",
  "###.###.#.#.###.#",
  "#.......P.......#",
  "#.#.#.##.##.#.#.#",
  "#.#...#GGG#...#.#",
  "#.#...#####...#.#",
  "#...#.......#...#",
  "#.###...#...###.#",
  "#o......#......o#",
  "#################",
}

local map_h = #map_rows
local map_w = #map_rows[1]

local walls = {}
local pellets = {}
local pellet_count = 0
local total_pellets = 0
local ghost_spawns = {}
local home_bfs_cache = {}

local player_spawn_x = 2.5
local player_spawn_y = 2.5
local player_x = 2.5
local player_y = 2.5
local player_dir = -math.pi * 0.5

local wall_depths = {}
local ghosts = {}

local pressed = {}
local gp_pressed = {}
local gp_lx = 0.0
local gp_ly = 0.0
local gp_rx = 0.0

local frame = 0
local score = 0
local lives = 3
local game_over = false
local game_won = false
local invuln_timer = 0
local power_timer = 0
local power_chain = 0
local damage_flash = 0

local fruit = {
  active = false,
  kind = "cherry",
  x = 8.5,
  y = 6.5,
  timer = 0,
  spawned_70 = false,
  spawned_30 = false,
}

local ghost_palette = {
  {1.00, 0.18, 0.16},
  {1.00, 0.58, 0.18},
  {0.22, 0.72, 1.00},
  {1.00, 0.45, 0.82},
}

local function clamp(v, lo, hi)
  if v < lo then
    return lo
  end
  if v > hi then
    return hi
  end
  return v
end

local function key_xy(x, y)
  return x .. ":" .. y
end

local function parse_map()
  home_bfs_cache = {}
  walls = {}
  pellets = {}
  ghost_spawns = {}
  pellet_count = 0

  for y = 1, map_h do
    local row = map_rows[y]
    walls[y] = {}
    for x = 1, map_w do
      local c = row:sub(x, x)
      walls[y][x] = c == "#"

      if c == "." or c == "o" then
        pellets[key_xy(x, y)] = c
        pellet_count = pellet_count + 1
      elseif c == "P" then
        player_spawn_x = x - 0.5
        player_spawn_y = y - 0.5
      elseif c == "G" then
        ghost_spawns[#ghost_spawns + 1] = {x = x - 0.5, y = y - 0.5}
      end
    end
  end

  total_pellets = pellet_count
  player_x = player_spawn_x
  player_y = player_spawn_y
  player_dir = -math.pi * 0.5
end

local function is_wall(mx, my)
  if mx < 1 or my < 1 or mx > map_w or my > map_h then
    return true
  end
  return walls[my][mx]
end

local function home_distmap_from(gmx, gmy)
  local key = gmx .. ":" .. gmy
  local cached = home_bfs_cache[key]
  if cached then
    return cached
  end
  local dist = {}
  if is_wall(gmx, gmy) then
    home_bfs_cache[key] = dist
    return dist
  end
  local q = { { gmx, gmy } }
  dist[gmy] = dist[gmy] or {}
  dist[gmy][gmx] = 0
  local qi = 1
  while qi <= #q do
    local mx = q[qi][1]
    local my = q[qi][2]
    qi = qi + 1
    local d = dist[my][mx] + 1
    local nbrs = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
    for j = 1, 4 do
      local nx = mx + nbrs[j][1]
      local ny = my + nbrs[j][2]
      if not is_wall(nx, ny) then
        if not dist[ny] then
          dist[ny] = {}
        end
        if dist[ny][nx] == nil then
          dist[ny][nx] = d
          q[#q + 1] = { nx, ny }
        end
      end
    end
  end
  home_bfs_cache[key] = dist
  return dist
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
  if nx < 0.15 then
    nx = map_w - 0.15
  elseif nx > map_w - 0.15 then
    nx = 0.15
  end

  if circle_fits(nx, player_y, PLAYER_RADIUS) then
    player_x = nx
  end
  if circle_fits(player_x, ny, PLAYER_RADIUS) then
    player_y = ny
  end
end

local function reset_player()
  player_x = player_spawn_x
  player_y = player_spawn_y
  player_dir = -math.pi * 0.5
  invuln_timer = RESPAWN_INVULN_FRAMES
end

local function build_ghosts()
  ghosts = {}
  if #ghost_spawns == 0 then
    ghost_spawns = {{x = 8.5, y = 7.5}}
  end

  for i = 1, 4 do
    local s = ghost_spawns[((i - 1) % #ghost_spawns) + 1]
    local gmx = math.floor(s.x) + 1
    local gmy = math.floor(s.y) + 1
    ghosts[i] = {
      x = s.x,
      y = s.y,
      spawn_x = s.x,
      spawn_y = s.y,
      dir_x = 1,
      dir_y = 0,
      state = "chase",
      color = ghost_palette[i],
      pick_cell_x = nil,
      pick_cell_y = nil,
      prev_ai_state = "chase",
      home_dist = home_distmap_from(gmx, gmy),
    }
  end
end

local function tone_for_wall(dist, side)
  local shade = 1.0 / (1.0 + dist * 0.14)
  shade = clamp(shade, 0.20, 1.0)
  if side == 1 then
    shade = shade * 0.72
  end
  return 0.12 * shade, 0.28 * shade, 0.84 * shade
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

      if is_wall(map_x + 1, map_y + 1) then
        hit = 1
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
    local r, g, b = tone_for_wall(perp, side)
    rectc(i * COLUMN_W, draw_y, COLUMN_W + 1, line_h, r, g, b, 1.0)
  end
end

local function draw_sprite_column(x0, x1, y0, h, depth, r, g, b)
  for ray = 0, RAY_COUNT - 1 do
    local col_x = ray * COLUMN_W
    if col_x + COLUMN_W >= x0 and col_x <= x1 and depth < wall_depths[ray + 1] then
      rectc(col_x, y0, COLUMN_W + 1, h, r, g, b, 1.0)
    end
  end
end

local function project_point(wx, wy)
  local dir_x = math.cos(player_dir)
  local dir_y = math.sin(player_dir)
  local plane_x = -dir_y * HALF_FOV_TAN
  local plane_y = dir_x * HALF_FOV_TAN
  local inv_det = 1.0 / (plane_x * dir_y - dir_x * plane_y)

  local sx = wx - player_x
  local sy = wy - player_y
  local tx = inv_det * (dir_y * sx - dir_x * sy)
  local ty = inv_det * (-plane_y * sx + plane_x * sy)
  return tx, ty
end

local function draw_pellets()
  local bob = 0.5 + 0.5 * math.sin(frame * 0.20)
  for k, kind in pairs(pellets) do
    local sep = k:find(":")
    local mx = tonumber(k:sub(1, sep - 1))
    local my = tonumber(k:sub(sep + 1))
    local wx = mx - 0.5
    local wy = my - 0.5

    local tx, ty = project_point(wx, wy)
    if ty > 0.25 then
      local screen_x = (SCREEN_W * 0.5) * (1.0 + tx / ty)
      local base = kind == "o" and 0.15 or 0.08
      local h = math.abs(SCREEN_H / ty) * (base + bob * 0.02)
      local w = h
      local y0 = SCREEN_H * 0.70 - h * 0.5
      local x0 = screen_x - w * 0.5
      local x1 = screen_x + w * 0.5
      local shade = clamp(1.0 / (1.0 + ty * 0.22), 0.30, 1.0)

      if kind == "o" then
        draw_sprite_column(x0, x1, y0, h, ty, 1.0 * shade, 0.95 * shade, 0.28 * shade)
      else
        draw_sprite_column(x0, x1, y0, h, ty, 1.0 * shade, 0.94 * shade, 0.58 * shade)
      end
    end
  end
end

local function draw_fruit()
  if not fruit.active then
    return
  end

  local tx, ty = project_point(fruit.x, fruit.y)
  if ty <= 0.25 then
    return
  end

  local screen_x = (SCREEN_W * 0.5) * (1.0 + tx / ty)
  local h = math.abs(SCREEN_H / ty) * 0.18
  local w = h * 1.1
  local y0 = SCREEN_H * 0.68 - h * 0.5
  local x0 = screen_x - w * 0.5
  local x1 = screen_x + w * 0.5

  local shade = clamp(1.0 / (1.0 + ty * 0.20), 0.30, 1.0)
  if fruit.kind == "cherry" then
    draw_sprite_column(x0, x1, y0, h, ty, 0.96 * shade, 0.16 * shade, 0.18 * shade)
    draw_sprite_column(screen_x - w * 0.08, screen_x + w * 0.05, y0 - h * 0.18, h * 0.18, ty, 0.24, 0.72, 0.22)
  else
    draw_sprite_column(x0, x1, y0, h, ty, 0.98 * shade, 0.44 * shade, 0.20 * shade)
    draw_sprite_column(screen_x - w * 0.09, screen_x + w * 0.04, y0 - h * 0.18, h * 0.18, ty, 0.20, 0.70, 0.20)
  end
end

local function draw_ghosts()
  local order = {}
  for i = 1, #ghosts do
    local g = ghosts[i]
    local dx = g.x - player_x
    local dy = g.y - player_y
    order[#order + 1] = {idx = i, dist = dx * dx + dy * dy}
  end

  table.sort(order, function(a, b)
    return a.dist > b.dist
  end)

  for n = 1, #order do
    local g = ghosts[order[n].idx]
    local tx, ty = project_point(g.x, g.y)
    if ty > 0.12 then
      local screen_x = (SCREEN_W * 0.5) * (1.0 + tx / ty)
      local h = math.abs(SCREEN_H / ty) * 0.86
      local w = h * 0.62
      local y0 = (SCREEN_H - h) * 0.5
      local x0 = screen_x - w * 0.5
      local x1 = screen_x + w * 0.5

      local shade = clamp(1.0 / (1.0 + ty * 0.20), 0.25, 1.0)
      local br, bg, bb

      if g.state == "frightened" then
        local warn = power_timer < POWER_WARN_FRAMES and ((frame // 8) % 2 == 0)
        if warn then
          br, bg, bb = 0.92, 0.92, 1.00
        else
          br, bg, bb = 0.18, 0.38, 0.98
        end
      elseif g.state == "eaten" then
        br, bg, bb = 0.16, 0.16, 0.20
      else
        br, bg, bb = g.color[1], g.color[2], g.color[3]
      end

      draw_sprite_column(x0, x1, y0, h, ty, br * shade, bg * shade, bb * shade)

      local eye_h = h * 0.16
      local eye_w = w * 0.19
      local eye_y = y0 + h * 0.28
      draw_sprite_column(screen_x - w * 0.26, screen_x - w * 0.26 + eye_w, eye_y, eye_h, ty, 1.0, 1.0, 1.0)
      draw_sprite_column(screen_x + w * 0.08, screen_x + w * 0.08 + eye_w, eye_y, eye_h, ty, 1.0, 1.0, 1.0)
      draw_sprite_column(screen_x - w * 0.22, screen_x - w * 0.22 + eye_w * 0.46, eye_y + eye_h * 0.30, eye_h * 0.48, ty, 0.10, 0.10, 0.18)
      draw_sprite_column(screen_x + w * 0.12, screen_x + w * 0.12 + eye_w * 0.46, eye_y + eye_h * 0.30, eye_h * 0.48, ty, 0.10, 0.10, 0.18)
    end
  end
end

local function fruit_points(kind)
  if kind == "strawberry" then
    return 300
  end
  return 100
end

local function maybe_spawn_fruit()
  if fruit.active or game_over or game_won then
    return
  end

  local ratio = pellet_count / math.max(total_pellets, 1)
  if not fruit.spawned_70 and ratio <= 0.70 then
    fruit.active = true
    fruit.kind = "cherry"
    fruit.timer = FRUIT_LIFETIME
    fruit.spawned_70 = true
  elseif not fruit.spawned_30 and ratio <= 0.30 then
    fruit.active = true
    fruit.kind = "strawberry"
    fruit.timer = FRUIT_LIFETIME
    fruit.spawned_30 = true
  end
end

local function collect_items()
  local mx = math.floor(player_x) + 1
  local my = math.floor(player_y) + 1
  local k = key_xy(mx, my)
  local kind = pellets[k]
  if kind then
    pellets[k] = nil
    pellet_count = pellet_count - 1

    if kind == "o" then
      score = score + 50
      power_timer = POWER_FRAMES
      power_chain = 0
      for i = 1, #ghosts do
        local g = ghosts[i]
        if g.state ~= "eaten" then
          g.state = "frightened"
        end
      end
    else
      score = score + 10
    end

    if pellet_count <= 0 then
      game_won = true
    end
  end

  if fruit.active then
    local dx = fruit.x - player_x
    local dy = fruit.y - player_y
    if (dx * dx + dy * dy) < 0.45 then
      score = score + fruit_points(fruit.kind)
      fruit.active = false
      fruit.timer = 0
    end
  end
end

local function choose_ghost_direction(g)
  local cx = math.floor(g.x) + 1
  local cy = math.floor(g.y) + 1

  local dirs = {
    {1, 0},
    {-1, 0},
    {0, 1},
    {0, -1},
  }

  local rev_x = -g.dir_x
  local rev_y = -g.dir_y
  local best_dx = g.dir_x
  local best_dy = g.dir_y
  local best_score = -1e9

  if g.state == "eaten" and g.home_dist then
    local row = g.home_dist[cy]
    local d_here = row and row[cx]
    if d_here ~= nil and d_here > 0 then
      local best_d = 1e9
      for i = 1, #dirs do
        local d = dirs[i]
        local dx = d[1]
        local dy = d[2]
        local nx = cx + dx
        local ny = cy + dy
        if not is_wall(nx, ny) then
          local nr = g.home_dist[ny]
          local dn = nr and nr[nx]
          if dn ~= nil and dn <= best_d then
            best_d = dn
            best_dx = dx
            best_dy = dy
          end
        end
      end
      if best_d < 1e8 then
        g.dir_x = best_dx
        g.dir_y = best_dy
        return
      end
    end
  end

  local ux, uy = 0.0, 0.0
  if g.state == "eaten" then
    local sx = g.spawn_x - g.x
    local sy = g.spawn_y - g.y
    local sl = math.sqrt(sx * sx + sy * sy)
    if sl > 1e-4 then
      ux, uy = sx / sl, sy / sl
    else
      ux, uy = 1.0, 0.0
    end
  else
    local wx = player_x - g.x
    local wy = player_y - g.y
    local wl = math.sqrt(wx * wx + wy * wy)
    if wl > 1e-4 then
      wx, wy = wx / wl, wy / wl
    else
      wx, wy = 1.0, 0.0
    end
    if g.state == "frightened" then
      ux, uy = -wx, -wy
    else
      ux, uy = wx, wy
    end
  end

  for i = 1, #dirs do
    local d = dirs[i]
    local dx = d[1]
    local dy = d[2]
    local nx = cx + dx
    local ny = cy + dy

    if not is_wall(nx, ny) then
      local reverse_penalty = 0.0
      if g.state ~= "eaten" then
        reverse_penalty = (dx == rev_x and dy == rev_y) and -1.25 or 0.0
      end
      -- Produto escalar com o alvo: maximizar = ir na direção desejada.
      local align = dx * ux + dy * uy
      -- Sem math.random: a cada frame na interseção o score mudava e a direção oscilava.
      local score_dir = reverse_penalty + align * 6.0
      if score_dir > best_score then
        best_score = score_dir
        best_dx = dx
        best_dy = dy
      end
    end
  end

  g.dir_x = best_dx
  g.dir_y = best_dy
end

local function reset_ghost(i)
  local g = ghosts[i]
  g.x = g.spawn_x
  g.y = g.spawn_y
  g.dir_x = 1
  g.dir_y = 0
  g.state = "chase"
  g.pick_cell_x = nil
  g.pick_cell_y = nil
  g.prev_ai_state = "chase"
end

local function update_ghosts()
  if game_over or game_won then
    return
  end

  for i = 1, #ghosts do
    local g = ghosts[i]

    if g.state ~= "eaten" then
      if power_timer > 0 then
        g.state = "frightened"
      else
        g.state = "chase"
      end
    end

    if g.prev_ai_state ~= g.state then
      g.pick_cell_x = nil
      g.pick_cell_y = nil
      g.prev_ai_state = g.state
    end

    -- Uma decisão por (célula, visita ao centro): evita reescolher 10+ frames seguidos com scores diferentes.
    local near_center_x = math.abs(g.x - (math.floor(g.x) + 0.5)) < 0.14
    local near_center_y = math.abs(g.y - (math.floor(g.y) + 0.5)) < 0.14
    local at_center = near_center_x and near_center_y
    local tcx = math.floor(g.x) + 1
    local tcy = math.floor(g.y) + 1

    if at_center then
      if g.pick_cell_x ~= tcx or g.pick_cell_y ~= tcy then
        choose_ghost_direction(g)
        g.pick_cell_x = tcx
        g.pick_cell_y = tcy
      end
    else
      g.pick_cell_x = nil
      g.pick_cell_y = nil
    end

    local speed = GHOST_SPEED
    if g.state == "frightened" then
      speed = GHOST_FRIGHT_SPEED
    elseif g.state == "eaten" then
      speed = GHOST_EATEN_SPEED
    end

    local nx = g.x + g.dir_x * speed
    local ny = g.y + g.dir_y * speed
    if circle_fits(nx, ny, 0.12) then
      g.x = nx
      g.y = ny
    else
      choose_ghost_direction(g)
    end

    if g.state == "eaten" then
      local sx = g.spawn_x - g.x
      local sy = g.spawn_y - g.y
      if (sx * sx + sy * sy) < 0.18 then
        g.x = g.spawn_x
        g.y = g.spawn_y
        g.state = power_timer > 0 and "frightened" or "chase"
        g.pick_cell_x = nil
        g.pick_cell_y = nil
        g.prev_ai_state = g.state
      end
    end

    local dx = g.x - player_x
    local dy = g.y - player_y
    local d2 = dx * dx + dy * dy
    if d2 < (GHOST_HIT_RANGE * GHOST_HIT_RANGE) and invuln_timer <= 0 then
      if g.state == "frightened" then
        power_chain = power_chain + 1
        local bonus = 200 * (2 ^ (power_chain - 1))
        score = score + bonus
        g.state = "eaten"
      elseif g.state == "chase" then
        lives = lives - 1
        damage_flash = 8
        if lives <= 0 then
          lives = 0
          game_over = true
        else
          reset_player()
          for gi = 1, #ghosts do
            reset_ghost(gi)
          end
        end
      end
    end
  end
end

local function draw_hud()
  local progress = 1.0 - (pellet_count / math.max(total_pellets, 1))
  local power_ratio = clamp(power_timer / POWER_FRAMES, 0.0, 1.0)

  rectc(12, 444, 228, 24, 0.0, 0.0, 0.0, 0.72)
  rectc(16, 450, 220, 8, 0.16, 0.16, 0.18, 1.0)
  rectc(16, 450, 220 * progress, 8, 1.0, 0.80, 0.16, 1.0)

  rectc(12, 414, 228, 22, 0.0, 0.0, 0.0, 0.62)
  rectc(16, 420, 220, 8, 0.10, 0.12, 0.24, 1.0)
  rectc(16, 420, 220 * power_ratio, 8, 0.22, 0.70, 1.0, 1.0)

  for i = 1, 5 do
    local x = 252 + (i - 1) * 22
    local alive = i <= lives
    rectc(x, 448, 16, 12, alive and 1.0 or 0.20, alive and 0.86 or 0.20, alive and 0.06 or 0.20, 1.0)
  end

  local score_mod = (score % 1000) / 1000
  rectc(380, 444, 180, 24, 0.0, 0.0, 0.0, 0.72)
  rectc(384, 450, 172, 8, 0.12, 0.12, 0.14, 1.0)
  rectc(384, 450, 172 * score_mod, 8, 0.95, 0.95, 0.96, 1.0)

  if invuln_timer > 0 then
    rectc(0, 0, SCREEN_W, SCREEN_H, 0.18, 0.38, 1.00, 0.06)
  end
  if damage_flash > 0 then
    rectc(0, 0, SCREEN_W, SCREEN_H, 1.00, 0.10, 0.08, 0.12)
  end

  if game_over then
    rectc(90, 176, 460, 132, 0.32, 0.04, 0.04, 0.80)
    rectc(128, 210, 384, 14, 0.88, 0.16, 0.14, 0.92)
    rectc(128, 236, 200, 10, 0.96, 0.28, 0.20, 0.95)
  elseif game_won then
    rectc(90, 176, 460, 132, 0.02, 0.24, 0.08, 0.76)
    rectc(128, 210, 384, 14, 0.22, 0.92, 0.36, 0.95)
    rectc(128, 236, 300, 10, 0.34, 1.00, 0.52, 1.0)
  end
end

local function draw_top_map()
  local scale = 10
  local pad = 10
  local map_px_w = map_w * scale
  local map_px_h = map_h * scale
  local ox = math.floor((SCREEN_W - map_px_w) * 0.5)
  local oy = 8

  rectc(0, 0, SCREEN_W, map_px_h + 2 * pad + 6, 0.02, 0.02, 0.03, 0.92)
  rectc(ox - pad, oy - pad, map_px_w + pad * 2, map_px_h + pad * 2, 0.0, 0.0, 0.0, 0.82)

  for y = 1, map_h do
    for x = 1, map_w do
      local cell_x = ox + (x - 1) * scale
      local cell_y = oy + (y - 1) * scale
      if is_wall(x, y) then
        rectc(cell_x, cell_y, scale - 1, scale - 1, 0.12, 0.26, 0.88, 1.0)
      else
        rectc(cell_x, cell_y, scale - 1, scale - 1, 0.02, 0.02, 0.05, 0.75)
      end
    end
  end

  for k, kind in pairs(pellets) do
    local sep = k:find(":")
    local mx = tonumber(k:sub(1, sep - 1))
    local my = tonumber(k:sub(sep + 1))
    local cx = ox + (mx - 1) * scale + scale * 0.5
    local cy = oy + (my - 1) * scale + scale * 0.5
    if kind == "o" then
      rectc(cx - 2, cy - 2, 4, 4, 1.0, 0.95, 0.35, 1.0)
    else
      rectc(cx - 1, cy - 1, 2, 2, 1.0, 0.92, 0.62, 1.0)
    end
  end

  if fruit.active then
    local fx = ox + fruit.x * scale
    local fy = oy + fruit.y * scale
    local fr, fg, fb = 0.95, 0.28, 0.22
    if fruit.kind == "strawberry" then
      fr, fg, fb = 1.0, 0.45, 0.22
    end
    rectc(fx - 3, fy - 3, 6, 6, fr, fg, fb, 1.0)
  end

  for i = 1, #ghosts do
    local g = ghosts[i]
    local cr, cg, cb = g.color[1], g.color[2], g.color[3]
    if g.state == "frightened" then
      cr, cg, cb = 0.22, 0.42, 1.00
    elseif g.state == "eaten" then
      cr, cg, cb = 0.20, 0.20, 0.24
    end
    rectc(ox + g.x * scale - 3, oy + g.y * scale - 3, 6, 6, cr, cg, cb, 1.0)
  end

  local px = ox + player_x * scale
  local py = oy + player_y * scale
  rectc(px - 3, py - 3, 6, 6, 1.0, 0.95, 0.15, 1.0)
  rectc(px, py, math.cos(player_dir) * 8, math.sin(player_dir) * 2, 1.0, 0.95, 0.25, 1.0)
end

local function update_player()
  if game_over or game_won then
    return
  end

  local forward = 0.0
  local turn = 0.0

  if pressed["w"] or pressed["up"] or gp_pressed["dpad_up"] then
    forward = forward + 1.0
  end
  if pressed["s"] or pressed["down"] or gp_pressed["dpad_down"] then
    forward = forward - 1.0
  end
  if pressed["left"] then
    turn = turn + 1.0
  end
  if pressed["right"] then
    turn = turn - 1.0
  end

  turn = turn + gp_rx
  forward = forward - gp_ly

  player_dir = player_dir + turn * TURN_SPEED

  local dir_x = math.cos(player_dir)
  local dir_y = math.sin(player_dir)
  local move_x = dir_x * forward * MOVE_SPEED
  local move_y = dir_y * forward * MOVE_SPEED
  try_move(player_x + move_x, player_y + move_y)
end

local function reset_match()
  parse_map()
  build_ghosts()

  score = 0
  lives = 3
  frame = 0
  game_over = false
  game_won = false
  invuln_timer = 0
  power_timer = 0
  power_chain = 0
  damage_flash = 0

  fruit.active = false
  fruit.kind = "cherry"
  fruit.timer = 0
  fruit.spawned_70 = false
  fruit.spawned_30 = false
end

parse_map()
build_ghosts()

function key(name, is_pressed)
  if (name == "space" or name == "enter") and is_pressed then
    if game_over or game_won then
      reset_match()
    end
  end

  pressed[name] = is_pressed
end

function gamepad_button(name, is_pressed)
  if (name == "a" or name == "x" or name == "rb") and is_pressed then
    if game_over or game_won then
      reset_match()
    end
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

  if power_timer > 0 then
    power_timer = power_timer - 1
    if power_timer <= 0 then
      power_chain = 0
    end
  end
  if invuln_timer > 0 then
    invuln_timer = invuln_timer - 1
  end
  if damage_flash > 0 then
    damage_flash = damage_flash - 1
  end
  if fruit.active then
    fruit.timer = fruit.timer - 1
    if fruit.timer <= 0 then
      fruit.active = false
    end
  end

  update_player()
  collect_items()
  update_ghosts()
  maybe_spawn_fruit()

  rectc(0, 0, SCREEN_W, SCREEN_H * 0.5, 0.02, 0.02, 0.05, 1.0)
  rectc(0, SCREEN_H * 0.5, SCREEN_W, SCREEN_H * 0.5, 0.01, 0.01, 0.02, 1.0)

  cast_and_draw_columns()
  draw_pellets()
  draw_fruit()
  draw_ghosts()
  draw_top_map()
  draw_hud()
end
