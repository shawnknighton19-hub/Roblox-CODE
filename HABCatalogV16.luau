local function priorCatalog()

--!nonstrict
-- HAB_HALLOWEEN_CRATES_1. Effect art/names belong to the supplied pack.
local Effects=require(assert(script.Parent:WaitForChild('Effects',15),'Halloween Effects data missing'))
local Settings=require(assert(script.Parent:WaitForChild('Settings',15),'Crate Settings missing'))
local Extra=require(assert(script.Parent:WaitForChild('ExtraFXData',20),'Imported VFX data missing'))
local C={Effects=Effects,Items={},ById={},Order={'Aura','Trail','BombFX','KillFX'},CarrierSprintBonus=3}
C.Crates={
 Aura={Name='Spirit Reliquary',Label='AURAS',Price=250,Color=Color3.fromRGB(168,112,255),Description='An animated presence around your character.'},
 Trail={Name='Reaper Cache',Label='TRAILS',Price=200,Color=Color3.fromRGB(74,225,220),Description='Animated wakes and matching arm effects while moving.'},
 BombFX={Name='Hex Vault',Label='BOMB EFFECTS',Price=250,Color=Color3.fromRGB(255,171,70),Description='A looping effect on your carried bomb. Keeps your bomb skin.'},
 KillFX={Name='Cataclysm Chest',Label='ELIMINATION FX',Price=300,Color=Color3.fromRGB(250,98,145),Description='A burst at a bomb elimination. No extra damage.'},
}
-- Each supplied effect appears in exactly ONE collection, with its original name.
local sets={
 Aura={'JackOLanternSwirl','JackOLanternVortex','PhantomMistVortex','PhantomShroudFold','SpiritSmokeColumn','SpiritRainfall','WraithHelixColumn','SpectralAntlerEnergy','MoonbranchApparition','CursedConstellationSigil','SoulWispVortex','WillOWispVortex','SpectralGalaxyVortex','NecromanticFungalGround'},
 Trail={'JackOLanternWisp','BansheeLashCrescent','SpectralBansheeLash','ReaperCrescentSlash','CursedScytheCross','BloodMistSlash','NeonBatSwarm','SpectralBatSwarm','DarkEmberBatSwarm','MothAshVortex','HexStitchTear','HexStitchLatticeTear','SmokyEmberVortex'},
 BombFX={'JackOLanternBloom','JackOLanternFlare','JackOLanternInferno','InfernalHexagramSigil','CursedHexTendrils','VoidEyeSmoke','DarkEmberVortex','GravePulseNetwork','PoisonCrystalSurge'},
 KillFX={'FieryJackOLantern','JackOLanternBurst','GhostlyVeilDissipation','WraithEruption','GraveLightningWraith','SpectralWingClash','OccultEclipseSigilExplosion','OccultEclipseImplosion','NeonSpiderwebRupture','SoulOrbitNova','VoidThornNova','HellfireEruption','BloodRedRingExplosion','PoisonCrystalBurst'},
}
local present={}
for _,category in ipairs(C.Order) do
 local crate=C.Crates[category];crate.Items={}
 crate.Price=assert(Settings.CratePrices[category],'Gem price missing');crate.Currency='Gems'
 for _,name in ipairs(sets[category]) do
  assert(Effects[name] and not present[name],'Missing/duplicate imported effect: '..name)
  present[name]=true
  local effect=Effects[name]
  local item={Id=name,Name=effect.label,Category=category,Theme=effect.theme,Type=effect.type,Color=effect.glow}
  C.ById[name]=item;table.insert(C.Items,item);table.insert(crate.Items,name)
 end
 table.sort(crate.Items,function(a,b) return C.ById[a].Name<C.ById[b].Name end)
