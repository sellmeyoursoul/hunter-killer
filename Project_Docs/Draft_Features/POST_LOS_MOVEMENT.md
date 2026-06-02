High level movement decision tree

      -------------------
      | Is active goal  |
      | location known? |
      -------------------
          no |  | Yes
          ___    ___
          |        |
          V        V
      --------  ----------------
      | Seek |  | Is there  a  |
      --------  | clear path   |
                | to the goal? |
                ----------------
                  yes | | no
                ______   ______
                |              |
                V              V
          ------------    -----------------
          | move to  |    | Calculate     |
          | the goal |    | optimal steps |
          ------------    -----------------
                                  |
                                  V
                            ------------------
                            | Make the first |
                            | step the new   |
                            | active goal.   |
                            ------------------

Every n ticks, the zone of awareness is reevualuated and **goals consideration** runs based on new observations.

n is derived off of the creature's Observation attribute, so that higher Observation = more frequestn ticks

Create and active goal table holding active goals and weights. If the table is empty, no-movement/creature at rest (apply rest/sleep model if applicable). **Goal consideration** works through all possible goals and weights them. If a goal is broken into steps, the earliest unaccomplished step is the primary step for that goal. If another goal weight gets a higher score, the steps are discarded as it is no longer the active goal. 

