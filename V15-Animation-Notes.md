# V15 animation notes

V15 adds 15 procedural action variants: a right hook, left hook, overhand strike, throw, hit recoil, block, and distinct poses for all nine abilities. These action poses run on R6 and R15 without uploaded animation assets.

| Action | Control | Animation |
| --- | --- | --- |
| Bomb strike | Left click / controller R2 / TAG button | Alternating cross-body hooks and an overhand strike, timed to the server's hit window. |
| Bomb throw | R / controller R1 / THROW button | Windup, release and arm follow-through. Requires the Bomb Pitcher unlock. |
| Equipped ability | Q / controller Y / ability button | The pose below plays after input; the server decides whether the ability is allowed. |
| Receive a tag / block | Automatic | Short recoil or braced parry; no added stun or forced facing. |

The bomb remains attached to the torso as in the uploaded game. A strike is a tagging gesture that transfers the bomb; it does not temporarily move the carried bomb into a hand. Thrown bombs remain cosmetic representations of the server's projectile.

| Ability | Authored gesture and native effect |
| --- | --- |
| Phase Guard | Crossed-arm preparation, outward brace and a restrained shield shell. |
| Skyvault | Compression, upward reach and an airborne leg tuck. |
| Overdrive | Shoulder load and a forward running arm drive. |
| Party Double | A sweep across the body and one translucent visual twin. |
| Jester Spin | A complete cosmetic body turn with three orbiting stars. |
| Soap Sprint | An outward hand spread and a small bubble wake. |
| Pogo Pop | A deeper compression, release and compact airborne tuck. |
| Disco Double | Alternating overhead points and two visual twins. |
| Confetti Cannon | A two-arm preparation, upward release and recoil. |

The twins have no collision, hit detection, immunity or bomb ownership. Ability feedback uses native geometry. Trail PNG effects remain available; combat and ability feedback does not depend on PNG effects.

Animation priority is explicit: dodge and emote states take precedence, followed by hit/block reactions, attacks, ability gestures and the carrier's panic pose. Lower-body blending keeps locomotion readable during attacks. Poses leave camera direction, shift lock, physical root position and velocity to the existing movement system. Leap and Pogo retain their existing server-approved launches. Reduced Motion reduces pose strength and suppresses extra effect geometry.

The uploaded place already uses R6. Its existing `Animate` controller is preserved: it loads the user's custom R6 locomotion clips independently, with standard fallbacks, and uses R15-compatible clips for R15 avatars. V15 does not change uploaded asset permissions. A custom locomotion clip that is private or owned by a different creator still needs permission for the experience; the new action poses have no such asset dependency.

Validation executes the actual action client, pose sampler and native effects against an offline Roblox math and signal adapter. It checks contact timing, pose ownership, respawn rejection, cleanup, all nine ability effects and allocation limits. `ActionAnimationsV15-Poses.png` and `ActionAnimationsV15-Preview.gif` are offline previews of the actual authored R6 transforms, not Studio recordings.

Before publishing, use Studio's two-player test to check all three strikes, a hit and block, throw, every unlocked ability, a dodge followed by a strike, respawn during an action, and Reduced Motion. Confirm that other players see the same reactions and that normal locomotion continues. Native rendering, multiplayer replication and uploaded asset access require that Studio/published-game test.
