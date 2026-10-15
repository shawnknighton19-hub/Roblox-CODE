--!nonstrict
-- HAB_PLAY_POLISH_8: bounded, swept melee geometry. No client target is trusted.
local R={}
local V=Vector3.new
function R.Finite(v)
 return typeof(v)=='Vector3' and v.X==v.X and v.Y==v.Y and v.Z==v.Z and v.Magnitude<1000000
end
function R.Flat(v) return V(v.X,0,v.Z) end
function R.Direction(v,fallback)
 if not R.Finite(v) then return fallback or V(0,0,-1) end
 local f=R.Flat(v)
 return f.Magnitude>.001 and f.Unit or fallback or V(0,0,-1)
end
function R.SegmentDistance(point,a,b)
 local d=b-a
 local t=d:Dot(d)>1e-8 and math.clamp((point-a):Dot(d)/d:Dot(d),0,1) or 0
 return (point-(a+d*t)).Magnitude,t
end
function R.Turn(from,to,maxAngle)
 from=R.Direction(from);to=R.Direction(to,from)
 local angle=math.atan2(from:Cross(to).Y,math.clamp(from:Dot(to),-1,1))
 local n=math.clamp(angle,-maxAngle,maxAngle)
 -- Y-axis rotation using the same handedness as Vector3:Cross.
 local c,s=math.cos(n),math.sin(n)
 return V(from.X*c+from.Z*s,0,-from.X*s+from.Z*c)
end
function R.Swing(a,b,direction,settings,radius,halfHeight)
 local d=b-a;local flat=R.Flat(d)
 radius=math.clamp(radius or 1.05,.85,1.25)
 halfHeight=math.clamp(halfHeight or 1.6,1.2,2)
 if math.abs(d.Y)>settings.Vertical+halfHeight then return nil end
 if flat.Magnitude>settings.Range+radius then return nil end
 local forward=flat:Dot(direction)
 -- A body overlapping the shoulder can be tagged; a target behind the user cannot.
 if forward<-.15 then return nil end
 local side=math.sqrt(math.max(0,flat:Dot(flat)-forward*forward))
 local angle=math.rad(settings.HalfAngle)
 if side>math.max(.2,forward)*math.tan(angle)+radius then return nil end
 return flat.Magnitude+side*.12
end
function R.Swept(a0,a1,b0,b1,d0,d1,settings,radius,height)
 local travel=((b1-b0)-(a1-a0)).Magnitude
 local steps=math.clamp(math.ceil(travel/.45),1,16)
 local best
 for i=0,steps do
  local t=i/steps
  local a=a0:Lerp(a1,t);local b=b0:Lerp(b1,t)
  local dir=R.Direction(d0:Lerp(d1,t),d1)
  local score=R.Swing(a,b,dir,settings,radius,height)
  if score and (not best or score<best.Score) then best={Score=score,A=a,B=b,Alpha=t} end
 end
 return best
end
function R.Projectile(origin,velocity,gravity,t)
 return origin+velocity*t+V(0,-.5*gravity*t*t,0)
end
return R

