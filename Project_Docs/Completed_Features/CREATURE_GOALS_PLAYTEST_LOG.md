# CREATURE_GOALS — manual playtest log

> Copy a row per run. **Winner** and **cause** are authoritative (HUD stays generic “Game Over”). Runtime also emits an `OLog` line tagged `CREATURE_GOALS` from [main.gd](../../main.gd). Parent spec (archived): [CREATURE_GOALS.md](CREATURE_GOALS.md).

Count | date | map | winner (`herbivore` / `carnivore`) | cause tag | herbivore cal end | carnivore cal end | notes |
|------|-----|-----------------------------------|-----------|-------------------|-------------------|-------|
1 | 6/9| main_3d | rabbit | starvation_carn_herb_win | 2 | 0 | Fox never left the upper left corner of the field of play. Rabbit seek behavior seemed less agreesive and it paused for a couple of seconds before continuing to a food source. |
2 | 6/9 | main_3d | none | timeout | 0 | 0 | Same fox behavior as last run. Never came close to where the rabbit was. Rabbit paused a lot more than fox, as if not actively seeking |
3 | 6/9 | main_3d | timeout | 0 | 0 | rabbit moved in a less smooth manner than the fox. They still never overlapped. |
<<Comment : added top down camera movement>>
4 | 6/9 | main_3d | timeout | 0 | 0 | Rabbit got stuck oscilating, there was a boulder to N, and food to the S and SW. NOt sure if it was torn between seek candidates. The fox was still nowhere near |
5 | 6/9 | main_3d | pending | — | — | — | **Guided patrol shipped** (expand hint + trail repulsion; headless `_test_predator_patrol_expanding_coverage` green). Re-run duel in-editor to confirm fox traverses field before timeout — Phase 3 **2× playtest boost** still active. |
6 | 6/9 | main_3d | none | timeout | 0 | 0 | Fox spent most of its time along the east wall. Rabbit seemed to look right past a shrub in the valley. Possible it was too low and LoS was blocked? |
7 | 6/9 | main_3d | none | timeout | 0 | 0 | Fox moved south and got stuck going north/south between the southern wall and a boulder to the north. Rabbit got stuck on a boulder. It's still not clear if it saw the shrub in the valley, though it was moving in that direction. | 
8 | 6/9 | main_3d | none | timeout | 0 | 0 | Fox moved south and got stuck going north/south between the southern wall and a boulder to the north northwest. Rabbit didnt' see the bush in the valley.
9 | 6/9 | main_3d | none | timeout | 0 | 0 | exact same pattern as 7 & 8 for fox and as 7 for rabbit. |
10 | 6/9 | main_3d | rabbit | starvation_carn_herb_win | 5 | 0 | Fox continues using the exact pattern (we need some chaos in there). Rabbit seemed to find the valley shrub when close enough.
11 | 6/9 | main_3d | pending | — | — | — | **Phase 3 refinement pass** shipped: Vector3 food latch/plateau, predator pacing trap + patrol nav escape, rabbit occluded-in-zone goal belief (`plant_awareness_requires_los`), duel pack retune. Re-run duel in-editor — 2× boost still active.
12 | 6/9 | main_3d | pending | — | — | — | **Pinch escape v2** shipped: lateral-only edge escape, tangent default expand, nav tangent goal, `predator_pinch_debug_log` enabled in fox pack. Headless `_test_predator_south_wall_boulder_pinch_escape` green — re-run duel; watch OLog `CREATURE_GOALS` for `pinch_esc` / `pacing_trap` / `final_intent`.
13 | 6/9 | main_3d | pending | — | — | — | Post-refinement run 3 — fill winner/cause/notes after editor playtest. |
14 | 6/10 | main_3d | none | timeout | 0 | 0 | Still seeing fox getting stuck in the same way. Not exactly sure which log to add so I will add a few different that might be relevant below.

W 0:00:02:343   olog.gd:423 @ _mirror_to_editor_impl(): Main3D: no ground hit for prop @Node3D@573 at (97.9, 103.2) — left at Y estimate
  <C++ Source>  core/variant/variant_utility.cpp:1034 @ push_warning()
  <Stack Trace> olog.gd:423 @ _mirror_to_editor_impl()
W 0:00:02:343   olog.gd:423 @ _mirror_to_editor_impl(): Main3D: no ground hit for prop @Node3D@575 at (99.3, 103.2) — left at Y estimate
  <C++ Source>  core/variant/variant_utility.cpp:1034 @ push_warning()
  <Stack Trace> olog.gd:423 @ _mirror_to_editor_impl()
W 0:00:04:461   main_3d.gd:745 @ _log_spawn_floor_contact(): Main3D: Body not on floor after spawn — check playfield collision layer 1 (world_static)
  <C++ Source>  core/variant/variant_utility.cpp:1034 @ push_warning()
  <Stack Trace> main_3d.gd:745 @ _log_spawn_floor_contact()
