local sti = require "sti"
local bump = require "bump"
local bump_debug = require "bump_debug"
local lume = require "lume"
require "perlin"
perlin:load()

--------------------------------------------------------------
-- Setup:

love.graphics.setDefaultFilter("nearest", "nearest")
local sprites = love.graphics.newImage("sprites.png")
local debug_font = love.graphics.newFont(12)
local big_font = love.graphics.newFont("Kenney Pixel.ttf", 950)
local pause_font = love.graphics.newFont("Boxy-Bold.ttf", 100)

--------------------------------------------------------------
-- Tweaks:

local LONG_STACHE_FIND = 9
local SHORT_STACHE_FIND = 5
local PLAYER_SPEED = 200
local GRAVITY = 1300
local JUMP_SPEED = 250
local JUMP_TIME = 0.4
local ON_GROUND_REACTION = 0.1
local GROUND_FRICTION = 3
local AIR_CONTROL = 0.2
local ACCELERATION = 3
local WALLSLIDE = 50
local WALLSLIDE_SPEED = 1900
local WALLJUMP = 150
local WALLJUMP_ACCELERATION = 0.7

local DASH_TIMEOUT = 1
local DASH_DY = 800
local DASH_DX = 800
local DASH_MIN_VELY = 240

local CAMERA_FOLLOW_X = 8
local CAMERA_FOLLOW_Y = 8
local CAMERA_MAX_DISTANCE_Y = 80
local CAMERA_PLAYER_MAX_VELY = 750
local CAMERA_MAX_TRANSLATION_SHAKE = 120
local CAMERA_SEED_0 = 100
local CAMERA_SEED_1 = 120
local CAMERA_SEED_2 = 220
local CAMERA_SHAKE_FREQUENCY = 5
local CAMERA_TRAUMA_DECREASE = 0.7

-----------------------------------------------------------
-- Colors:

local LIGHT_BG   = {r=196, g=208, b=162}
local DEFAULT_BG = {r=131, g=142, b=102}
local BLACK      = {r=0,   g=0,   b=0  }
local WHITE      = {r=255, g=255, b=255}

-----------------------------------------------------------
-- States:

local STATE_IDLE = 1
local STATE_RUN = 2
local STATE_JUMP = 3
local STATE_WALL = 4

local DASH_NONE = 0
local DASH_HOLD = 1
local DASH_DASH = 2

-----------------------------------------------------------
-- Input:
local debug_draw = false
local input_left = false
local input_right = false
local input_jump = false
local input_dash = false
local game_is_paused = true

----------------------------------------------------------------
-- Gameplay:
local jump_timer = 0
local on_ground_timer = 0
local is_walljumping = false
local camera = {x=0, y=0, trauma=0, time=0}
local start_position = {x=0, y=0}
local has_stache = true
local life = 0

-----------------------------------------------------------
-- Util functions:
local nop = function() end

local perlin_noise = function(x, y)
  if not x then
    print("x is null")
  end
  if not y then
    print("y is null")
  end
  return perlin:noise(x, y, x)
end

local add_trauma = function(val)
  camera.trauma = lume.clamp(camera.trauma + val, 0, 1)
end

local make_sprite = function(x)
  return love.graphics.newQuad(x*32, 0, 32, 32, sprites:getWidth(), sprites:getHeight())
end

local draw_sprite = function(q, x, y, facing_right)
  local scale_x = 1
  local offset_x = 0
  if not facing_right then
    scale_x = -1
    offset_x = 32
  end
  love.graphics.draw(sprites, q, x + offset_x, y, 0, scale_x, 1)
end

local make_animation = function(frames, speed)
  local anim = {}
  anim.sprites = {}
  for i, f in ipairs(frames) do
    anim.sprites[i] = make_sprite(f)
  end
  anim.time = 0
  anim.speed = speed
  anim.current_frame = 1
  return anim
end

local step_animation = function(anim, dt)
  anim.time = anim.time + dt
  while anim.time > anim.speed do
    anim.time = anim.time - anim.speed
    anim.current_frame = anim.current_frame + 1
    if anim.current_frame > #anim.sprites then
      anim.current_frame = 1
    end
  end
end

local reset_animation = function(anim)
  anim.current_frame = 1
  anim.time = 0
end

local draw_animation = function(anim, x, y, facing_right)
  if not anim then return end
  local sprite = anim.sprites[anim.current_frame]
  draw_sprite(sprite, x, y, facing_right)
end

