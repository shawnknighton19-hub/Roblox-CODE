local PASS_IDS={["Confetti"]=0,["Disco"]=0,["FastOpen"]=0,["Throw"]=0,["VIP"]=0,}
local BUNDLE_PASS_IDS={["Cyber"]=0,["Glacier"]=0,["Phantom"]=0,["Solar"]=0,}
local KILL_AUDIO_IDS={}
local function priorConfig()
local function priorConfig()
--!nonstrict
-- HAB EXPANSION 7. Configure ONLY your own experience's asset IDs.
local C = {}
C.Version = 7
C.Passes = {
 {Key='FastOpen', Name='Fast Open', Id=0, SuggestedRobux=79,
  Description='Skip the crate reveal animation. Odds and rewards never change.', Color=Color3.fromRGB(255,203,70)},
 {Key='Throw', Name='Bomb Pitcher', Id=0, SuggestedRobux=249,
  Description='Throw your carried bomb with R. Aim required; 12s cooldown. A miss keeps the bomb on you.',Color=Color3.fromRGB(255,111,82)},
 {Key='VIP', Name='Spotlight VIP', Id=0, SuggestedRobux=149,
  Description='Permanent Spotlight title and exclusive gold aura. Cosmetic only.',Color=Color3.fromRGB(255,223,104)},
}
C.Bundles = {
 {Key='Phantom',Name='PHANTOM SOVEREIGN',Id=0,SuggestedRobux=299,Color=Color3.fromRGB(173,119,255),
  Skin='bomb_phantomset',SkinName='Phantom Sovereign',SkinBase='bomb_abyss',
  Items={{Id='set_phantom_aura',Name='Sovereign Haunt',Slot='Aura',Source='PhantomMistVortex'},
         {Id='set_phantom_trail',Name='Royal Wraith Wake',Slot='Trail',Source='SpectralBansheeLash'},
         {Id='set_phantom_kill',Name='Throne of Shadows',Slot='KillFX',Source='OccultEclipseImplosion'}}},
 {Key='Solar',Name='SOLAR OVERDRIVE',Id=0,SuggestedRobux=299,Color=Color3.fromRGB(255,149,53),
  Skin='bomb_solarset',SkinName='Solar Overdrive',SkinBase='bomb_solar',
  Items={{Id='set_solar_aura',Name='Solar Ascension',Slot='Aura',Source='SpiritSmokeColumn'},
         {Id='set_solar_bomb',Name='Overdrive Core',Slot='BombFX',Source='JackOLanternInferno'},
         {Id='set_solar_kill',Name='Sunfall Cataclysm',Slot='KillFX',Source='HellfireEruption'}}},
 {Key='Cyber',Name='CYBERSTORM',Id=0,SuggestedRobux=349,Color=Color3.fromRGB(59,236,222),
  Skin='bomb_cyberset',SkinName='Cyberstorm Core',SkinBase='bomb_plasma',
  Items={{Id='set_cyber_trail',Name='Circuit Storm',Slot='Trail',Source='NeonBatSwarm'},
         {Id='set_cyber_dodge',Name='Cyber Slip',Slot='DodgeFX',Source='combat_00107'},
         {Id='set_cyber_kill',Name='System Overload',Slot='KillFX',Source='NeonSpiderwebRupture'}}},
 {Key='Glacier',Name='GLACIAL MONARCH',Id=0,SuggestedRobux=349,Color=Color3.fromRGB(132,215,255),
  Skin='bomb_glacialset',SkinName='Glacial Monarch',SkinBase='bomb_arctic',
  Items={{Id='set_glacial_aura',Name='Frozen Crown',Slot='Aura',Source='SpectralAntlerEnergy'},
         {Id='set_glacial_dodge',Name='Monarch Shiver',Slot='DodgeFX',Source='combat_00094'},
         {Id='set_glacial_kill',Name='Winter Requiem',Slot='KillFX',Source='PoisonCrystalBurst'}}},
}
C.Abilities = {
 {Key='Shield',Name='PHASE GUARD',Description='Block ONE incoming swing or throw for 0.8s. Unavailable while carrying the bomb.',Cooldown=18,Duration=.8,Effect='ability_00505',Color=Color3.fromRGB(94,226,255)},
 {Key='Leap',Name='SKYVAULT',Description='A single super jump. Normal jumping stays disabled. Ground activation only.',Cooldown=22,Velocity=78,Effect='combat_00094',Color=Color3.fromRGB(180,158,255)},
 {Key='Speed',Name='OVERDRIVE',Description='+6 movement speed for 2.6 seconds. Keeps the existing dodge speed cap.',Cooldown=20,Duration=2.6,Bonus=6,Effect='combat_00078',Color=Color3.fromRGB(255,185,68)},
}
C.DefaultAbility='Speed'
C.Swing={Cooldown=.58,Windup=.08,Window=.24,Range=6.5,HalfAngle=68,Vertical=5.3}
C.Throw={Cooldown=12,Speed=74,Gravity=18,Lifetime=.72,Radius=2.8}
C.RevealSeconds=7.2
C.Audio={MusicId=0,MusicVolume=.18,SwingId=0,ThrowId=0,AbilityId=0,CrateTickId=0,CrateOpenId=0}
-- MusicId is the ROBLOX audio ID after uploading the supplied MP3, not a filename.
-- Zero is disabled. Existing GameAudioV6 provides non-music effects meanwhile.
C.GemSuggestions={{Gems=100,Robux=49},{Gems=300,Robux=129},{Gems=750,Robux=299}}
C.VIP={Title='title_spotlight',Effect='set_vip_aura',Source='CursedConstellationSigil'}
local P={FastOpen=0,Throw=0,VIP=0}
local B={Phantom=0,Solar=0,Cyber=0,Glacier=0}
for _,p in ipairs(C.Passes) do p.Id=P[p.Key] or 0 end
for _,b in ipairs(C.Bundles) do b.Id=B[b.Key] or 0 end
C.Audio.MusicId=0
return C

