function love.draw()
  love.graphics.print("Yo World!", 400, 300)
end


function love.update()
  -- DEBUG CODE
  require("lurker").update()
end
