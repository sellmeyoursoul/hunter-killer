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
13 | 6/9 | main_3d | pending | — | — | — | Post-refinement run 3 — fill winner/cause/notes after editor playtest.


**Cause tags:** `predation_carn_win` | `starvation_herb` | `starvation_carn_herb_win` | `timeout` | `end_ai`