end
-- HAB_PLAY_POLISH_8: gameplay tuning only. Existing pass/product/audio IDs remain intact.
local C=priorConfig()
assert(type(C)=='table' and type(C.Abilities)=='table','Invalid expansion Config.')
C.PlayPolishVersion=8
C.Swing={Cooldown=.48,Windup=.055,Window=.235,Range=6.1,HalfAngle=68,Vertical=2.8}
local seen={}
for _,a in ipairs(C.Abilities) do
 if a.Key=='Shield' then
  a.Name='PHASE GUARD';a.Cooldown=18;a.Duration=1
  a.Description='Block one incoming swing or throw for 1 second. Cannot protect the bomb carrier.';seen.Shield=true
 elseif a.Key=='Leap' then
  a.Name='SKYVAULT';a.Cooldown=22;a.Velocity=72
  a.Description='One controlled super jump from solid ground. Normal jumping remains disabled.';seen.Leap=true
 elseif a.Key=='Speed' then
  a.Name='OVERDRIVE';a.Cooldown=20;a.Duration=3;a.Bonus=6
  a.Description='+6 movement speed for 3 seconds. No change to your dodge speed cap.';seen.Speed=true
 end
end
assert(seen.Shield and seen.Leap and seen.Speed,'The three free abilities are missing.')
C.DefaultAbility=seen[C.DefaultAbility] and C.DefaultAbility or 'Speed'
return C


end
local C=priorConfig()
C.SeasonVersion=9
C.VFX={AuraScale=1.55,TrailScale=1.4,DodgeScale=1.35,AbilityScale=1.35,MaxAuraWidth=9.5,BombCover=1.42}
C.Abilities=C.Abilities or {}
local function add(a) for _,old in ipairs(C.Abilities) do if old.Key==a.Key then return end end;table.insert(C.Abilities,a) end
for _,a in ipairs(C.Abilities) do
 if a.Key=='Shield' or a.Key=='Speed' or a.Key=='Leap' then a.Currency='Free';a.Cost=0;a.Mechanic=a.Key end