local plusminus = function(plus, minus)
  if plus then
    if minus then
      return 0, false
    else
      return 1, true
    end
  end
  if minus then
    return -1, true
  end
  return 0, false
end

local set_color = function(c)
  local m = 255
  local a = 1
  if c.a then
    a = c.a / m
  end
  love.graphics.setColor(c.r/m, c.g/m, c.b/m, a)
end

local draw_centered_text = function(t)
  local font = love.graphics.getFont()
  local tw = font:getWidth(t)
  local th = font:getHeight()
  local ww = love.graphics.getWidth()
  local wh = love.graphics.getHeight()
  local x = (ww-tw)/2
  local y = (wh-th)/2
  love.graphics.print(t, x, y)
end

local str = tostring

-------------------------------------------------------
-- Animations:
local anim_idle = make_animation({0}, 1)
local anim_run = make_animation({3, 0, 2, 0}, 0.055)
local anim_jump = make_animation({1}, 1)
local anim_wall = make_animation({5}, 1)

--------------------------------------------------------
-- Game code:

local maxy = 0
local capture_y = true

local draw_debug_text = function()
  local y = 10
  local text = function(t)
    local x = 10
    local f = love.graphics.getFont()
    local h = f:getHeight()
    local w = f:getWidth(t)
    local padding = 3
    set_color(LIGHT_BG)
    love.graphics.rectangle("fill", x-padding, y-padding, w+padding*2, h+padding*2)
    set_color(BLACK)
    love.graphics.print(t, x, y)
    y = y + h + padding*3
  end
  love.graphics.setFont(debug_font)
  text("Y: " .. str(maxy) .. " / " .. str(player.vely))
  text("Jump timer: " .. str(jump_timer))
  text("On ground: " .. str(on_ground_timer))
  text("Hor move: " .. str(player.velx))
  text("Trauma: " .. str(camera.trauma))
end

local load_level = function(path)
  level_gfx = sti(path, {"bump"})
  level_collision = bump.newWorld(32 * 2)
  start_position.x = 90
  start_position.y = 0
  camera.time = 0
  player.x, player.y = start_position.x, start_position.y
  camera.x, camera.y = start_position.x, start_position.y
  player.vely = 0
  player.facing_right = true
  -- todo: setup player collision box
  level_collision:add(player, player.x, player.y, 32, 32)
  level_gfx:bump_init(level_collision)
end

local onkey = function(key, down)
  if key == "left" then
    input_left = down
  end
  if key == "right" then
    input_right = down
  end
  if key == "up" then
    input_jump = down
  end
  if key == "p" and down then
    game_is_paused = not game_is_paused
  end
  if key == "tab" and down then
    debug_draw = not debug_draw
  end
  if key == "x" and down then
    add_trauma(0.3)
  end
  if key == "c" then
    input_dash = down
  end
  if key == "r" and not down then
    camera.time = 0
    player.x = start_position.x
    player.y = start_position.y
    level_collision:update(player, player.x, player.y)
  end
end

