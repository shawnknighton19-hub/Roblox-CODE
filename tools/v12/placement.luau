-- Staged V11 lobby clearance: all fifteen arenas at their actual runtime positions.
local World={}
local V=Vector3.new
local function bounds(model,delta,out)
 out=out or {MinX=math.huge,MaxX=-math.huge,MinZ=math.huge,MaxZ=-math.huge}
 for _,p in ipairs(model:GetDescendants()) do if p:IsA('BasePart') then
  local c,h=p.CFrame,p.Size*.5
  local r,u,l=c.RightVector,c.UpVector,c.LookVector
  local x=math.abs(r.X)*h.X+math.abs(u.X)*h.Y+math.abs(l.X)*h.Z
  local z=math.abs(r.Z)*h.X+math.abs(u.Z)*h.Y+math.abs(l.Z)*h.Z
  local q=p.Position+delta
  out.MinX=math.min(out.MinX,q.X-x);out.MaxX=math.max(out.MaxX,q.X+x)
  out.MinZ=math.min(out.MinZ,q.Z-z);out.MaxZ=math.max(out.MaxZ,q.Z+z)
 end end
 assert(out.MinX<math.huge,'Missing world geometry. Nothing changed.')
 return out
end
local function clear(a,b,gap)
 return a.MaxX<=b.MinX-gap or a.MinX>=b.MaxX+gap or a.MaxZ<=b.MinZ-gap or a.MinZ>=b.MaxZ+gap
end
function World.Plan(lobby,library,maps,anchor)
 assert(lobby and lobby:IsA('Model') and library and maps and anchor and anchor:IsA('BasePart'),'Lobby or map containers missing. Nothing changed.')
 local spawn=lobby:FindFirstChild('LobbySpawn')
 assert(spawn and spawn:IsA('SpawnLocation'),'LobbySpawn is missing. Nothing changed.')
 local arena,count=nil,0
 for _,model in ipairs(library:GetChildren()) do if model:IsA('Model') then
  local floor=model:FindFirstChild('Floor',true) or model.PrimaryPart
  assert(floor and floor:IsA('BasePart'),'Map floor missing: '..model.Name)
  -- Match MapService and map voting: floor-top translation, no anchor rotation.
  local top=floor.Position+V(0,floor.Size.Y/2,0)
  arena=bounds(model,anchor.Position-top,arena);count+=1
 end end
 assert(count>0,'MapLibrary is empty. Nothing changed.')
 if #maps:GetDescendants()>0 then arena=bounds(maps,Vector3.zero,arena) end
 local box=bounds(lobby,Vector3.zero)
 local delta,gap=Vector3.zero,96
 if not clear(box,arena,gap-.01) then
  local options={V(arena.MinX-gap-.05-box.MaxX,0,0),V(arena.MaxX+gap+.05-box.MinX,0,0),V(0,0,arena.MinZ-gap-.05-box.MaxZ),V(0,0,arena.MaxZ+gap+.05-box.MinZ)}
  delta=options[1]
  for _,offset in ipairs(options) do if offset.Magnitude<delta.Magnitude then delta=offset end end
 end
 return {Lobby=lobby,Spawn=spawn,OldParent=lobby.Parent,OldSpawnPosition=spawn.Position,OldPivot=lobby:GetPivot(),NewPivot=lobby:GetPivot()+delta,Delta=delta,ArenaBounds=arena,Gap=gap,TemplateCount=count}
end
function World.Apply(plan)
 assert(plan.Lobby.Parent==plan.OldParent and plan.Lobby:FindFirstChild('LobbySpawn')==plan.Spawn,'Lobby changed during installation.')
 if plan.Delta.Magnitude>0 then plan.Lobby:PivotTo(plan.NewPivot) end
 assert((plan.Spawn.Position-plan.OldSpawnPosition-plan.Delta).Magnitude<.02,'Lobby spawn alignment failed.')
 assert(clear(bounds(plan.Lobby,Vector3.zero),plan.ArenaBounds,plan.Gap-.01),'Lobby clearance failed.')
end
return World