end
add({Key='Decoy',Name='PARTY DOUBLE',Description='Leave a translucent party twin for 2.4 seconds. It cannot tag, block hits or carry the bomb.',Currency='Coins',Cost=1200,Cooldown=18,Duration=2.4,Mechanic='Decoy',Effect='combat_00058',Color=Color3.fromRGB(255,138,215)})
add({Key='Jester',Name='JESTER SPIN',Description='A whirling jester halo and silly orbiting stars for 2.4 seconds. Cosmetic misdirection; no immunity.',Currency='Coins',Cost=800,Cooldown=15,Duration=2.4,Mechanic='Jester',Effect='combat_00078',Color=Color3.fromRGB(255,200,82)})
add({Key='Bubble',Name='SOAP SPRINT',Description='Leave a bubbly wake while gaining +4 speed for 1.6 seconds. No invulnerability or slowing opponents.',Currency='Gems',Cost=60,Cooldown=18,Duration=1.6,Bonus=4,Mechanic='Speed',Effect='ability_00505',Color=Color3.fromRGB(102,233,228)})
add({Key='Pogo',Name='POGO POP',Description='One smaller, bouncy-looking super hop with a colorful launch burst. Ground use only.',Currency='Gems',Cost=75,Cooldown=20,Duration=1.0,Velocity=52,Mechanic='Leap',Effect='combat_00094',Color=Color3.fromRGB(170,143,255)})
add({Key='Disco',Name='DISCO DOUBLE',Description='Two short-lived disco twins and a dance-floor ripple. Visual decoys only; no collision or immunity.',Currency='Robux',Cost=0,PassKey='Disco',Cooldown=20,Duration=2.4,Mechanic='Disco',Effect='combat_00354',Color=Color3.fromRGB(255,102,193)})
add({Key='Confetti',Name='CONFETTI CANNON',Description='A party cannon burst with +3 speed for 1.8 seconds. A fun alternative, not a stronger Overdrive.',Currency='Robux',Cost=0,PassKey='Confetti',Cooldown=20,Duration=1.8,Bonus=3,Mechanic='Speed',Effect='combat_00078',Color=Color3.fromRGB(101,219,255)})
local function pass(p) for _,old in ipairs(C.Passes) do if old.Key==p.Key then return end end;C.Passes[#C.Passes+1]=p end
pass({Key='Disco',Name='Disco Double',Id=0,SuggestedRobux=99,Description='Permanently unlock the Disco Double ability. Cosmetic decoys; no hitboxes or immunity.',Color=Color3.fromRGB(255,102,193)})
pass({Key='Confetti',Name='Confetti Cannon',Id=0,SuggestedRobux=79,Description='Permanently unlock the Confetti Cannon ability: a party burst and brief, modest speed boost.',Color=Color3.fromRGB(101,219,255)})
C.CustomKillAudio=C.CustomKillAudio or {}
for _,b in ipairs(C.Bundles) do
 for _,fx in ipairs(b.Items) do if fx.Slot=='KillFX' then
  fx.SoundKey=b.Key;fx.Name=({Phantom='Phantom Echo',Solar='Solar Pop',Cyber='System Beep',Glacier='Frost Chime'})[b.Key] or 'Bundle Chime'
 end end
end
for _,p in ipairs(C.Passes) do if PASS_IDS[p.Key] and PASS_IDS[p.Key]>0 then p.Id=PASS_IDS[p.Key] end end
for _,p in ipairs(C.Bundles) do if BUNDLE_PASS_IDS[p.Key] and BUNDLE_PASS_IDS[p.Key]>0 then p.Id=BUNDLE_PASS_IDS[p.Key] end end
for key,id in pairs(KILL_AUDIO_IDS) do if id>0 then C.CustomKillAudio[key]=id end end
return C

-- HAB_FUN_9