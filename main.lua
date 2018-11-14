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
  print("a")
  level_gfx = sti(path, {"bump"})
  print("b")
  level_collision = bump.newWorld(32 * 2)
  player.x = 90
  player.y = 0
  -- todo: setup player collision box
  print("knas")
  level_collision:add(player, player.x, player.y, 32, 32)
  print("dog")
  level_gfx:bump_init(level_collision)
  print("cat")
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
  if key == "tab" and down then
    debug_draw = not debug_draw
  end
end

player_update = function(dt)
  local input_movement = plusminus(input_right, input_left)
  local movement_hor = input_movement * dt * PLAYER_SPEED
  player.x, player.y = level_collision:move(player, player.x + movement_hor, player.y)
end

--------------------------------------------------------------

-- gameplay tweaks
PLAYER_SPEED = 32

LIGHT_BG = {r= 196, g= 208, b= 162}
DEFAULT_BG = {r= 131, g= 142, b= 102}

love.graphics.setDefaultFilter("nearest", "nearest")
sprites = love.graphics.newImage("sprites.png")
idle_sprite = make_sprite(0)
player = {x=0, y=0}
load_level("level1.lua")

debug_draw = false
input_left = false
input_right = false
--------------------------------------------------------------

love.load = function()
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
