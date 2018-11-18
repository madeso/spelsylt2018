local sti = require "sti"
local bump = require "bump"
local bump_debug = require "bump_debug"
local lume = require "lume"
require "perlin"
perlin:load()

--------------------------------------------------------------
-- Tweaks:

PLAYER_SPEED = 200
GRAVITY = 1300
JUMP_SPEED = 250
JUMP_TIME = 0.4
ON_GROUND_REACTION = 0.1
GROUND_FRICTION = 3
AIR_CONTROL = 0.2
ACCELERATION = 3
WALLSLIDE = 50
WALLSLIDE_SPEED = 1900
WALLJUMP = 150
WALLJUMP_ACCELERATION = 0.7

CAMERA_FOLLOW_X = 8
CAMERA_FOLLOW_Y = 8
CAMERA_MAX_DISTANCE_Y = 80
CAMERA_PLAYER_MAX_VELY = 750
CAMERA_MAX_TRANSLATION_SHAKE = 120
CAMERA_SEED_0 = 100
CAMERA_SEED_1 = 120
CAMERA_SEED_2 = 220
CAMERA_SHAKE_FREQUENCY = 5
CAMERA_TRAUMA_DECREASE = 0.7

LIGHT_BG   = {r=196, g=208, b=162}
DEFAULT_BG = {r=131, g=142, b=102}
BLACK      = {r=0,   g=0,   b=0  }
WHITE      = {r=255, g=255, b=255}


-----------------------------------------------------------
-- Util functions:

perlin_noise = function(x, y)
  if not x then
    print("x is null")
  end
  if not y then
    print("y is null")
  end
  return perlin:noise(x, y, x)
end

add_trauma = function(val)
  camera.trauma = lume.clamp(camera.trauma + val, 0, 1)
end

make_sprite = function(x)
  return love.graphics.newQuad(x*32, 0, 32, 32, sprites:getWidth(), sprites:getHeight())
end

draw_sprite = function(q, x, y, facing_right)
  local scale_x = 1
  local offset_x = 0
  if not facing_right then
    scale_x = -1
    offset_x = 32
  end
  love.graphics.draw(sprites, q, x + offset_x, y, 0, scale_x, 1)
end

make_animation = function(frames, speed)
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

step_animation = function(anim, dt)
  anim.time = anim.time + dt
  while anim.time > anim.speed do
    anim.time = anim.time - anim.speed
    anim.current_frame = anim.current_frame + 1
    if anim.current_frame > #anim.sprites then
      anim.current_frame = 1
    end
  end
end

reset_animation = function(anim)
  anim.current_frame = 1
  anim.time = 0
end

draw_animation = function(anim, x, y, facing_right)
  if not anim then return end
  local sprite = anim.sprites[anim.current_frame]
  draw_sprite(sprite, x, y, facing_right)
end

plusminus = function(plus, minus)
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

set_color = function(c)
  local m = 255
  local a = 1
  if c.a then
    a = c.a / max
  end
  love.graphics.setColor(c.r/m, c.g/m, c.b/m, a)
end


str = tostring

--------------------------------------------------------
-- Game code:

maxy = 0
capture_y = true

draw_debug_text = function()
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
  text("Y: " .. str(maxy) .. " / " .. str(player.vely))
  text("Jump timer: " .. str(jump_timer))
  text("On ground: " .. str(on_ground_timer))
  text("Hor move: " .. str(player.velx))
  text("Trauma: " .. str(camera.trauma))
end

load_level = function(path)
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

onkey = function(key, down)
  if down then
    print(key .. " was down")
  else
    print(key .. " was released")
  end
  if key == "left" then
    input_left = down
  end
  if key == "right" then
    input_right = down
  end
  if key == "up" then
    input_jump = down
  end
  if key == "space" and down then
    game_is_paused = not game_is_paused
  end
  if key == "tab" and down then
    debug_draw = not debug_draw
  end
  if key == "x" and down then
    add_trauma(0.3)
  end
  if key == "r" and not down then
    camera.time = 0
    player.x = start_position.x
    player.y = start_position.y
    level_collision:update(player, player.x, player.y)
  end
end

player_update = function(dt)
  local ground_collision_count

  -- make sure velocity is not nil
  if not player.vely then player.vely = 0 end
  if not player.velx then player.velx = 0 end
  if not player.animation then player.animation = anim_idle end

  step_animation(player.animation, dt)

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
        end
        if player.vely > 900 then
          trauma = 1.0
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
  if is_on_group then
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
  local control = 1
  if has_moved_hor then
    if input_movement > 0 then
      player.facing_right = true
    else
      player.facing_right = false
    end
  else
    -- print("nop")
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

  if sliding and input_jump then
    sliding = false
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

  -- determine player animation
  local set_animation = function(o, anim, anim_state)
    if o.anim_state ~= anim_state then
      print("switching anim")
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
    if sliding then
      set_animation(player, anim_wall, STATE_WALL)
    else
      set_animation(player, anim_jump, STATE_JUMP)
    end
  end
end

camera_update = function(dt)
  if not camera.target_x then camera.target_x = camera.x end
  if not camera.target_y then camera.target_y = camera.x end

  camera.time = camera.time + dt
  camera.trauma = lume.clamp(camera.trauma - dt * CAMERA_TRAUMA_DECREASE, 0, 1)

  if player.is_on_ground then
    camera.target_y = player.y
  end

  if math.abs(player.vely) > CAMERA_PLAYER_MAX_VELY then
    camera.target_y = player.y
    print("max vely")
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

  camera.x = camera.x + (camera.target_x - camera.x) * CAMERA_FOLLOW_X * dt
  camera.y = camera.y + (camera.target_y - camera.y) * CAMERA_FOLLOW_Y * dt
end

---------------------------------------------------------------
-- Startup code:

love.graphics.setDefaultFilter("nearest", "nearest")
sprites = love.graphics.newImage("sprites.png")
idle_sprite = make_sprite(0)

anim_idle = make_animation({0}, 1)
anim_run = make_animation({3, 0, 2, 0}, 0.055)
anim_jump = make_animation({1}, 1)
anim_wall = make_animation({5}, 1)

camera = {x=0, y=0, trauma=0, time=0}

STATE_IDLE = 1
STATE_RUN = 2
STATE_JUMP = 3
STATE_WALL = 4

debug_draw = false
input_left = false
input_right = false
game_is_paused = false

jump_timer = 0
on_ground_timer = 0
is_walljumping = false
--------------------------------------------------------------
-- Love callbacks:

love.load = function()
  player = {x=0, y=0, vely=0, facing_right=true, animation=nil}
  start_position = {x=0, y=0}
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
  draw_debug_text()
end

love.update = function(dt)
  -- DEBUG CODE
  if game_is_paused then
  else
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