end
local count=0;for name in pairs(Effects) do count=count+1;assert(present[name],'Unassigned effect: '..name) end
assert(count==50 and #C.Items==50,'Expected all 50 effects')
C.Crates.DodgeFX={Name='Weaver Cache',Label='DODGE EFFECTS',Price=Settings.CratePrices.DodgeFX or 45,Currency='Gems',
 Color=Color3.fromRGB(113,194,255),Description='An equipped pack burst when you dodge. Cosmetic only.',Items={}}
C.Order[#C.Order+1]='DodgeFX'
local assignments={
 ["combat_00001"]="DodgeFX",
 ["combat_00011"]="DodgeFX",
 ["combat_00036"]="DodgeFX",
 ["combat_00058"]="DodgeFX",
 ["combat_00078"]="DodgeFX",
 ["combat_00094"]="DodgeFX",
 ["combat_00107"]="DodgeFX",
 ["combat_00125"]="DodgeFX",
 ["combat_00162"]="DodgeFX",
 ["combat_00172"]="DodgeFX",
 ["combat_00192"]="DodgeFX",
 ["combat_00218"]="DodgeFX",
 ["combat_00248"]="DodgeFX",
 ["combat_00258"]="DodgeFX",
 ["combat_00269"]="DodgeFX",
 ["combat_00274"]="DodgeFX",
 ["combat_00295"]="DodgeFX",
 ["combat_00310"]="DodgeFX",
 ["combat_00327"]="DodgeFX",
 ["combat_00354"]="DodgeFX",
 ["combat_00372"]="DodgeFX",
 ["combat_00382"]="DodgeFX",
 ["combat_00392"]="DodgeFX",
 ["combat_00399"]="DodgeFX",
 ["combat_00406"]="DodgeFX",
 ["combat_00413"]="DodgeFX",
 ["combat_00455"]="DodgeFX",
 ["combat_00477"]="DodgeFX",
 ["combat_00504"]="DodgeFX",
 ["combat_00568"]="DodgeFX",
 ["combat_00596"]="DodgeFX",
 ["combat_00782"]="DodgeFX",
 ["combat_00807"]="DodgeFX",
 ["combat_00817"]="DodgeFX",
 ["combat_00948"]="DodgeFX",
 ["combat_00992"]="DodgeFX",
 ["combat_01020"]="DodgeFX",
 ["combat_01048"]="DodgeFX",
 ["combat_01260"]="DodgeFX",
 ["combat_01353"]="DodgeFX",
 ["combat_01430"]="DodgeFX",
 ["combat_01447"]="DodgeFX",
 ["combat_01472"]="DodgeFX",
 ["combat_01482"]="DodgeFX",
 ["combat_01492"]="DodgeFX",
 ["combat_01505"]="DodgeFX",
 ["combat_01524"]="DodgeFX",
 ["combat_01549"]="DodgeFX",
 ["combat_01654"]="DodgeFX",
 ["ability_01936"]="BombFX",
 ["ability_00469"]="DodgeFX",
 ["ability_00482"]="KillFX",
 ["ability_00505"]="Aura",
 ["ability_00562"]="Aura",
 ["ability_00656"]="Aura",
 ["ability_00709"]="Aura",
 ["ability_00754"]="Aura",
 ["ability_00833"]="Aura",
 ["ability_00898"]="Aura",
 ["ability_00939"]="Aura",
 ["ability_01026"]="Aura",
 ["ability_01053"]="Aura",
 ["ability_01096"]="Aura",
 ["ability_01126"]="Aura",
 ["ability_01152"]="Aura",
 ["ability_01181"]="Aura",
 ["ability_01234"]="Aura",
 ["ability_01321"]="Aura",
 ["ability_01348"]="Aura",
 ["ability_01387"]="Aura",
 ["ability_01448"]="Aura",
 ["ability_01478"]="Aura",
 ["ability_01532"]="Aura",
 ["ability_01611"]="Aura",
 ["ability_01656"]="Aura",
 ["ability_01724"]="Aura",
 ["ability_01788"]="Aura",
 ["ability_01807"]="Aura",
 ["ability_01867"]="Aura",
 ["ability_00406"]="KillFX",
 ["ability_12380"]="Trail",
 ["ability_13107"]="BombFX",
 ["ability_13155"]="BombFX",
 ["ability_15213"]="BombFX",
 ["ability_17372"]="DodgeFX",
 ["ability_00009"]="KillFX",
 ["ability_00175"]="KillFX",
 ["ability_00195"]="KillFX",
 ["ability_00367"]="KillFX",
 ["ability_01985"]="KillFX",
 ["ability_02101"]="DodgeFX",
 ["ability_02119"]="KillFX",
 ["ability_12332"]="KillFX",
 ["ability_12383"]="DodgeFX",
 ["ability_12406"]="DodgeFX",
 ["ability_12460"]="DodgeFX",
 ["ability_12478"]="Trail",
 ["ability_12497"]="Aura",
 ["ability_12516"]="KillFX",
 ["ability_12568"]="DodgeFX",
 ["ability_12622"]="BombFX",
 ["ability_12640"]="KillFX",
 ["ability_12703"]="KillFX",
 ["ability_12855"]="KillFX",
 ["ability_13002"]="DodgeFX",
 ["ability_13062"]="Trail",
 ["ability_13083"]="DodgeFX",
 ["ability_13110"]="Trail",
 ["ability_13131"]="KillFX",
 ["ability_13158"]="DodgeFX",
 ["ability_13178"]="BombFX",
 ["ability_13228"]="DodgeFX",
 ["ability_13336"]="DodgeFX",
 ["ability_13482"]="Trail",
 ["ability_13643"]="KillFX",
 ["ability_13816"]="DodgeFX",
 ["ability_13861"]="DodgeFX",
 ["ability_13872"]="BombFX",
 ["ability_13911"]="DodgeFX",
 ["ability_14080"]="KillFX",
 ["ability_14125"]="KillFX",
 ["ability_14178"]="BombFX",
 ["ability_14231"]="DodgeFX",
 ["ability_14389"]="DodgeFX",
 ["ability_14547"]="DodgeFX",
 ["ability_14718"]="KillFX",
 ["ability_14893"]="KillFX",
 ["ability_15065"]="KillFX",
 ["ability_15090"]="KillFX",
 ["ability_15143"]="DodgeFX",
 ["ability_15170"]="BombFX",
 ["ability_15216"]="DodgeFX",
 ["ability_15376"]="DodgeFX",
 ["ability_15383"]="KillFX",
 ["ability_15555"]="BombFX",
 ["ability_15593"]="KillFX",
 ["ability_15644"]="KillFX",
 ["ability_16786"]="DodgeFX",
 ["ability_16808"]="KillFX",
 ["ability_16840"]="KillFX",
 ["ability_16995"]="DodgeFX",
 ["ability_17153"]="DodgeFX",
 ["ability_17175"]="BombFX",
 ["ability_17294"]="KillFX",
 ["ability_17334"]="DodgeFX",
 ["ability_17404"]="KillFX",
 ["ability_17463"]="KillFX",
 ["ability_00005"]="DodgeFX",
 ["ability_00331"]="KillFX",
 ["ability_00394"]="BombFX",
 ["ability_00495"]="DodgeFX",
 ["ability_01948"]="Trail",
 ["ability_01971"]="BombFX",
 ["ability_12371"]="KillFX",
 ["ability_12488"]="BombFX",
 ["ability_12692"]="DodgeFX",
 ["ability_12997"]="DodgeFX",
 ["ability_13009"]="DodgeFX",
 ["ability_13017"]="DodgeFX",
 ["ability_13026"]="Aura",
 ["ability_13035"]="Aura",
 ["ability_13044"]="Aura",
 ["ability_13051"]="Aura",
 ["ability_13089"]="BombFX",
 ["ability_13095"]="BombFX",
 ["ability_13101"]="BombFX",
 ["ability_13662"]="DodgeFX",
 ["ability_13676"]="KillFX",
 ["ability_13686"]="Aura",
 ["ability_13695"]="KillFX",
 ["ability_13715"]="Aura",
 ["ability_13734"]="KillFX",
 ["ability_13745"]="Aura",
 ["ability_13762"]="Aura",
 ["ability_13778"]="Aura",
 ["ability_13788"]="Aura",
 ["ability_13798"]="Aura",
 ["ability_13807"]="Aura",
 ["ability_13832"]="Trail",
 ["ability_14069"]="Trail",
 ["ability_14706"]="DodgeFX",
 ["ability_14709"]="KillFX",
 ["ability_15128"]="KillFX",
 ["ability_16832"]="DodgeFX",
 ["ability_17289"]="DodgeFX",
 ["ability_17317"]="DodgeFX",
 ["ability_17331"]="KillFX",
 ["ability_17378"]="DodgeFX",
 ["ability_17498"]="BombFX",
 ["ability_17528"]="BombFX",
 ["ability_17538"]="Aura",
 ["ability_15374"]="Trail",
}
for id,t in pairs(Extra.Templates) do
 local category=assert(assignments[id],'Unassigned native pack effect: '..id)
 assert(not C.ById[id],'Duplicate cosmetic ID')
 local color=Color3.new(table.unpack(t.Color))
 if color.R+color.G+color.B<.65 then color=color:Lerp(Color3.fromRGB(190,217,255),.6) end
 local display=t.Name:gsub('Ability Study','Impact')
 local item={Id=id,Name=display,Category=category,Theme=t.Pack,Type='Pack particles',Color=color,Native=true}
 C.ById[id]=item;C.Items[#C.Items+1]=item;table.insert(C.Crates[category].Items,id)
end
for _,category in ipairs(C.Order) do
 table.sort(C.Crates[category].Items,function(a,b)
  if C.ById[a].Name==C.ById[b].Name then return a<b end
  return C.ById[a].Name<C.ById[b].Name
 end)
end
C.PreviewItems={};C.PreviewById={} -- old extension compatibility; no preview-only store.
function C.Get(id) return C.ById[id] end
function C.Lifetime(id)
 local item=C.ById[id];id=item and item.SourceId or id
 local t=Extra.Templates[id]
 return t and t.Duration or Effects[id] and Effects[id].lifetime or 1
end
assert(#C.Items==242,'Pack catalog must contain 242 presets')
-- HAB_CRATE_GUI_4
-- HAB_COLLECTIONS_6_NAMES
require(script.Parent.HABEffectNames).Apply(C)

local Expansion=require(script.Parent.Parent.HABExpansion.Config)
local function exclusive(id,name,slot,source,tint,offer)
 local original=assert(C.ById[source],'Missing original VFX '..tostring(source))
 assert(not C.ById[id],'Duplicate exclusive effect')
 local item={Id=id,Name=name,Category=slot,Theme=offer..' exclusive edition',Type='Guaranteed bundle cosmetic',Color=tint,
  Native=original.Native,SourceId=source,Exclusive=true,Offer=offer,Tint=tint}
 C.ById[id]=item;C.Items[#C.Items+1]=item
end
for _,bundle in ipairs(Expansion.Bundles) do
 for _,fx in ipairs(bundle.Items) do exclusive(fx.Id,fx.Name,fx.Slot,fx.Source,bundle.Color,bundle.Key) end
end
exclusive(Expansion.VIP.Effect,'Spotlight Constellation','Aura',Expansion.VIP.Source,Color3.fromRGB(255,219,103),'VIP')

return C
-- HAB_EXPANSION_7

end
local C=priorCatalog()
local Sounds=require(script.Parent.HABKillSounds)
local keep={}
for _,item in ipairs(C.Items) do
 if item.Category=='KillFX' and not Sounds.ById[item.Id] then item.RetiredFinisher=true;item.Hidden=true
 else keep[#keep+1]=item end
end
C.Items=keep
local crate=C.Crates.KillFX
crate.Name='Kill Sound Chest';crate.Label='KILL SOUNDS';crate.Description='A short sound at your last-giver bomb elimination. No finisher VFX.';crate.Items={}
for _,def in ipairs(Sounds.Items) do
 local old=C.ById[def.Id]
 if old then
  for i=#C.Items,1,-1 do if C.Items[i].Id==def.Id then table.remove(C.Items,i) end end
 end
 local item={Id=def.Id,Name=def.Name,Category='KillFX',Theme='Kill sound',Type='KillSound',Color=def.Color,
  Exclusive=def.Exclusive,Offer=old and old.Offer,Description='Preview the sound, then equip it. Short and spatial; respects sound volume.'}
 C.ById[def.Id]=item;C.Items[#C.Items+1]=item
 if not def.Exclusive then crate.Items[#crate.Items+1]=def.Id end
end
local lifetime=C.Lifetime
function C.Lifetime(id) if Sounds.ById[id] then return Sounds.ById[id].Duration end;return lifetime(id) end
C.Version=9
-- V16: remove visual collections from shopping without deleting any saved IDs.
C.DisabledVisualCategories={BombFX=true,DodgeFX=true}
local visibleOrder={}
for _,category in ipairs(C.Order) do if not C.DisabledVisualCategories[category] then visibleOrder[#visibleOrder+1]=category end end
C.Order=visibleOrder
return C

-- HAB_FUN_9