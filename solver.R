# =====================================================================
# solver.R  -  PROBLEM DATA + DUAL SIMPLEX SOLVER
# =====================================================================
# Cale, Aaron Cohen D.
# 2025 - 15680
# CMSC 150 - E-5L
# =====================================================================

# --- PROBLEM CONSTANTS ------------------------------------------------
# Names of every plant group. The order here is the order shown in the UI.
PLANT_GROUPS <- c("Coal", "Natural Gas", "Geothermal", "Hydro", "Oil-based", "Solar", "Wind")
# Six time blocks of the day.
BLOCKS <- c("B1", "B2", "B3", "B4", "B5", "B6")
# Length of each block in hours (converts MW -> MWh, and prices MWh -> per-MW-block).
HOURS <- 4

# System demand in MW for each block B1..B6.  EDIT to change the load profile.
DEMAND <- c(6300, 8600, 11800, 12300, 14000, 10600)
# Multiplier on fuel-based costs per block (a heat/fuel-price factor). 1.00 = no change.
HEAT_FACTORS <- c(1.00, 1.01, 1.03, 1.05, 1.04, 1.02)

# Base marginal cost (PHP/MWh) of each group.  EDIT to change generation costs.
BASE_COSTS <- c("Coal" = 3800, "Natural Gas" = 6500, "Geothermal" = 1500,
                "Hydro" = 300, "Oil-based" = 14000, "Solar" = 40, "Wind" = 60)

# Installed capacity in MW of each group.  EDIT to change plant size.
CAPACITIES <- c("Coal" = 7000, "Natural Gas" = 3300, "Geothermal" = 800,
                "Hydro" = 2500, "Oil-based" = 1500, "Solar" = 2500, "Wind" = 400)

# Fraction of capacity actually available per block (only for variable renewables).
# Solar is 0 at night (B1, B6) and peaks midday (B3). Groups not listed here = 100% available.
AVAILABILITY <- list(
  "Solar" = c(0, 0.10, 0.60, 0.55, 0.08, 0),
  "Wind"  = c(0.35, 0.30, 0.25, 0.25, 0.30, 0.35)
)

# Tonnes of CO2 per MWh for each group. Only used when the CO2 cap is switched on.
EMISSION_FACTORS <- c("Coal" = 0.95, "Natural Gas" = 0.40, "Geothermal" = 0.10,
                      "Hydro" = 0.0, "Oil-based" = 0.75, "Solar" = 0.0, "Wind" = 0.0)

# Cost of group `group` in block number `b_idx`.
get_cost <- function(group, b_idx) {
  base <- BASE_COSTS[[group]]                                   # look up the group's base cost
  if (group %in% c("Coal", "Natural Gas", "Geothermal", "Oil-based")) {  # which groups pay the heat factor
    return(base * HEAT_FACTORS[b_idx])                          # scale by that block's factor
  }
  return(base)                                                  # renewables/hydro: flat cost
}