W 0:00:04:467   olog.gd:423 @ _mirror_to_editor_impl(): Main3D spawn: Body pos=(-15.63, 3.71, -1.36) is_on_floor=false
  <C++ Source>  core/variant/variant_utility.cpp:1034 @ push_warning()
  <Stack Trace> olog.gd:423 @ _mirror_to_editor_impl()
|
15 | 6/10 | main_3d | none | timeout | 0 | 0 | Same fox behavior with similar log entries. |
16 | 6/10 | main_3d | pending | — | — | — | **Cardinal probe scale fix** shipped ([CREATURE_MOVEMENT_V2.md §A.1.1](../Draft_Features/CREATURE_MOVEMENT_V2.md)): playfield-scaled `motor_cardinal_probe_min` / `motor_cardinal_near_probe_min`; predator pinch escape during active goal; `predator_pinch_debug_log` → `OLog.info` (`CREATURE_GOALS`: `pinch_esc` / `pacing_trap` / `final_intent`). Headless `_test_motor_cardinal_probe_scaled_for_small_playfield` green — re-run duel; confirm fox lateral escape at south-wall boulder pinch (rows 7–9 / 14–15 regression). Phase 3 **2× playtest boost** still active. |
17 | 6/10 | main_3d | none | end_ai | 0 | 0 | Fox got stuck in the northeast corner and somehow went off the edge of the playfield to the east 

W 0:00:04:844   main_3d.gd:745 @ _log_spawn_floor_contact(): Main3D: Body not on floor after spawn — check playfield collision layer 1 (world_static)
  <C++ Source>  core/variant/variant_utility.cpp:1034 @ push_warning()
  <Stack Trace> main_3d.gd:745 @ _log_spawn_floor_contact()
W 0:00:04:845   main_3d.gd:745 @ _log_spawn_floor_contact(): Main3D: Body not on floor after spawn — check playfield collision layer 1 (world_static)
  <C++ Source>  core/variant/variant_utility.cpp:1034 @ push_warning()
  <Stack Trace> main_3d.gd:745 @ _log_spawn_floor_contact()
W 0:00:04:849   olog.gd:423 @ _mirror_to_editor_impl(): Main3D spawn: Body pos=(-15.61, 3.64, -1.34) is_on_floor=false
  <C++ Source>  core/variant/variant_utility.cpp:1034 @ push_warning()
  <Stack Trace> olog.gd:423 @ _mirror_to_editor_impl()
W 0:00:04:849   olog.gd:423 @ _mirror_to_editor_impl(): Main3D spawn: Body pos=(90.64, 2.42, -90.45) is_on_floor=false
  <C++ Source>  core/variant/variant_utility.cpp:1034 @ push_warning()
  <Stack Trace> olog.gd:423 @ _mirror_to_editor_impl()
|
18 | 6/10 | main_3d | none | end_ai | 0 | 0 | Fox got stuck in the northeast corner | 
19 | 6/10 | main_3d | none | end_ai | 0 | 0 | Fox got stuck in the northeast corner, similar behavior as the last 2 |
20 |  6/10 | main_3d | none | timeout | 0 | 0 | Fox followed the east edge south and got stuck in roughly the middle of the playfield.

W 0:00:04:214   main_3d.gd:745 @ _log_spawn_floor_contact(): Main3D: Body not on floor after spawn — check playfield collision layer 1 (world_static)
  <C++ Source>  core/variant/variant_utility.cpp:1034 @ push_warning()
  <Stack Trace> main_3d.gd:745 @ _log_spawn_floor_contact()
W 0:00:04:214   main_3d.gd:745 @ _log_spawn_floor_contact(): Main3D: Body not on floor after spawn — check playfield collision layer 1 (world_static)
  <C++ Source>  core/variant/variant_utility.cpp:1034 @ push_warning()
  <Stack Trace> main_3d.gd:745 @ _log_spawn_floor_contact()
W 0:00:04:218   olog.gd:423 @ _mirror_to_editor_impl(): Main3D spawn: Body pos=(-15.61, 3.68, -1.34) is_on_floor=false
  <C++ Source>  core/variant/variant_utility.cpp:1034 @ push_warning()
  <Stack Trace> olog.gd:423 @ _mirror_to_editor_impl()
W 0:00:04:218   olog.gd:423 @ _mirror_to_editor_impl(): Main3D spawn: Body pos=(90.61, 2.46, -90.44) is_on_floor=false
  <C++ Source>  core/variant/variant_utility.cpp:1034 @ push_warning()
  <Stack Trace> olog.gd:423 @ _mirror_to_editor_impl()
