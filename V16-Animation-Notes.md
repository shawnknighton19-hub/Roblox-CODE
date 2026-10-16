# V16 animation notes

This update uses the uploaded **HABWAS** game as its gameplay and GUI baseline. The existing `Animate` script, movement controls, action cooldowns, server hit rules and ability physics are retained.

The new action layer contains **15 pose variants**: right hook, left hook, overhand strike, throw, receiving-hit recoil, shield block, and nine ability gestures. They animate R6 and R15 joints directly and require no uploaded animation IDs.

| Ability | Gesture |
| --- | --- |
| Phase Guard | Crossed-arm preparation, outward brace, guarded recovery. |
| Skyvault | Compressed stance, upward reach, asymmetric airborne tuck. |
| Overdrive | Shoulder load and alternating running arm drive. |
| Party Double | A twist and an outward sweep toward the visual decoy. |
| Jester Spin | A complete cosmetic body turn with an open-arm finish. |
| Soap Sprint | Gathered hands, outward spread and a running recovery. |
| Pogo Pop | Deep compression, release and a compact two-leg tuck. |
| Disco Double | Alternating overhead points and a shifting stance. |
| Confetti Cannon | Two-arm preparation, upward release and recoil. |

Grounded actions align the lowest foot with the existing locomotion pose. Moving legs retain their gait; airborne abilities retain their tuck. These corrections affect joint transforms only. The physical root, camera and shift lock remain under the original controllers. The bomb remains attached to the torso: strikes are tagging gestures, while throws use the original projectile system.

**Controls are unchanged:** left click/R2 for strikes, R/R1 for throws, and Q/Y for the equipped ability. Existing touch buttons remain in the original HUD.

The rebuilt weave and action animation layers share visual ownership. Predictions yield to an active weave. A newer server-approved action can interrupt an older weave animation because the original server already permits those actions; a new weave interrupts an older action. This does not add attack locks or change cooldowns. Panic motion yields while either layer owns the pose. Ability FX have a single owner, `HABFunAbilityFXV16`, so the action client does not duplicate their effects.

Reduced Motion softens action poses and removes the complete Jester turn. Death, respawn, ragdoll, cancellation and rejected predictions restore only transforms owned by the action layer.

The original custom locomotion clips still depend on their existing Roblox asset permissions. Their original parallel loading and fallback handling remain in `Animate`; the new action and weave poses do not require animation assets.

Validation covers the actual action client, pose sampler and both weave/action callback orders using an offline Roblox math/signal adapter. The original input bindings and approved local launch/speed blocks are checked byte-for-byte against the uploaded client. `ActionAnimationsV16-Poses.png` and `ActionAnimationsV16-Preview.gif` show actual authored R6 transforms, rendered offline; the GIF is slowed down for inspection.

In Studio's two-player test, verify strikes, throw, receiving a tag, shield block, each unlocked ability, action/weave transitions, respawn during an action and Reduced Motion. Native blending, network replication, actual character proportions and existing uploaded assets still require this playtest.
