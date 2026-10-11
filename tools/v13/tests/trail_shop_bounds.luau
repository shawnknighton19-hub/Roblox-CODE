function instanceMethods:GetBoundingBox()
 local low,high=Vector3.new(math.huge,math.huge,math.huge),Vector3.new(-math.huge,-math.huge,-math.huge)
 local found=false
 for _,part in ipairs(self:GetDescendants()) do if part:IsA('BasePart') then
  found=true
  for x=-1,1,2 do for y=-1,1,2 do for z=-1,1,2 do
   local p=part.CFrame:PointToWorldSpace(Vector3.new(part.Size.X*x,part.Size.Y*y,part.Size.Z*z)*.5)
   low=Vector3.new(math.min(low.X,p.X),math.min(low.Y,p.Y),math.min(low.Z,p.Z))
   high=Vector3.new(math.max(high.X,p.X),math.max(high.Y,p.Y),math.max(high.Z,p.Z))
  end end end
 end end
 if not found then return CFrame.new(),Vector3.one end
 return CFrame.new((low+high)*.5),high-low
end