local player_update = function(dt)
  local ground_collision_count

  if not has_stache then
    life = life - dt
    if life < 0 then
      has_stache = true
      print("Player died...")
    end
  end

  -- make sure velocity is not nil
  if not player.vely then player.vely = 0 end
  if not player.velx then player.velx = 0 end
  if not player.animation then player.animation = anim_idle end

  step_animation(player.animation, dt)

  if input_dash and on_ground_timer > 0.1 and not player.is_wallsliding then
    if player.vely < DASH_MIN_VELY then
      player.dash_state = DASH_HOLD
      player.dash_timer = 0
      player.vely = 0
      input_dash = false
      input_jump = false
      capture_y = true
      maxy = 0
      jump_timer = JUMP_TIME + 1
    else
      print("Too high vely: " .. str(player.vely))
    end
  end

  if player.dash_state == DASH_NONE then
    player.vely = player.vely + GRAVITY * dt

    if input_jump and jump_timer < JUMP_TIME then
      if not is_walljumping then
        player.vely = -JUMP_SPEED
      else
        player.vely = -WALLJUMP
      end
    end
    -- increase jump timer or set it beyond the max when released, so release+hold wont rejump
    if input_jump then
      jump_timer = jump_timer + dt
      capture_y = true
      maxy = 0
    else
      jump_timer = JUMP_TIME + 1
    end
  elseif player.dash_state == DASH_HOLD then
    player.dash_timer = player.dash_timer + dt
    if player.dash_timer > DASH_TIMEOUT then
      print("dash timeout")
      player.dash_state = DASH_NONE
    end
  elseif player.dash_state == DASH_DASH then
    nop()
  else
    print("Unknown dash state: " .. str(player.dash_state))
    player.dash_state = DASH_NONE
  end

  ----------- vertical movment:
  player.x, player.y, _, ground_collision_count = level_collision:move(player, player.x, player.y + player.vely*dt)
  local is_on_ground = ground_collision_count > 0 and player.vely >= 0
  player.is_on_ground = is_on_ground
  if is_on_ground then
    if player.vely > 100 then
      print("landed: " .. str(player.vely))

      if player.vely > 400 then
        local trauma = 0.3
        if player.vely > 700 then
          trauma = 0.5
          if has_stache then
            has_stache = false
            life = LONG_STACHE_FIND
          end
        end
        if player.vely > 900 then
          trauma = 1.0
          if has_stache then
            has_stache = false
            life = life - SHORT_STACHE_FIND
          end
        end
        add_trauma(trauma)
        print("adding some trauma: " .. str(trauma))
      end
    end
    on_ground_timer = 0
    is_walljumping = false
  else
    on_ground_timer = on_ground_timer + dt
  end
  if capture_y then
    maxy = math.max(maxy, player.vely)
  end
  if is_on_ground then
    capture_y = false
  end
  if ground_collision_count > 0 then
    player.vely = 0
    jump_timer = JUMP_TIME + 1
  end
  -- if we was on the ground recently and we are not pressing the jump button
  if on_ground_timer < ON_GROUND_REACTION and not input_jump then
    jump_timer = 0
  end

  -------------- horizontal movment:
  local input_movement, has_moved_hor = plusminus(input_right, input_left)
  if player.dash_state == DASH_NONE then
    local control = 1
    if has_moved_hor then
      if input_movement > 0 then
        player.facing_right = true
      else
        player.facing_right = false
      end
    end
    if not is_on_ground then
      control = AIR_CONTROL
    end
    if has_moved_hor then
      player.velx = lume.clamp(player.velx + control * ACCELERATION * input_movement * dt, -1, 1)
    else
      -- decrease horizontal movment if no input is hold
      if math.abs(player.velx) > 0 and is_on_ground then
        local change = GROUND_FRICTION * dt
        if math.abs(player.velx) < change then
          player.velx = 0
        else
          if player.velx > 0 then
            player.velx = player.velx - change
          else
            player.velx = player.velx + change
          end
        end
      end
    end

    local hor_collision_count
    player.x, player.y, _, hor_collision_count = level_collision:move(player, player.x + player.velx * PLAYER_SPEED * dt, player.y)
    local touches_wall = hor_collision_count > 0

    if touches_wall then
      player.velx = 0
    end

    local sliding = false
    if has_moved_hor and touches_wall and player.vely > WALLSLIDE then
      player.vely = player.vely - WALLSLIDE_SPEED * dt
      sliding = true
      if player.vely <= WALLSLIDE then
        player.vely = WALLSLIDE
      end
    end

    player.is_wallsliding = sliding
    player.is_walljumping = false

    if player.is_wallsliding and input_jump then
      player.is_wallsliding = false
      player.is_walljumping = true
      jump_timer = 0
      is_on_ground = false
      player.vely = WALLJUMP
      is_walljumping = true
      if input_movement > 0 then
        player.velx = -WALLJUMP_ACCELERATION
      else
        player.velx = WALLJUMP_ACCELERATION
      end
    end

    -- this if stops the infinite-jump when holding down the jump button
    if input_jump and jump_timer > JUMP_TIME then
      input_jump = false
    end
  elseif player.dash_state == DASH_HOLD then
    if has_moved_hor then
      if input_movement > 0 then
        player.facing_right = true
      else
        player.facing_right = false
      end
      player.dash_state = DASH_DASH
    end
  elseif player.dash_state == DASH_DASH then
    local dash_collision_count
    local dash_dx = DASH_DX
    if not player.facing_right then
      dash_dx = -dash_dx
    end
    player.x, player.y, _, dash_collision_count = level_collision:move(player, player.x + dash_dx * dt, player.y + DASH_DY * dt)

    if dash_collision_count > 0 then
      add_trauma(0.7)
      player.dash_state = DASH_NONE
      print("dash done")
    end
  else
    print("invalid dash state " .. str(player.dash_state))
  end
  -- determine player animation
  local set_animation = function(o, anim, anim_state)
    if o.anim_state ~= anim_state then
      o.animation = anim
      o.anim_state = anim_state
      reset_animation(o.animation)
    end
  end
  if is_on_ground then
    if has_moved_hor then
      set_animation(player, anim_run, STATE_RUN)
    else
      set_animation(player, anim_idle, STATE_IDLE)
    end
  else
    if player.is_wallsliding then
      set_animation(player, anim_wall, STATE_WALL)
    else
      set_animation(player, anim_jump, STATE_JUMP)
    end
  end
