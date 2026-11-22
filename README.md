# ⚡ Luzon Grid Dispatch & Price Simulator

Find the cheapest way to power Luzon across all six 4-hour blocks of the day. Turn different power plants on or off, add a carbon emissions limit, and see the lowest-cost energy mix and electricity prices update for each 4-hour window.

> **Live Web App:** https://01a201e3-3443-d94f-4db5-12f2cea6c5bf.share.connect.posit.cloud/

---

## Overview

The **Luzon Grid Dispatch & Price Simulator** is an interactive R Shiny decision-support tool powered by a custom **Dual Simplex linear programming solver** (`solver.R`). It models 24-hour economic power dispatch across **six 4-hour time blocks** using **seven generation technologies**:

* **Thermal & Baseload:** Coal, Natural Gas, Geothermal, Oil-based
* **Renewables:** Hydro, Solar, Wind

For any combination of active plant groups and optional carbon constraints, the simulator computes the least-cost generation schedule (MW), marginal electricity spot prices (PHP/MWh), and every intermediate pivot tableau of the dual simplex algorithm.

---

### Project Information

| Detail | Information |
| :--- | :--- |
| **Name** | Aaron Cohen D. Cale |
| **Section** | C-3L |
| **Course** | CMSC 150 |
| **Frontend** | R Shiny (`bslib` / Bootstrap 5, `plotly`, Custom CSS/JS) |
| **Backend** | R (`solver.R` & Shiny Server) |
| **Optimization** | Custom Dual Simplex Algorithm (`solve_dual_simplex`) |

---

## User Manual

### 1. Configure Controls (Left Sidebar)

1. **Select Plant Groups:** Check or uncheck any combination of the seven energy sources (**Coal**, **Natural Gas**, **Geothermal**, **Hydro**, **Oil-based**, **Solar**, **Wind**) to include or exclude them from the grid.
   * **Check all:** Quickly re-enables all seven plant groups.
   * **Reset:** Clears all plant checkboxes, turns off the CO₂ cap, and restores the default limit (`165,000 t/day`).
2. **Set an Optional Carbon Limit:**
   * Toggle **Enable CO₂ cap** on to enforce a daily emissions ceiling.
   * Type your desired cap in **Daily CO₂ limit (t/day)** (default: `165000`).
3. **Run the Solver:**
   * Click **RUN SIMULATION** (or press `Enter`) to solve the linear program and refresh all charts, tables, and simplex iterations.

---

### 2. Interpret the Results Tab

#### Key Performance Indicators (Top Row)
* **Status:** Displays **`OPTIMAL`** when a valid least-cost schedule is found. If your selected plants cannot meet grid demand—or if the CO₂ cap is too strict—an **`INFEASIBLE`** alert appears along with the number of iterations attempted.
* **Total minimum cost (Z):** The minimized total daily generation cost across all six blocks, formatted in Philippine Pesos (**PHP**).
* **Iterations:** Total number of dual simplex pivot steps required to reach optimality.
* **LP setup:** Displays the size of the formulated linear program (`unknowns` / decision variables and `constraints`).

#### Interactive Charts
* **Dispatch by block (MW):** A stacked bar chart showing how much power (in megawatts) each energy source contributes during each 4-hour block. Hover over any bar segment to view exact MW values.
* **Spot price per block (PHP / MWh):** A line and area chart showing the marginal system electricity price for every 4-hour window, derived from the dual shadow prices of the demand constraints.

#### Summary Tables
* **Optimal dispatch x_gt (MW):** Exact megawatt output scheduled for each active plant group across all six time blocks.
* **Electricity spot prices (PHP / MWh):** Exact marginal spot price for each 4-hour block.

---

### 3. Inspect the Simplex Tableau Tab

Switch to the **Simplex Tableau** tab to examine the mathematical optimization step by step:

* **Iteration Selector:** Use the dropdown menu—or click **Prev** and **Next**—to move through `Iteration 0 (Initial)` up to `Iteration N (Final)`. Navigation loops continuously from the final tableau back to the initial tableau.
* **Tableau Grid:** Displays the current basic variables (**`Basic Var`**), decision and slack variable columns, right-hand side values, and the reduced-cost objective row (**`Z'`**).

---

### 4. Keyboard Shortcuts

| Key | Action |
| :--- | :--- |
| `Enter` | Runs the simulation from anywhere in the app |
| `←` (Left Arrow) | Moves to the previous iteration (when on the **Simplex Tableau** tab) |
| `→` (Right Arrow) | Moves to the next iteration (when on the **Simplex Tableau** tab) |

---

## Running the App Locally (Offline)

If you have **R (4.3+)** and **RStudio** installed, you can run the simulator offline on your own machine:

### Option A: Launch Directly from GitHub
Run the following commands in your R console:

```r
install.packages(c("shiny", "bslib", "plotly"))
shiny::runGitHub("luzon-grid-dispatch-simulator", username = "aaroncale", ref = "main")
```

### Option B: Run from a Local Clone
1. Clone or download this repository to your computer.
2. Open `app.R` in RStudio.
3. Click **Run App** in the top-right corner of the editor, or run:
   ```r
   shiny::runApp("app.R", launch.browser = TRUE)
   ```

---

## Repository Structure

```text
luzon-grid-dispatch-simulator/
├── app.R           # Shiny UI layout, dark theme styling, Plotly visuals, and server logic
├── solver.R        # Custom dual simplex LP solver, grid parameters, and constraint builders
├── manifest.json   # R package dependency manifest for Posit Connect Cloud deployment
└── README.md       # Project overview and user manual
```

---

## Notes

- The Dual Simplex algorithm (`solve_dual_simplex()`) is implemented completely from scratch in base R.
- No external optimization or linear programming packages are used.
- The R solver module (`solver.R`) is responsible for all mathematical computations, including LP constraint construction, dual simplex pivot iterations, optimal dispatch extraction, and marginal spot pricing.
- The R Shiny frontend (`app.R`) communicates reactively with `solver.R`, dynamically updating Plotly charts, KPI cards, and step-by-step simplex tableaus whenever inputs change.
- The solver backend (`solver.R`) is decoupled from the Shiny UI and can be sourced and tested independently in the R console.

---

Developed as part of **CMSC 150 – C-3L**  
**Aaron Cohen D. Cale**  
University of the Philippines Los Baños