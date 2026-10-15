--!strict
-- Pure layout shared by the match HUD and action controls. Pixels are safe-area pixels.
local Layout={}
local function box(x:number,y:number,w:number,h:number)
 return {x=math.floor(x),y=math.floor(y),w=math.floor(w),h=math.floor(h)}
end
function Layout.Measure(width:number,height:number,touch:boolean?,actionCount:number?)
 local w=math.max(240,width);local h=math.max(240,height)
 local count=math.clamp(math.floor(actionCount or 3),1,3)
 local narrow=w<600
 -- Touch controls reserve the bottom corners for Roblox's thumbstick and dodge button.
 local bottom=touch and math.min(132,math.max(68,h*.19)) or 18
 local actionH=h<300 and 48 or 58
 local total=math.min(w-28,count*156+(count-1)*10)
 local actionY=h-bottom-actionH
 local weaveW=math.min(260,w-32)
 local short=h<400 and w>=500
 local statusW=math.min(330,short and (w-40)/2 or w-28)
 local dockW=narrow and 156 or 188
 local dockH=244
 local dockY=math.max(132,math.min(h-dockH-112,(h-dockH)/2))
 if h<450 then dockH=math.max(70,h-214);dockY=94 end
 return {
  status=box(short and 12 or (w-statusW)/2,10,statusW,short and 52 or 60),
  fuse=box(short and w-statusW-12 or (w-statusW)/2,short and 10 or 80,statusW,short and 52 or 62),
  actions=box((w-total)/2,actionY,total,actionH),
  weave=box((w-weaveW)/2,actionY-54,weaveW,44),
  dock=box(12,dockY,dockW,dockH),
 }
end
return Layout
