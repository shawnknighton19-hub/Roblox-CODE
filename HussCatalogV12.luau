--!nonstrict
-- HussCatalogV12: every item is bought with earned Coins; cosmetic effects only.
local C={Items={},ById={},Categories={'Bombs','Trails','Titles','Emotes'},Defaults={Bombs='bomb_classic',Trails='default',Titles='title_rookie',Emotes='emote_wave'}}
local function add(category,rows)
 for _,r in ipairs(rows) do
  local item={id=r[1],name=r[2],price=r[3],color=r[4],style=r[5],description=r[6],rarity=r[7] or 'Common',category=category}
  assert(not C.ById[item.id],'Duplicate catalog ID');C.ById[item.id]=item;table.insert(C.Items,item)
 end
end
add('Bombs',{
 {'bomb_classic','Classic Fuse',0,{44,48,58},'smooth','Black foundry bomb, copper seam, rivets and a curled sparking fuse.'},
 {'bomb_cherry','Cherry Pop',200,{255,69,92},'smooth','Glossy cherry bomb with a leafy stem and a tiny cherry companion.'},
 {'bomb_cobalt','Cobalt Core',250,{47,134,255},'banded','Armored blue shell with a seven-blade turbine and cooling pipes.'},
 {'bomb_mint','Mint Condition',300,{78,244,183},'banded','A peppermint swirl, fresh leaves and a bright mint bomb shell.'},
 {'bomb_taxi','Taxi Trouble',350,{255,211,48},'hazard','A round yellow taxi bomb with wheels, headlights and checkers.'},
 {'bomb_candy','Candy Capsule',400,{255,123,206},'banded','Wrapped candy bomb with twisted ends, a sugar ribbon and sprinkles.'},
 {'bomb_orange','Citrus Charge',450,{255,157,45},'panel','A sliced citrus bomb with visible segments, a leaf and curling peel.'},
 {'bomb_arctic','Arctic Fuse',500,{140,234,255},'orb','Frozen bomb heart, icy crown shards, icicles and snowbright sparks.','Rare'},
 {'bomb_ember','Ember Egg',600,{255,106,43},'reactor','Obsidian shell plates split by glowing molten cracks and embers.','Rare'},
 {'bomb_toxic','Toxic Tank',700,{143,255,60},'hazard','An acid-filled tank bomb with pressure hoses and a warning badge.','Rare'},
 {'bomb_royal','Royal Rumble',800,{177,105,255},'ring','Purple bomb with a jeweled golden crown, royal sash and ruby crest.','Rare'},
 {'bomb_disco','Disco Disaster',900,{233,109,255},'panel','Mirrored bomb tiles, neon headphones and tiny dance-floor glints.','Rare'},
 {'bomb_gift','Surprise Package',1000,{255,85,129},'gift','A round present bomb with crossed ribbons, a bow and hanging tag.','Rare'},
 {'bomb_bee','Bumble Blast',1100,{255,213,60},'banded','A striped bee bomb with wings, antennae, a stinger and a hot fuse.','Rare'},
 {'bomb_prism','Prism Pop',1250,{147,203,255},'panel','An opal bomb heart inside pastel crystal facets and hanging points.','Epic'},
 {'bomb_saturn','Saturn Sphere',1400,{246,179,115},'ring','A banded planet bomb with a tilted ring and two little moons.','Epic'},
 {'bomb_abyss','Abyss Pearl',1600,{99,88,215},'orb','A glowing midnight pearl cradled in a luminous deep-sea shell.','Epic'},
 {'bomb_spike','Iron Urchin',1800,{150,174,193},'spike','A riveted iron bomb with broad metal spikes and a bolted faceplate.','Epic'},
 {'bomb_plasma','Plasma Pulse',2000,{86,255,238},'reactor','A glass reactor bomb with a plasma coil, cage ribs and power terminals.','Epic'},
 {'bomb_sakura','Sakura Surprise',2200,{255,175,207},'orb','A porcelain-pink bomb with a sculpted branch and three blossoms.','Epic'},
 {'bomb_gold','Golden Fuse',2500,{255,207,62},'banded','A polished gold bomb stamped with a star coin and gilded laurels.','Legendary'},
 {'bomb_void','Void Star',2800,{139,78,246},'spike','A dark armored bomb with a glowing star aperture and drifting wisps.','Legendary'},
 {'bomb_solar','Solar Furnace',3200,{255,158,54},'reactor','A furnace bomb with heat fins, a glowing grate and escaping embers.','Legendary'},
 {'bomb_nova','Supernova',3600,{255,89,167},'ring','A stellar bomb with crossing luminous rings and a brilliant starburst.','Legendary'},
 {'bomb_champion','Champion Charge',4200,{255,227,104},'gift','A trophy bomb with handles, a medal, victory ribbons and laurels.','Legendary'},
})
add('Trails',{
 {'default','Classic',0,{125,244,255},'ribbon','The familiar cyan sprint and golden weave.'},
 {'aqua','Arctic Rush',250,{72,211,255},'ribbon','A crisp blue ribbon for clean escapes.'},
 {'sunset','Solar Rush',400,{255,161,74},'sparks','Orange embers follow your acceleration.'},
 {'royal','Royal Rush',600,{172,116,255},'stars','Violet stars mark a royal escape.','Rare'},
 {'lime','Toxic Rush',800,{157,255,85},'bubbles','Bright green bubbles spill behind you.','Rare'},
 {'rose','Candy Rush',1000,{255,117,180},'confetti','Pink candy confetti follows every burst.','Rare'},
 {'trail_ice','Ice Shards',500,{179,242,255},'sparks','Pale crystal sparks scatter from your heels.'},
 {'trail_smoke','Smoke Screen',550,{170,185,202},'smoke','A soft silver plume marks your path.'},
 {'trail_coins','Coin Shower',650,{255,224,85},'confetti','Golden flecks make every run look valuable.','Rare'},
 {'trail_ocean','Ocean Foam',700,{73,238,218},'bubbles','Turquoise bubbles wash across your wake.','Rare'},
 {'trail_berry','Berry Blast',850,{189,72,220},'pulse','A rich berry pulse surges behind you.','Rare'},
 {'trail_volt','Voltage',950,{255,242,68},'lightning','A jagged yellow flash follows quick turns.','Rare'},
 {'trail_petals','Petal Parade',1100,{255,185,214},'confetti','Pastel petals drift across the arena.','Rare'},
 {'trail_cosmic','Cosmic Dust',1250,{141,142,255},'stars','A starlit indigo path for close calls.','Epic'},
 {'trail_lava','Lava Leak',1400,{255,79,43},'sparks','Hot red sparks burst from your sprint.','Epic'},
 {'trail_ghost','Ghost Step',1500,{207,244,229},'smoke','A pale mist traces your narrow escapes.','Epic'},
 {'trail_neon','Neon Circuit',1700,{53,255,170},'lightning','Green circuit flashes race along your trail.','Epic'},
 {'trail_party','Party Fuse',1900,{255,132,222},'confetti','Bright party pieces make a joyful mess.','Epic'},
 {'trail_halo','Golden Halo',2100,{255,224,125},'pulse','A warm golden pulse lights the finish.','Epic'},
 {'trail_blizzard','Blizzard',2300,{195,235,255},'stars','A cold burst of snowbright stars.','Epic'},
 {'trail_comet','Comet Tail',2600,{93,203,255},'sparks','Brilliant blue sparks streak through the arena.','Legendary'},
 {'trail_eclipse','Eclipse Wake',2900,{175,108,255},'smoke','Purple dusk follows your footsteps.','Legendary'},
 {'trail_overload','Overload',3200,{255,90,89},'lightning','Scarlet energy crackles after each weave.','Legendary'},
 {'trail_supernova','Supernova Wake',3600,{255,155,95},'pulse','A bright solar pulse marks a perfect escape.','Legendary'},
 {'trail_celebrate','Victory Parade',4200,{255,223,71},'confetti','A shower of gold for the arena champion.','Legendary'},
})
add('Titles',{
 {'title_rookie','Fuse Rookie',0,{235,243,255},'title','Your first name in the bomb arena.'},
 {'title_runner','Quick Feet',250,{86,219,255},'title','A title for runners who keep moving.'},
 {'title_courier','Special Delivery',450,{255,181,67},'title','Always ready to hand over the hot package.'},
 {'title_dancer','Danger Dancer',700,{255,126,188},'title','A little style in the danger zone.','Rare'},
 {'title_wire','Live Wire',950,{184,255,82},'title','Charged up and hard to catch.','Rare'},
 {'title_calm','Cool Under Fire',1300,{120,220,255},'title','Keep your head when the timer runs low.','Epic'},
 {'title_stand','Last One Standing',1800,{255,201,82},'title','A bold title for your collection.','Epic'},
 {'title_fuse','Fuse Master',2200,{197,125,255},'title','Wear your explosive ambitions.','Epic'},
 {'title_untouch','Untouchable',2800,{128,255,206},'title','Make every near miss look effortless.','Legendary'},
 {'title_legend','Bomb Legend',3600,{255,226,97},'title','The golden name above the arena.','Legendary'},
})
add('Emotes',{
 {'emote_wave','Friendly Wave',0,{93,211,255},'wave','Say hello in the lobby.'},
 {'emote_cheer','Fuse Cheer',300,{255,206,79},'cheer','Raise your arms and cheer for the next round.'},
 {'emote_salute','Bomb Squad Salute',500,{124,231,160},'salute','A sharp salute before the action.'},
 {'emote_shuffle','Lobby Shuffle',800,{255,140,209},'shuffle','A playful side to side dance.','Rare'},
 {'emote_robot','Circuit Robot',1100,{119,197,255},'robot','Move like a mechanical bomb defuser.','Rare'},
 {'emote_victory','Victory Bounce',1500,{255,211,83},'victory','Celebrate with a grounded victory pose.','Epic'},
 {'emote_spin','Disco Spin',2000,{194,141,255},'spin','Turn up the style with a spinning dance.','Epic'},
 {'emote_charge','Power Up',2600,{255,126,91},'charge','Gather your energy for the next match.','Legendary'},
})
return C
