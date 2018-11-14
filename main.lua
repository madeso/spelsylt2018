love.graphics.setDefaultFilter("nearest", "nearest")
sprites = love.graphics.newImage("sprites.png")

make_sprite = function(x)
  return love.graphics.newQuad(x*32, 0, 32, 32, sprites:getWidth(), sprites:getHeight())
end

draw_sprite = function(q, x, y)
  love.graphics.draw(sprites, q, x, y)
end

idle_sprite = make_sprite(0)

love.load = function()
end

LIGHT_BG = {r= 196, g= 208, b= 162}
DEFAULT_BG = {r= 131, g= 142, b= 102}

love.draw = function()
  -- love.graphics.print("Yo World!", 400, 300)
  local set_background = function(c)
    local max = 255
    love.graphics.setBackgroundColor(c.r/max, c.g/max, c.b/max)
  end
  set_background(DEFAULT_BG)
  draw_sprite(idle_sprite, 20, 20)
end

love.update = function()
  -- DEBUG CODE
  require("lurker").update()
end
