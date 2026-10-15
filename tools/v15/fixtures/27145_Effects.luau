--[[
	Effects: the 50 Halloween effects, by theme. HalloweenVFX reads everything from here.

	label     the display name
	theme     the effect's group
	type      Slash, Impact or Build (sets the play time)
	lifetime  seconds per play at speed 1
	colour    image id of the colour flipbook (Body and Glow)
	mono      image id of the mono sheet (the dark Backing layer). Optional: "" plays without it
	fit       keeps the art's size (the art was shrunk to fit its cells); don't change
	base      the lowest point the art ever reaches, 0 = top of the frame, 1 = bottom (for grounded)
	glow      the effect's main colour (tints the Backing)

	If you upload the textures yourself (see UPLOADING THE TEXTURES in the Read Me), paste the new ids
	into colour and mono. Textures/<Name>.png is colour, Textures/Backing/<Name>.png is mono.
]]

return {
	-- Pumpkins: Cursed jack-o'-lanterns
	FieryJackOLantern = { label = "Fiery Jack-o'-Lantern", theme = "Pumpkins", type = "Impact", lifetime = 0.9,
		colour = "100912410164181", mono = "90213640148489", fit = 0.9516, base = 0.957, glow = Color3.fromRGB(255, 109, 25) },
	JackOLanternSwirl = { label = "Jack-o'-Lantern Swirl", theme = "Pumpkins", type = "Build", lifetime = 1.1,
		colour = "127598801714674", mono = "106023144308750", fit = 0.9516, base = 0.9609, glow = Color3.fromRGB(45, 255, 50) },
	JackOLanternVortex = { label = "Jack-o'-Lantern Vortex", theme = "Pumpkins", type = "Build", lifetime = 1.1,
		colour = "137804944661587", mono = "97290697638762", fit = 0.9516, base = 0.9609, glow = Color3.fromRGB(154, 65, 255) },
	JackOLanternBloom = { label = "Jack-o'-Lantern Bloom", theme = "Pumpkins", type = "Build", lifetime = 1.1,
		colour = "70490644475144", mono = "132489154713591", fit = 0.9564, base = 0.957, glow = Color3.fromRGB(255, 25, 41) },
	JackOLanternFlare = { label = "Jack-o'-Lantern Flare", theme = "Pumpkins", type = "Build", lifetime = 1.1,
		colour = "109314870199509", mono = "138146742184054", fit = 0.9516, base = 0.9609, glow = Color3.fromRGB(34, 128, 255) },
	JackOLanternWisp = { label = "Jack-o'-Lantern Wisp", theme = "Pumpkins", type = "Build", lifetime = 1.1,
		colour = "92118090830925", mono = "121567418883673", fit = 0.9516, base = 0.9609, glow = Color3.fromRGB(48, 122, 255) },
	JackOLanternBurst = { label = "Jack-o'-Lantern Burst", theme = "Pumpkins", type = "Impact", lifetime = 0.9,
		colour = "75544513304667", mono = "89641396289598", fit = 0.9516, base = 0.9609, glow = Color3.fromRGB(255, 49, 242) },
	JackOLanternInferno = { label = "Jack-o'-Lantern Inferno", theme = "Pumpkins", type = "Build", lifetime = 1.1,
		colour = "140031327233613", mono = "133259523693911", fit = 0.9631, base = 0.957, glow = Color3.fromRGB(140, 174, 255) },

	-- Spirits & Wraiths: Ghosts, mist and apparitions
	GhostlyVeilDissipation = { label = "Ghostly Veil Dissipation", theme = "Spirits & Wraiths", type = "Impact", lifetime = 0.9,
		colour = "87354217066163", mono = "126729741498410", fit = 0.9516, base = 0.9609, glow = Color3.fromRGB(140, 233, 255) },
	PhantomMistVortex = { label = "Phantom Mist Vortex", theme = "Spirits & Wraiths", type = "Build", lifetime = 1.1,
		colour = "89967337073633", mono = "74274576641980", fit = 1.0, base = 0.9453, glow = Color3.fromRGB(140, 154, 255) },
	PhantomShroudFold = { label = "Phantom Shroud Fold", theme = "Spirits & Wraiths", type = "Build", lifetime = 1.1,
		colour = "123649167871441", mono = "121567623052178", fit = 0.9632, base = 0.957, glow = Color3.fromRGB(164, 51, 255) },
	SpiritSmokeColumn = { label = "Spirit Smoke Column", theme = "Spirits & Wraiths", type = "Build", lifetime = 1.1,
		colour = "124757967887681", mono = "84731300108020", fit = 0.967, base = 0.9805, glow = Color3.fromRGB(115, 134, 255) },
	SpiritRainfall = { label = "Spirit Rainfall", theme = "Spirits & Wraiths", type = "Build", lifetime = 1.1,
		colour = "78647682861418", mono = "118705266782599", fit = 0.9639, base = 0.9531, glow = Color3.fromRGB(255, 171, 131) },
	WraithHelixColumn = { label = "Wraith Helix Column", theme = "Spirits & Wraiths", type = "Build", lifetime = 1.1,
		colour = "88853962294156", mono = "94473718721809", fit = 0.9577, base = 0.9688, glow = Color3.fromRGB(92, 95, 255) },
	WraithEruption = { label = "Wraith Eruption", theme = "Spirits & Wraiths", type = "Build", lifetime = 1.1,
		colour = "77265235883814", mono = "94788665028232", fit = 0.9516, base = 0.9414, glow = Color3.fromRGB(255, 255, 140) },
	SpectralAntlerEnergy = { label = "Spectral Antler Energy", theme = "Spirits & Wraiths", type = "Build", lifetime = 1.1,
		colour = "93856933462339", mono = "104449163868798", fit = 0.9516, base = 0.9609, glow = Color3.fromRGB(140, 189, 255) },
	MoonbranchApparition = { label = "Moonbranch Apparition", theme = "Spirits & Wraiths", type = "Build", lifetime = 1.1,
		colour = "111184756727568", mono = "82136901141053", fit = 0.9516, base = 0.9336, glow = Color3.fromRGB(160, 116, 255) },
	GraveLightningWraith = { label = "Grave Lightning Wraith", theme = "Spirits & Wraiths", type = "Impact", lifetime = 0.9,
		colour = "123802317645382", mono = "119051975369119", fit = 0.9873, base = 0.9609, glow = Color3.fromRGB(237, 255, 140) },

	-- Reaper Slashes: Banshee lashes and scythe cuts
	BansheeLashCrescent = { label = "Banshee Lash Crescent", theme = "Reaper Slashes", type = "Slash", lifetime = 0.7,
		colour = "116597355511830", mono = "79042783319833", fit = 0.9516, base = 0.9531, glow = Color3.fromRGB(140, 240, 255) },
	SpectralBansheeLash = { label = "Spectral Banshee Lash", theme = "Reaper Slashes", type = "Slash", lifetime = 0.7,
		colour = "81996456532072", mono = "87677226760129", fit = 0.9516, base = 0.957, glow = Color3.fromRGB(140, 168, 255) },
	ReaperCrescentSlash = { label = "Reaper Crescent Slash", theme = "Reaper Slashes", type = "Slash", lifetime = 0.7,
		colour = "88679122265818", mono = "131023627769306", fit = 0.9516, base = 0.9609, glow = Color3.fromRGB(145, 136, 255) },
	CursedScytheCross = { label = "Cursed Scythe Cross", theme = "Reaper Slashes", type = "Slash", lifetime = 0.7,
		colour = "129462164404166", mono = "135279793197634", fit = 0.9765, base = 0.957, glow = Color3.fromRGB(255, 46, 240) },
	BloodMistSlash = { label = "Blood Mist Slash", theme = "Reaper Slashes", type = "Slash", lifetime = 0.7,
		colour = "101925930126129", mono = "139943204125921", fit = 0.9516, base = 0.9414, glow = Color3.fromRGB(255, 25, 34) },
	SpectralWingClash = { label = "Spectral Wing Clash", theme = "Reaper Slashes", type = "Impact", lifetime = 0.9,
		colour = "85706368178933", mono = "93256610369340", fit = 0.9686, base = 0.957, glow = Color3.fromRGB(158, 255, 140) },

	-- Bats & Swarms: Wings in the dark
	NeonBatSwarm = { label = "Neon Bat Swarm", theme = "Bats & Swarms", type = "Build", lifetime = 1.1,
		colour = "135585201577418", mono = "80870606929806", fit = 0.9516, base = 0.9609, glow = Color3.fromRGB(255, 25, 190) },
	SpectralBatSwarm = { label = "Spectral Bat Swarm", theme = "Bats & Swarms", type = "Build", lifetime = 1.1,
		colour = "103220330735643", mono = "73524740100689", fit = 0.9829, base = 0.9531, glow = Color3.fromRGB(200, 25, 255) },
	DarkEmberBatSwarm = { label = "Dark Ember Bat Swarm", theme = "Bats & Swarms", type = "Build", lifetime = 1.1,
		colour = "111391211337359", mono = "91983075743278", fit = 0.9516, base = 0.9609, glow = Color3.fromRGB(255, 80, 34) },
	MothAshVortex = { label = "Moth Ash Vortex", theme = "Bats & Swarms", type = "Build", lifetime = 1.1,
		colour = "91635824849093", mono = "99293099475537", fit = 0.9516, base = 0.9609, glow = Color3.fromRGB(255, 147, 91) },

	-- Hexes & Sigils: Occult circles and curses
	CursedConstellationSigil = { label = "Cursed Constellation Sigil", theme = "Hexes & Sigils", type = "Build", lifetime = 1.1,
		colour = "103152022332396", mono = "94776733387163", fit = 0.9577, base = 0.957, glow = Color3.fromRGB(236, 93, 255) },
	InfernalHexagramSigil = { label = "Infernal Hexagram Sigil", theme = "Hexes & Sigils", type = "Build", lifetime = 1.1,
		colour = "99270966449693", mono = "92953863319651", fit = 0.9516, base = 0.9531, glow = Color3.fromRGB(255, 97, 54) },
	HexStitchTear = { label = "Hex Stitch Tear", theme = "Hexes & Sigils", type = "Build", lifetime = 1.1,
		colour = "88944091068453", mono = "133993295389369", fit = 0.9516, base = 0.9609, glow = Color3.fromRGB(255, 75, 79) },
	HexStitchLatticeTear = { label = "Hex Stitch Lattice Tear", theme = "Hexes & Sigils", type = "Build", lifetime = 1.1,
		colour = "94840319572522", mono = "81696769150303", fit = 0.9516, base = 0.9531, glow = Color3.fromRGB(255, 63, 41) },
	OccultEclipseSigilExplosion = { label = "Occult Eclipse Sigil Explosion", theme = "Hexes & Sigils", type = "Build", lifetime = 1.1,
		colour = "130052169310461", mono = "79582308375891", fit = 0.9575, base = 0.9609, glow = Color3.fromRGB(255, 46, 25) },
	OccultEclipseImplosion = { label = "Occult Eclipse Implosion", theme = "Hexes & Sigils", type = "Impact", lifetime = 0.9,
		colour = "119982515459682", mono = "103165387173034", fit = 0.9516, base = 0.9609, glow = Color3.fromRGB(255, 68, 34) },
	CursedHexTendrils = { label = "Cursed Hex Tendrils", theme = "Hexes & Sigils", type = "Build", lifetime = 1.1,
		colour = "139601058562795", mono = "83900121622641", fit = 0.9894, base = 0.9531, glow = Color3.fromRGB(255, 104, 25) },
	NeonSpiderwebRupture = { label = "Neon Spiderweb Rupture", theme = "Hexes & Sigils", type = "Impact", lifetime = 0.9,
		colour = "107191447664282", mono = "89906215765213", fit = 0.9516, base = 0.9609, glow = Color3.fromRGB(255, 77, 102) },
	VoidEyeSmoke = { label = "Void Eye Smoke", theme = "Hexes & Sigils", type = "Impact", lifetime = 0.9,
		colour = "113230082807973", mono = "79917004171331", fit = 0.9516, base = 0.9609, glow = Color3.fromRGB(255, 69, 79) },

	-- Souls & Vortices: Wisps, orbits and spirals
	SoulOrbitNova = { label = "Soul Orbit Nova", theme = "Souls & Vortices", type = "Impact", lifetime = 0.9,
		colour = "104134095569789", mono = "139151870846885", fit = 1.0, base = 0.8945, glow = Color3.fromRGB(246, 140, 255) },
	SoulWispVortex = { label = "Soul Wisp Vortex", theme = "Souls & Vortices", type = "Build", lifetime = 1.1,
		colour = "91524716030137", mono = "88592714795162", fit = 1.0, base = 0.9219, glow = Color3.fromRGB(244, 140, 255) },
	WillOWispVortex = { label = "Will O Wisp Vortex", theme = "Souls & Vortices", type = "Build", lifetime = 1.1,
		colour = "91566334695837", mono = "83687549156525", fit = 0.9894, base = 0.9492, glow = Color3.fromRGB(175, 107, 255) },
	SpectralGalaxyVortex = { label = "Spectral Galaxy Vortex", theme = "Souls & Vortices", type = "Build", lifetime = 1.1,
		colour = "85829372776444", mono = "134582010737004", fit = 0.988, base = 0.957, glow = Color3.fromRGB(125, 137, 255) },
	DarkEmberVortex = { label = "Dark Ember Vortex", theme = "Souls & Vortices", type = "Build", lifetime = 1.1,
		colour = "73668721712825", mono = "108461092101272", fit = 0.9516, base = 0.9453, glow = Color3.fromRGB(255, 113, 64) },
	SmokyEmberVortex = { label = "Smoky Ember Vortex", theme = "Souls & Vortices", type = "Build", lifetime = 1.1,
		colour = "75808958725385", mono = "119430014747802", fit = 0.9829, base = 0.9531, glow = Color3.fromRGB(255, 152, 104) },
	VoidThornNova = { label = "Void Thorn Nova", theme = "Souls & Vortices", type = "Impact", lifetime = 0.9,
		colour = "75615020003110", mono = "95778971484561", fit = 0.9516, base = 0.9609, glow = Color3.fromRGB(192, 94, 255) },

	-- Hellfire & Poison: Eruptions, blood rings and toxic bursts
	HellfireEruption = { label = "Hellfire Eruption", theme = "Hellfire & Poison", type = "Build", lifetime = 1.1,
		colour = "120735363581775", mono = "100433376914793", fit = 0.9516, base = 0.9609, glow = Color3.fromRGB(255, 138, 68) },
	BloodRedRingExplosion = { label = "Blood Red Ring Explosion", theme = "Hellfire & Poison", type = "Impact", lifetime = 0.9,
		colour = "104401199252916", mono = "99242104469540", fit = 0.9575, base = 0.9609, glow = Color3.fromRGB(255, 44, 28) },
	GravePulseNetwork = { label = "Grave Pulse Network", theme = "Hellfire & Poison", type = "Build", lifetime = 1.1,
		colour = "129214795393417", mono = "72894016755248", fit = 0.9571, base = 0.9609, glow = Color3.fromRGB(255, 158, 78) },
	NecromanticFungalGround = { label = "Necromantic Fungal Ground", theme = "Hellfire & Poison", type = "Build", lifetime = 1.1,
		colour = "118466205049196", mono = "136050338693187", fit = 0.9516, base = 0.9609, glow = Color3.fromRGB(255, 168, 91) },
	PoisonCrystalBurst = { label = "Poison Crystal Burst", theme = "Hellfire & Poison", type = "Impact", lifetime = 0.9,
		colour = "109874498247044", mono = "127524234711925", fit = 0.9815, base = 0.9531, glow = Color3.fromRGB(249, 255, 75) },
	PoisonCrystalSurge = { label = "Poison Crystal Surge", theme = "Hellfire & Poison", type = "Build", lifetime = 1.1,
		colour = "81037887276666", mono = "113875238427714", fit = 0.9516, base = 0.9609, glow = Color3.fromRGB(255, 239, 85) },
}