end

local camera_update = function(dt)
  if not camera.target_x then camera.target_x = camera.x end
  if not camera.target_y then camera.target_y = camera.x end

  local camera_follow_y = CAMERA_FOLLOW_Y

  camera.time = camera.time + dt
  camera.trauma = lume.clamp(camera.trauma - dt * CAMERA_TRAUMA_DECREASE, 0, 1)

  if player.is_on_ground then
    camera.target_y = player.y
  end

  if math.abs(player.vely) > CAMERA_PLAYER_MAX_VELY then
    camera.target_y = player.y
    camera_follow_y = 30
  end

  if player.is_wallsliding and math.abs(camera.target_y - player.y) > CAMERA_MAX_DISTANCE_Y and player.y > camera.target_y then
    print("target: " .. str(camera.target_y))
    print("player: " .. str(player.y))
    camera.target_y = player.y
  end

  if player.is_walljumping then
    camera.target_y = player.y
  end

  camera.target_x = player.x

  camera.x = camera.x + (camera.target_x - camera.x) * lume.clamp(CAMERA_FOLLOW_X * dt, 0, 1)
  camera.y = camera.y + (camera.target_y - camera.y) * lume.clamp(camera_follow_y * dt, 0, 1)
end


--------------------------------------------------------------
-- Love callbacks:

love.load = function()
  player = {x=0, y=0, vely=0, facing_right=true, animation=nil}
  load_level("level1.lua")
end

love.draw = function()
  local set_background = function(c)
    local max = 255
    love.graphics.setBackgroundColor(c.r/max, c.g/max, c.b/max)
  end
  if game_is_paused then
    set_background(LIGHT_BG)
  else
    set_background(DEFAULT_BG)
  end
  set_color(WHITE)
  local zoom = 2
  local window_width, window_height = love.graphics.getWidth(), love.graphics.getHeight()
  local camera_shake = camera.trauma * camera.trauma
  local offset_x = camera_shake * CAMERA_MAX_TRANSLATION_SHAKE * perlin_noise(camera.time * CAMERA_SHAKE_FREQUENCY, CAMERA_SEED_0)
  local offset_y = camera_shake * CAMERA_MAX_TRANSLATION_SHAKE * perlin_noise(camera.time * CAMERA_SHAKE_FREQUENCY, CAMERA_SEED_1)
  local camera_x, camera_y = (offset_x + camera.x) * zoom - window_width / 2, (offset_y + camera.y) * zoom - window_height/2
  local angle = 0.5 * math.pi/2 * camera_shake * perlin_noise(camera.time * CAMERA_SHAKE_FREQUENCY, CAMERA_SEED_2)

  love.graphics.push()
  love.graphics.translate(window_width/2, window_height/2)
  love.graphics.rotate(angle)
  love.graphics.translate(-window_width/2, -window_height/2)
  love.graphics.translate(-camera_x, -camera_y)
  love.graphics.scale(zoom, zoom)
  if debug_draw then
    bump_debug.draw(level_collision)
  end
  -- level_gfx:draw(-camera_x/zoom, -camera_y/zoom, zoom, zoom)
  level_gfx:drawLayer(level_gfx.layers["col"])
  draw_animation(player.animation, player.x, player.y, player.facing_right)
  love.graphics.pop()
  if not has_stache then
    love.graphics.setFont(big_font)
    local alpha = {r=255, g=255, b=255, a=180}
    set_color(alpha)
    -- love.graphics.print(math.ceil(life), 250, -80)
    draw_centered_text(math.ceil(life))
    set_color(WHITE)
  end
  if game_is_paused then
    love.graphics.setFont(pause_font)
    set_color(WHITE)
    -- love.graphics.print("PAUSED", 100, 100)
    draw_centered_text("PAUSED")
  end
  draw_debug_text()
end

love.update = function(dt)
  -- DEBUG CODE
  if not game_is_paused then
    player_update(dt)
    camera_update(dt)
  end
  require("lurker").update()
end

love.keypressed = function(key)
  onkey(key, true)
end

love.keyreleased = function(key)
  onkey(key, false)
end

