# Luzon Grid - where to edit
| I want to change...                       | File                    | What to edit |
|-------------------------------------------|-------------------------|--------------|
| Demand, costs, capacities, availability   | solver.R (top)          | DEMAND, BASE_COSTS, CAPACITIES, AVAILABILITY, EMISSION_FACTORS, HEAT_FACTORS |
| Coal min (2800), ramp (1500), hydro (8000)| solver.R, Steps 2-(3)/(4)/(5) | the numbers in b_vec lines marked EDIT |
| Add a new constraint                      | solver.R, end of Step 2 | push a row into A_list and its RHS into b_vec (">=" form) |
| Add a new plant group                     | solver.R + shiny/app.R PAL + web/src/App.jsx ALL/PAL | add to all constants and to the colour maps |
| Solver iteration limit                    | solver.R, max_iters     | 200 |
| Shiny colours/fonts                       | shiny/app.R             | PAL, bs_theme(), css string |
| React colours/layout                      | web/src/styles.css      | :root variables, .layout, .grid2 |
| API address/port                          | api/run_api.R, web/.env | port = 8000, VITE_API_URL |
