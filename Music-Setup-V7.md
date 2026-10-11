# Full music tracks for Huss A Bomb

V7 removes the generated note/drum soundtrack and keeps gameplay sound effects. Music starts when you add real Roblox audio asset IDs. Choose two tracks to begin: Lobby and Chase. A separate Final Duel track is optional; otherwise the chase track continues without restarting.

## Find ready-made music

1. In Roblox Studio, open **Toolbox → Creator Store**, then choose **Audio**.
2. Search and preview full music tracks. Suggested directions:
   - **Lobby:** `chill electronic`, `downtempo`, or `ambient groove`; relaxed instrumental music around 85–105 BPM.
   - **Chase:** `electronic action`, `breakbeat`, or `drum and bass`; energetic instrumental music around 125–165 BPM.
   - **Final Duel (optional):** `electronic tension` or `action pulse`; a more urgent track.
3. Right-click the chosen audio asset → **Copy Asset ID**. Copy the actual asset ID, not a model ID or a website's catalog of unverified song codes.
4. Put those IDs in the installer’s `MUSIC` entries, or send them as `Lobby: …`, `Chase: …`, and optionally `Duel: …`.

Clicking an audio result inserts a Sound into Explorer. You only need its ID for this system; you do not need extra autoplay Sound objects.

## Upload a track you already have

1. Use a track you made or have permission to use in your Roblox game.
2. Open [Creator Dashboard](https://create.roblox.com/dashboard/creations) → **Development Items → Audio → Upload Asset**. Upload the file, give it a name, and wait for moderation. Roblox currently accepts MP3, OGG, WAV, or FLAC under 20 MB and shorter than seven minutes, with sample rates up to 48 kHz.
3. On the uploaded asset, open **Permissions → Experiences → Add experiences**, enter your game's **universe ID**, then **Add → Done**. This matters for private audio, including audio uploaded under an account different from the game's owner/group.
4. In the published game's Studio Command Bar, `print(game.GameId)` gives its universe ID. A result of `0` means this place is not yet associated with a published experience. `game.PlaceId` is a different ID.
5. Copy the uploaded audio's asset ID into the music configuration. Test the published experience and check Studio Output if Roblox reports an audio permission or loading error.

The installer accepts bare numeric asset IDs or `rbxassetid://…` values. Empty installer fields preserve existing settings. When no Duel ID is stored in Workspace, Duel uses Chase. Invalid or inaccessible audio does not bring back the generated-note soundtrack.

Official instructions verified from Roblox's current creator documentation:

- [Find and import audio](https://create.roblox.com/docs/audio/assets)
- [Grant a game permission to use an asset](https://create.roblox.com/docs/projects/assets/privacy#to-games)

No music files were generated, uploaded, or licensed by this update. Track selection and Roblox permission checks still need to happen in Studio/Creator Dashboard.
