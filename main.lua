local sti = require "sti"
local bump = require "bump"
local bump_debug = require "bump_debug"
local lume = require "lume"


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

LIGHT_BG   = {r=196, g=208, b=162}
DEFAULT_BG = {r=131, g=142, b=102}
BLACK      = {r=0,   g=0,   b=0  }
WHITE      = {r=255, g=255, b=255}


-----------------------------------------------------------
-- Util functions:

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
end

load_level = function(path)
  level_gfx = sti(path, {"bump"})
  level_collision = bump.newWorld(32 * 2)
  start_position.x = 90
  start_position.y = 0
  player.x, player.y = start_position.x, start_position.y
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
  if key == "r" and not down then
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
  if is_on_ground then
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

  if sliding and input_jump then
    sliding = false
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
end


---------------------------------------------------------------
-- Startup code:

love.graphics.setDefaultFilter("nearest", "nearest")
sprites = love.graphics.newImage("sprites.png")
idle_sprite = make_sprite(0)

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
  player = {x=0, y=0, vely=0, facing_right=true}
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
  if debug_draw then
    bump_debug.draw(level_collision)
  end
  level_gfx:draw()
  draw_sprite(idle_sprite, player.x, player.y, player.facing_right)
  draw_debug_text()
end

love.update = function(dt)
  -- DEBUG CODE
  if game_is_paused then
  else
    player_update(dt)
  end
  require("lurker").update()
end

love.keypressed = function(key)
  onkey(key, true)
end

love.keyreleased = function(key)
  onkey(key, false)
end

