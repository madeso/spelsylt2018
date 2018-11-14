local sti = require "sti"

make_sprite = function(x)
  return love.graphics.newQuad(x*32, 0, 32, 32, sprites:getWidth(), sprites:getHeight())
end

draw_sprite = function(q, x, y)
  love.graphics.draw(sprites, q, x, y)
end

load_level = function(path)
  level_gfx = sti(path)
  player.x = 90
  player.y = 0
end

--------------------------------------------------------------

LIGHT_BG = {r= 196, g= 208, b= 162}
DEFAULT_BG = {r= 131, g= 142, b= 102}

love.graphics.setDefaultFilter("nearest", "nearest")
sprites = love.graphics.newImage("sprites.png")
idle_sprite = make_sprite(0)
player = {x=0, y=0}
load_level("level1.lua")
--------------------------------------------------------------

love.load = function()
end

love.draw = function()
  local set_background = function(c)
    local max = 255
    love.graphics.setBackgroundColor(c.r/max, c.g/max, c.b/max)
  end
  set_background(DEFAULT_BG)
  level_gfx:draw()
  draw_sprite(idle_sprite, player.x, player.y)
end

love.update = function()
  -- DEBUG CODE
  require("lurker").update()
end