|
21 |  6/10 | main_3d | none | timeout | 0 | 0 | Fox followed the east edge south and got stuck in roughly the middle of the playfield. Also, observed that through the majority fo these recent tests, the fox follows the same pattern every time. There should be enough chaos that alternate directions will win out during seek. It shouldn't be 100% predicatable. |
22 |  6/10 | main_3d | none | timeout | 0 | 0 | Still focused on fox, which meandered more but never left the vicity of the east wall so ultimately starved |
23 |  6/10 | main_3d | none | timeout | 0 | 0 | Fox followed the east all to the south wall. Appeared to move west one tick before turning north, for a few and then back south again. |
24 |  6/10 | main_3d | none | timeout | 0 | 0 | Fox meandered to mid-field and then moved in random directions, but functionally staying in a small area. |
25 |  6/10 | main_3d | none | timeout | 0 | 0 | Fox moved south and got stuck mid-field. Why is it always moving south rather than wall sliding west or (even better) moving away from the walls to explore the surrounding area? |
26 |  6/10 | main_3d | none | timeout | 0 | 0 | Fox moved south and got stuck mid-field. |
27 |  6/10 | main_3d | none | timeout | 0 | 0 | Fox moved south and jittered mid-field, facing south and southwest over and over. <<Question: Why would seek push forward at an edge where LOS is obstructed once the Cone of awareness encounters the obstruction. SHouldn't it at least veer away to try and find open space?>> |
28 |  6/10 | main_3d | none | timeout | 0 | 0 | Fox moved west and east a few times, shimmied north, reset and repeted until the creatures starved |
29 | 6/10 | main_3d | none | end_ai | 0 | 0 | Fox moved south and got stuck mid-field. |
30 | 6/10 | main_3d | none | timeout | 0 | 0 | Fox moved south and got stuck mid-field. |
31 | 6/10 | main_3d | none | timeout | 0 | 0 | Fox moved south, with east wall within the zone of awareness. Along it's path it would angle south west occasionally, but not fundamentally move more than a few ticks west. It would also stop and jitter in wide arcs at various points before continuing on it's southern path. |
32 | 6/10 | main_3d | none | timeout | 0 | 0 | Fox moved south with occasional steps west. Around midfield (also when zone of awareness left east wall) it turned east for several ticks and then moved south and got stuck in what looked like a squeeze between the south wall and a boulder to the north northwest. 

0:3:42.161 | Main3D: Body not on floor after spawn — check playfield collision layer 1 (world_static)
0:3:42.161 | Main3D: Body not on floor after spawn — check playfield collision layer 1 (world_static)
0:3:42.167 | Main3D spawn: Body pos=(-15.60, 3.94, -1.34) is_on_floor=false
0:3:42.167 | Main3D spawn: Body pos=(90.60, 2.72, -90.43) is_on_floor=false
|
33 | 6/10 | main_3d | none | timeout | 0 | 0 | Fox moved south until not just the cone, but also the awreness radius crossed the southern wall and then it danced around in the souther corner. |
34 | 6/10 | main_3d | none | timeout | 0 | 0 | Fox got stuck in the NW corner. |
35 | 6/13 | main_3d | none | timeout | 0 | 0 | Fox moved south almost right away and didn't even look away from that direction until he was almost on the southern edge at which point he seemed to circle. <<Question: Why is South scoring so much higher than all other directions? >>
36 | 6/13 | main_3d | none | timeout | 0 | 0 | Fox still moved south, skirting the east wall, with it still in its zone of awareness. Once slightly south east of a boulder by the valley, it appeared to get stuck, trying to turn north, seeing a boulter up there and then just circling. |
37 | 6/13 | main_3d | none | timeout | 0 | 0 | Fox moved south following the same pattern as 36.|
38 | 6/13 | main_3d | none | timeout | 0 | 0 | Fox moved south, veering slightly inward. It got stuck between a couple of boulders and the east wall for about 20 seconds, before moving south again and starving. |
39 | 6/13 | main_3d | none | timeout | 0 | 0 | Fox moved sounth got beyond the boulders it got stuck on in 38, and then turned north as it approached the south wall and got stuck on those boulders. |
40 | 6/13 | main_3d | none | end_ai | 10 | 10 | Fox moved south and occasionally west. Managed to get south of the first boulder, after appearing to get stuck for a couple of seconds. When it was about east of the next boulder, moved east toward the wall, turned back and then got stuck for about 30 seconds before I ended the test. |
41 | 6/13 | main_3d | none | end_ai | 15 | 15 | Same pattern as 20 |
42 | 6/13 | main_3d | none | timeout | 0 | 0 | Fox moved south, danced a bit around the boulder squeeze where it got stuck, but managed to get past. Appeeared to get stuck again near the south wall for a few seconds before moving west. Had a similar problem on a shrub and then spun back and forth near the valley edge. <<question: is a drop/no clear ground treated as open ground or a blocker? If neither how is it weighted?>> |
43 | 6/13 |main_3d | none | timeout | 0 | 0 | Fox moved south and only stuttered a couple of times moving past the boulders. There were a few mroe seconds of stuck in the southeast corner, before moving west. It got stuck there with the bush to the northeast the south wall nearby, and the east wall visible when it turned. The zone of awareness never reached the valley's edge. |
44 |6/13 |main_3d | none | timeout | 0 | 0 | Fox moved south, smoothly past the first boulder, with it to the west and the wall to the east. A few units before being east of the next boulder (so still slightly north), the fox got stuck and spent the next ~30 seconds in rapid oscilation before spending another 10-15 seconds in slow turns, but still stuck, until the timer ran out.


**Cause tags:** `predation_carn_win` | `starvation_herb` | `starvation_carn_herb_win` | `timeout` | `end_ai`
