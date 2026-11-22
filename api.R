# =====================================================================
# api/api.R  -  plumber REST API: lets React call the R solver over HTTP
# Start it with:  Rscript api/run_api.R   (listens on http://localhost:8000)
# Comments starting with  #*  are plumber annotations (they define routes), not normal comments.
# =====================================================================

library(plumber)      # turns R functions into HTTP endpoints
library(jsonlite)     # converts R objects to JSON
source("solver.R") # same solver as the Shiny app

#* @filter cors
function(req, res) {                                           # runs before every request
  res$setHeader("Access-Control-Allow-Origin", "*")            # let the React dev server (other port) call us
  res$setHeader("Access-Control-Allow-Headers", "Content-Type")
  res$setHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
  if (req$REQUEST_METHOD == "OPTIONS") { res$status <- 200; return(list()) }   # browser "preflight" check
  plumber::forward()                                           # continue to the real endpoint
}

#* @get /config
#* @serializer json list(auto_unbox = TRUE)
function() {                                                   # static info about the model
  list(groups = I(PLANT_GROUPS), blocks = I(BLOCKS), demand = I(DEMAND),   # I() keeps 1-length vectors as arrays
       emissions = as.list(EMISSION_FACTORS), default_co2 = 165000)

}

#* @post /solve
#* @serializer json list(auto_unbox = TRUE, digits = NA)       # digits = NA -> full numeric precision
function(req, res) {
  b <- req$body                                                # parsed JSON sent by React
  groups <- as.character(unlist(b$groups))                     # list -> character vector
  co2_toggle <- isTRUE(b$co2_toggle)                           # safe TRUE/FALSE
  co2_limit <- suppressWarnings(as.numeric(b$co2_limit))       # NA if not numeric

  if (length(groups) == 0) { res$status <- 400; return(list(error = "Please select at least one plant group.")) }
  if (co2_toggle && (is.na(co2_limit) || co2_limit <= 0)) {    # same validation as the Shiny app
    res$status <- 400; return(list(error = "CO2 cap limit must be a positive number."))
  }

  r <- solve_dual_simplex(groups, co2_toggle, co2_limit)       # run the solver
  out <- list(status = r$status, iterations = r$iterations, n_vars = r$n_vars,      # scalar results
              n_constraints = r$n_constraints, Z_opt = r$Z_opt, groups = I(r$groups), blocks = I(BLOCKS))

  if (r$status == "OPTIMAL") {
    m <- dispatch_matrix(r)                                    # groups x blocks
    out$dispatch <- setNames(lapply(r$groups, function(g) I(round(unname(m[g, ]), 2))), r$groups)  # {group: [B1..B6]}
    out$block_prices <- I(round(r$block_prices, 2))            # 6 prices
  }

  out$columns <- I(colnames(r$history[[1]]$tableau))           # tableau column headers
  out$history <- lapply(r$history, function(h) list(           # every iteration, for the Tableau tab
    tableau = unname(round(h$tableau, 2)),                     # numbers only, 2 decimals
    basic_vars = I(c(h$basic_vars, "Z'"))))                    # row labels incl. objective row
  out                                                          # returned as JSON
}
