local sti = require "sti"
local bump = require "bump"
local bump_debug = require "bump_debug"


--------------------------------------------------------------
-- Tweaks:

PLAYER_SPEED = 100
GRAVITY = 600
JUMP_SPEED = 200
JUMP_TIME = 0.5
ON_GROUND_REACTION = 0.1

LIGHT_BG   = {r=196, g=208, b=162}
DEFAULT_BG = {r=131, g=142, b=102}
BLACK      = {r=0,   g=0,   b=0  }
WHITE      = {r=255, g=255, b=255}


-----------------------------------------------------------
-- Util functions:

make_sprite = function(x)
  return love.graphics.newQuad(x*32, 0, 32, 32, sprites:getWidth(), sprites:getHeight())
end

draw_sprite = function(q, x, y)
  love.graphics.draw(sprites, q, x, y)
end

plusminus = function(plus, minus)
  if plus then
    if minus then
      return 0
    else
      return 1
    end
  end
  if minus then
    return -1
  end
  return 0
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
end

load_level = function(path)
  level_gfx = sti(path, {"bump"})
  level_collision = bump.newWorld(32 * 2)
  start_position.x = 90
  start_position.y = 0
  player.x, player.y = start_position.x, start_position.y
  player.vely = 0
  -- todo: setup player collision box
  level_collision:add(player, player.x, player.y, 32, 32)
  level_gfx:bump_init(level_collision)
end

onkey = function(key, down)
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
  local input_movement = plusminus(input_right, input_left)
  local movement_hor = input_movement * dt * PLAYER_SPEED
  local ground_collision_count
  if not player.vely then player.vely = 0 end
  player.vely = player.vely + GRAVITY * dt

  if input_jump and jump_timer < JUMP_TIME then
    player.vely = -JUMP_SPEED
  end
  -- increase jump timer or set it beyond the max when released, so release+hold wont rejump
  if input_jump then
    jump_timer = jump_timer + dt
    capture_y = true
    maxy = 0
  else
    jump_timer = JUMP_TIME + 1
  end

  player.x, player.y, _, ground_collision_count = level_collision:move(player, player.x, player.y + player.vely*dt)
  local is_on_ground = ground_collision_count > 0 and player.vely >= 0
  if is_on_ground then
    on_ground_timer = 0
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
  player.x, player.y = level_collision:move(player, player.x + movement_hor, player.y)

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

--------------------------------------------------------------
-- Love callbacks:

love.load = function()
  player = {x=0, y=0, vely=0}
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
  draw_sprite(idle_sprite, player.x, player.y)
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