# --- DUAL SIMPLEX SOLVER FROM SCRATCH ---------------------------------
# groups      : character vector of selected plant groups
# co2_toggle  : TRUE/FALSE, add the CO2 cap constraint?
# co2_cap_val : daily CO2 limit in tonnes/day
solve_dual_simplex <- function(groups, co2_toggle, co2_cap_val) {

  # ---- Step 1: name every decision variable x_<group>_<block> ----------
  var_names <- c()                                    # will hold e.g. "x_Coal_B1", "x_Coal_B2", ...
  for (g in groups) {                                 # loop over selected groups
    for (t in BLOCKS) {                               # and over blocks
      var_names <- c(var_names, paste0("x_", g, "_", t))   # append the variable name
    }
  }
  n_vars <- length(var_names)                         # number of primal variables (= dual constraints)

  # ---- Step 2: build the primal constraint matrix A and RHS vector b ----
  A_list <- list()                                    # each element = one constraint row of A
  b_vec <- c()                                        # matching right-hand sides b
  constraint_names <- c()                             # labels (for readability/debugging)

  # (1) Demand: sum over groups of x_gt >= D_t, one row per block
  for (t_idx in seq_along(BLOCKS)) {
    t <- BLOCKS[t_idx]                                # block label
    row <- rep(0, n_vars)                             # start with an all-zero row
    for (g in groups) {
      v_name <- paste0("x_", g, "_", t)               # variable for this group in this block
      row[which(var_names == v_name)] <- 1.0          # coefficient +1 for that variable
    }
    A_list[[length(A_list) + 1]] <- row               # store the row
    b_vec <- c(b_vec, DEMAND[t_idx])                  # RHS = demand of this block
    constraint_names <- c(constraint_names, paste0("Demand_", t))
  }

  # (2) Capacity: x_gt <= Cap_gt  ->  written as  -x_gt >= -Cap_gt
  for (g in groups) {
    cap_base <- CAPACITIES[[g]]                       # installed MW of the group
    for (t_idx in seq_along(BLOCKS)) {
      t <- BLOCKS[t_idx]
      row <- rep(0, n_vars)
      v_name <- paste0("x_", g, "_", t)
      row[which(var_names == v_name)] <- -1.0         # coefficient -1 (flipped to keep ">=" form)

      # availability factor if the group has one (solar/wind), otherwise 1 (full capacity)
      avail <- if (g %in% names(AVAILABILITY)) AVAILABILITY[[g]][t_idx] else 1.0
      cap_val <- cap_base * avail                     # usable MW in this block

      A_list[[length(A_list) + 1]] <- row
      b_vec <- c(b_vec, -cap_val)                     # RHS is negative because the row is negated
      constraint_names <- c(constraint_names, paste0("Cap_", g, "_", t))
    }
  }

  # (3) Coal minimum output and (4) ramping - only if Coal was selected
  if ("Coal" %in% groups) {
    # (3) x_coal_t >= 2800 MW in every block (must-run level)
    for (t in BLOCKS) {
      row <- rep(0, n_vars)
      v_name <- paste0("x_Coal_", t)
      row[which(var_names == v_name)] <- 1.0
      A_list[[length(A_list) + 1]] <- row
      b_vec <- c(b_vec, 2800.0)                       # EDIT 2800 to change the coal minimum
      constraint_names <- c(constraint_names, paste0("CoalMin_", t))
    }

    # (4) Ramping: |x_t - x_{t-1}| <= 1500 MW between consecutive blocks (two inequalities)
    for (t_idx in 2:6) {                              # starts at B2 because B1 has no previous block
      t_curr <- BLOCKS[t_idx]                         # current block
      t_prev <- BLOCKS[t_idx - 1]                     # previous block

      # Ramp up:  x_curr - x_prev <= 1500   ->   -x_curr + x_prev >= -1500
      r_up <- rep(0, n_vars)
      r_up[which(var_names == paste0("x_Coal_", t_curr))] <- -1.0
      r_up[which(var_names == paste0("x_Coal_", t_prev))] <- 1.0
      A_list[[length(A_list) + 1]] <- r_up
      b_vec <- c(b_vec, -1500.0)                      # EDIT 1500 to change the ramp-up limit
      constraint_names <- c(constraint_names, paste0("CoalRampUp_", t_curr))

      # Ramp down: x_prev - x_curr <= 1500  ->    x_curr - x_prev >= -1500
      r_dn <- rep(0, n_vars)
      r_dn[which(var_names == paste0("x_Coal_", t_curr))] <- 1.0
      r_dn[which(var_names == paste0("x_Coal_", t_prev))] <- -1.0
      A_list[[length(A_list) + 1]] <- r_dn
      b_vec <- c(b_vec, -1500.0)                      # EDIT 1500 to change the ramp-down limit
      constraint_names <- c(constraint_names, paste0("CoalRampDown_", t_curr))
    }
  }

  # (5) Hydro daily energy: 4 * sum_t x_hydro_t <= 8000 MWh  ->  -4*sum >= -8000
  if ("Hydro" %in% groups) {
    row <- rep(0, n_vars)
    for (t in BLOCKS) {
      v_name <- paste0("x_Hydro_", t)
      row[which(var_names == v_name)] <- -4.0         # -4 = -(hours per block)
    }
    A_list[[length(A_list) + 1]] <- row
    b_vec <- c(b_vec, -8000.0)                        # EDIT 8000 to change hydro's daily energy
    constraint_names <- c(constraint_names, "HydroLimit")
  }

  # (6) CO2 cap: sum 4*e_g*x_gt <= cap  ->  -sum 4*e_g*x_gt >= -cap
  if (co2_toggle) {
    row <- rep(0, n_vars)
    for (g in groups) {
      e_g <- EMISSION_FACTORS[[g]]                    # t CO2 per MWh of this group
      for (t in BLOCKS) {
        v_name <- paste0("x_", g, "_", t)
        row[which(var_names == v_name)] <- -4.0 * e_g # emissions per MW of dispatch over 4 hours
      }
    }
    A_list[[length(A_list) + 1]] <- row
    b_vec <- c(b_vec, -co2_cap_val)                   # negative of the cap from the UI
    constraint_names <- c(constraint_names, "CO2Cap")
  }

  n_constraints <- length(A_list)                     # total number of primal constraints (= dual variables)

  # ---- Step 3: build the DUAL simplex tableau ---------------------------
  dual_var_names <- paste0("S", 1:n_constraints)      # dual variables S1..Sm (one per primal constraint)
  dual_slack_names <- paste0("s_", var_names)         # one dual slack per primal variable
  col_headers <- c(dual_var_names, dual_slack_names, "Z'", "RHS")   # column labels of the tableau

  # Rows: one per dual constraint (= n_vars) + 1 objective row. Columns: S's, slacks, Z', RHS.
  tableau <- matrix(0, nrow = n_vars + 1, ncol = length(col_headers))
  colnames(tableau) <- col_headers
  basic_vars <- dual_slack_names                      # initial basis = the slacks

  for (j in 1:n_vars) {                               # fill dual constraint row j (= primal variable j)
    for (i in 1:n_constraints) {
      tableau[j, i] <- A_list[[i]][j]                 # transpose of A: column j of A becomes row j
    }
    tableau[j, n_constraints + j] <- 1.0              # identity block for the slack of this row
    tableau[j, "Z'"] <- 0.0                           # Z' is 0 in constraint rows

    # Recover group and block from the variable name "x_<group>_<block>"
    parts <- strsplit(var_names[j], "_")[[1]]         # e.g. c("x","Coal","B1")
    g <- parts[2]                                     # group name
    b <- parts[3]                                     # block name
    b_idx <- which(BLOCKS == b)                       # block number 1..6
    c_gt <- get_cost(g, b_idx)                        # cost with heat factor if applicable
    tableau[j, "RHS"] <- HOURS * c_gt                 # dual RHS = 4 * cost
  }

  # Objective row:  Z' - sum(b_i * S_i) = 0  (we maximise b'S)
  for (i in 1:n_constraints) {
    tableau[n_vars + 1, i] <- -b_vec[i]               # -b_i under each S_i
  }
  tableau[n_vars + 1, "Z'"] <- 1.0                    # coefficient of Z'
  tableau[n_vars + 1, "RHS"] <- 0.0                   # starting objective value

  # History stores every tableau so the UI can show each iteration
  history <- list()
  history[[1]] <- list(tableau = tableau, basic_vars = basic_vars)   # iteration 0 = initial tableau

  # ---- Step 4: simplex iterations ----------------------------------------
  max_iters <- 200                                    # safety stop; raise if you have bigger models
  iter_count <- 1                                     # loop counter
  status <- "OPTIMAL"                                 # assume optimal until proven otherwise

  while (iter_count <= max_iters) {
    # Look at the objective row, only over S and slack columns (not Z' or RHS)
    z_row <- tableau[n_vars + 1, 1:(n_constraints + n_vars)]
    min_val <- min(z_row)                             # most negative entry

    if (min_val >= -1e-7) {                           # no negative entries -> optimal
      status <- "OPTIMAL"
      break
    }

    pivot_col <- which.min(z_row)                     # entering variable (most negative = Dantzig rule)

    # Ratio test: choose the leaving row with the smallest RHS/element among positive elements
    pivot_row <- -1                                   # -1 means "none found yet"
    min_ratio <- Inf
    for (r in 1:n_vars) {
      elem <- tableau[r, pivot_col]                   # candidate pivot element
      rhs <- tableau[r, "RHS"]
      if (elem > 1e-7) {                              # only strictly positive elements qualify
        ratio <- rhs / elem
        if (ratio < min_ratio) {                      # keep the smallest ratio
          min_ratio <- ratio
          pivot_row <- r
        }
      }
    }

    if (pivot_row == -1) {                            # no positive element: dual unbounded
      status <- "INFEASIBLE"                          # => primal infeasible (e.g. not enough capacity)
      break
    }

    # Pivot: make the pivot element 1 and clear the rest of its column
    pivot_val <- tableau[pivot_row, pivot_col]
    tableau[pivot_row, ] <- tableau[pivot_row, ] / pivot_val          # normalise pivot row

    for (r in 1:nrow(tableau)) {
      if (r != pivot_row) {
        factor <- tableau[r, pivot_col]               # how much of the pivot row to subtract
        tableau[r, ] <- tableau[r, ] - factor * tableau[pivot_row, ]
      }
    }

    basic_vars[pivot_row] <- col_headers[pivot_col]   # entering variable replaces the leaving one in the basis
    history[[length(history) + 1]] <- list(tableau = tableau, basic_vars = basic_vars)  # save snapshot
    iter_count <- iter_count + 1
  }

  # ---- Step 5: extract results -------------------------------------------
  Z_opt <- 0                                          # optimal total cost
  primal_x <- list()                                  # named list of dispatch values
  shadow_prices <- rep(0, n_constraints)              # S_i values
  block_prices <- rep(0, 6)                           # PHP/MWh per block

  if (status == "OPTIMAL") {
    final_tab <- history[[length(history)]]$tableau   # last tableau
    Z_opt <- final_tab[nrow(final_tab), "RHS"]        # objective value = minimum cost (strong duality)

    # Primal x_gt = bottom-row value under the matching dual slack column
    for (j in 1:n_vars) {
      slack_col_idx <- n_constraints + j              # slack columns come after the S columns
      primal_x[[var_names[j]]] <- final_tab[nrow(final_tab), slack_col_idx]
    }

    # Shadow price S_i = RHS value when S_i is basic (its column is a clean unit vector)
    for (i in 1:n_constraints) {
      col_vals <- final_tab[, i]                      # column of S_i
      ones <- which(abs(col_vals - 1.0) < 1e-5)       # rows holding a 1
      others <- which(abs(col_vals) > 1e-5 & abs(col_vals - 1.0) >= 1e-5)  # rows holding anything else

      if (length(ones) == 1 && length(others) == 0 && ones[1] <= n_vars) {
        shadow_prices[i] <- max(0, final_tab[ones[1], "RHS"])   # basic -> read its value
      } else {
        shadow_prices[i] <- 0                         # non-basic -> 0
      }
    }

    block_prices <- shadow_prices[1:6] / 4.0          # first 6 constraints = demand rows; /4 gives PHP per MWh
  }

  # Everything the UIs need, returned as one list
  return(list(
    status = status,                                  # "OPTIMAL" or "INFEASIBLE"
    iterations = length(history) - 1,                 # pivots performed
    history = history,                                # all tableaus
    n_vars = n_vars,                                  # number of x variables
    n_constraints = n_constraints,                    # number of constraints
    Z_opt = Z_opt,                                    # minimum cost
    primal_x = primal_x,                              # dispatch values
    shadow_prices = shadow_prices,                    # all S_i
    block_prices = block_prices,                      # prices per block
    groups = groups                                   # groups used in this run
  ))
}

# Helper: turn primal_x into a (groups x blocks) matrix, used by plots/tables/API
dispatch_matrix <- function(res) {
  m <- sapply(BLOCKS, function(b) sapply(res$groups, function(g) {   # for each block, for each group
    v <- res$primal_x[[paste0("x_", g, "_", b)]]      # look up x_g_b
    if (is.null(v)) 0 else v                          # missing -> 0
  }))
  # sapply collapses to a vector when only one group is selected, so rebuild the matrix shape
  if (!is.matrix(m)) m <- matrix(m, nrow = length(res$groups), dimnames = list(res$groups, BLOCKS))
  rownames(m) <- res$groups                           # label rows with group names
  m
}
