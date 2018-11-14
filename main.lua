local sti = require "sti"
local bump = require "bump"
local bump_debug = require "bump_debug"

make_sprite = function(x)
  return love.graphics.newQuad(x*32, 0, 32, 32, sprites:getWidth(), sprites:getHeight())
end

draw_sprite = function(q, x, y)
  love.graphics.draw(sprites, q, x, y)
end

load_level = function(path)
  level_gfx = sti(path, {"bump"})
  level_collision = bump.newWorld(32 * 2)
  player.x = 90
  player.y = 0
  player.vely = 0
  -- todo: setup player collision box
  level_collision:add(player, player.x, player.y, 32, 32)
  level_gfx:bump_init(level_collision)
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
  if key == "tab" and down then
    debug_draw = not debug_draw
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
  else
    jump_timer = JUMP_TIME + 1
  end

  player.x, player.y, _, ground_collision_count = level_collision:move(player, player.x, player.y + player.vely*dt)
  local is_on_ground = ground_collision_count > 0 and player.vely >= 0
  if ground_collision_count > 0 then
    player.vely = 0
    jump_timer = JUMP_TIME + 1
  end
  if is_on_ground then
    jump_timer = 0
  end
  player.x, player.y = level_collision:move(player, player.x + movement_hor, player.y)

  -- this if stops the infinite-jump when holding down the jump button
  if input_jump and jump_timer > JUMP_TIME then
    input_jump = false
  end
end

--------------------------------------------------------------

-- gameplay tweaks
PLAYER_SPEED = 100
GRAVITY = 600
JUMP_SPEED = 200
JUMP_TIME = 0.5

LIGHT_BG = {r= 196, g= 208, b= 162}
DEFAULT_BG = {r= 131, g= 142, b= 102}

love.graphics.setDefaultFilter("nearest", "nearest")
sprites = love.graphics.newImage("sprites.png")
idle_sprite = make_sprite(0)

debug_draw = false
input_left = false
input_right = false

jump_timer = 0
--------------------------------------------------------------

love.load = function()
  player = {x=0, y=0, vely=0}
  load_level("level1.lua")
end

love.draw = function()
  local set_background = function(c)
    local max = 255
    love.graphics.setBackgroundColor(c.r/max, c.g/max, c.b/max)
  end
  set_background(DEFAULT_BG)
  if debug_draw then
    bump_debug.draw(level_collision)
  end
  level_gfx:draw()
  draw_sprite(idle_sprite, player.x, player.y)
end

love.update = function(dt)
  -- DEBUG CODE
  player_update(dt)
  require("lurker").update()
end

love.keypressed = function(key)
  onkey(key, true)
end

love.keyreleased = function(key)
  onkey(key, false)
end
print("eof")
