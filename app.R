# =====================================================================
# app.R  -  ADVANCED SHINY USER INTERFACE
# Run with:  shiny::runApp("app.R", launch.browser = TRUE)
# Structure: libraries -> theme/CSS -> ui -> server
# =====================================================================

library(shiny)    # core web framework
library(bslib)    # Bootstrap 5 theming + modern layout helpers (value_box, cards, sidebar)
library(plotly)   # interactive charts

source("solver.R")   # loads constants + solve_dual_simplex() + dispatch_matrix()

# Colour per plant group, used by the stacked bar chart. EDIT hex codes to recolour.
PAL <- c(Coal = "#64748b", "Natural Gas" = "#f59e0b", Geothermal = "#ef4444",
         Hydro = "#38bdf8", "Oil-based" = "#a855f7", Solar = "#facc15", Wind = "#34d399")

# Font Awesome icon per plant group. EDIT names to change icons.
PLANT_ICONS <- c(
  Coal = "cubes",
  "Natural Gas" = "fire",
  Geothermal = "volcano",
  Hydro = "droplet",
  "Oil-based" = "oil-can",
  Solar = "sun",
  Wind = "wind"
)

# Build icon + text labels for the sidebar checkboxes
plant_choice_names <- lapply(PLANT_GROUPS, function(g) {
  tags$span(
    icon(PLANT_ICONS[[g]], class = "fa-fw",
         style = paste0("color:", PAL[[g]], "; margin-right:6px;")),
    g
  )
})


# --- THEME: global look of the app -------------------------------------
theme <- bs_theme(
  version = 5,                          # Bootstrap version
  bg = "#0b1220", fg = "#e2e8f0",       # page background / text colour
  primary = "#38bdf8",                  # accent colour (buttons, switches)
  secondary = "#1e293b",                # secondary colour
  base_font = font_google("Inter"),             # body font
  heading_font = font_google("Space Grotesk"),  # heading font
  code_font = font_google("JetBrains Mono")     # monospace font (tables)
)

# --- EXTRA CSS (plain CSS pasted into the page) ------------------------
css <- "
/* page background gradient */
body{background:radial-gradient(1200px 600px at 10% -10%,#12263f 0%,#0b1220 55%)!important}
/* translucent rounded cards and sidebar */
.card,.bslib-sidebar-layout>.sidebar{background:rgba(17,26,43,.85)!important;border:1px solid #223049!important;border-radius:14px}
/* title bar with icon */
.brand{display:flex;align-items:center;gap:.6rem;font-family:'Space Grotesk';font-weight:700;font-size:3.15rem}
.brand i{color:#38bdf8}.sub{color:#94a3b8;font-size:.8rem;margin-bottom:1rem;text-align:justify}
/* RUN button: full width gradient */
.btn-run{width:100%;font-weight:600;letter-spacing:.05em;background:linear-gradient(90deg,#0ea5e9,#6366f1);border:0}
.btn-run:hover{filter:brightness(1.12)}
/* KPI boxes */
.bslib-value-box{background:linear-gradient(135deg,#13233c,#0f1a2e)!important;border:1px solid #223049!important}
/* OPTIMAL / INFEASIBLE pill */
.status-pill{display:inline-block;padding:.2rem .7rem;border-radius:99px;font-size:.75rem;font-weight:600}
.ok{background:#064e3b;color:#6ee7b7}.bad{background:#7f1d1d;color:#fca5a5}
/* tables: monospace, transparent so they blend with the dark cards */
table{font-family:'JetBrains Mono';font-size:.78rem;color:#e2e8f0!important}
.table>:not(caption)>*>*{background:transparent!important;color:#e2e8f0!important;border-color:#1e293b!important}
.form-check-input:checked{background-color:#38bdf8;border-color:#38bdf8}

.form-check-input:checked{background-color:#38bdf8;border-color:#38bdf8}
/* hide up/down arrows on the CO2 limit input */
#co2_limit::-webkit-outer-spin-button,
#co2_limit::-webkit-inner-spin-button{-webkit-appearance:none;margin:0}
#co2_limit{-moz-appearance:textfield}

/* Custom auto-hiding black & blue scrollbars */
* {
  scrollbar-width: thin;
  scrollbar-color: transparent transparent;
}
*.is-scrolling, *:hover {
  scrollbar-color: #38bdf8 #0b1220;
}
::-webkit-scrollbar {
  width: 7px;
  height: 7px;
}
::-webkit-scrollbar-track,
::-webkit-scrollbar-corner {
  background: #0b1220;
}
::-webkit-scrollbar-thumb {
  background: transparent;
  border-radius: 99px;
}
.is-scrolling::-webkit-scrollbar-thumb,
::-webkit-scrollbar-thumb:hover,
::-webkit-scrollbar-thumb:active {
  background: linear-gradient(180deg, #38bdf8, #0ea5e9);
}
"

# --- USER INTERFACE -----------------------------------------------------
ui <- page_sidebar(                                   # page = left sidebar + main area
  title = div(class = "brand", icon("bolt"), "Luzon Grid Dispatch & Price Simulator"),  # header text
  theme = theme, fillable = FALSE,                    # apply theme; let the page scroll normally
  tags$head(
    tags$style(HTML(css)),                            # inject the CSS string above
    tags$script(HTML("
      $(document).on('keydown', function(e) {
        // Let arrow keys navigate normally if the dropdown menu is currently open
        if ($('.selectize-dropdown:visible').length) return;

        if (e.key === 'Enter') {
          if (e.target.tagName === 'BUTTON') return;
          e.preventDefault();
          if (document.activeElement) $(document.activeElement).trigger('change');
          setTimeout(function() { $('#btn_run').click(); }, 50);
        } else if (e.key === 'ArrowLeft' || e.key === 'ArrowRight') {
          // Keep normal left/right cursor movement when typing inside the CO2 input
          if ($(e.target).is('input, textarea') && !$(e.target).closest('.selectize-input').length) return;

          // Only fire when the Simplex Tableau tab is active
          var $prev = $('#btn_prev_iter');
          var $next = $('#btn_next_iter');
          if ($prev.length && $prev.closest('.tab-pane').hasClass('active')) {
            e.preventDefault();
            if (e.key === 'ArrowLeft') $prev.click();
            if (e.key === 'ArrowRight') $next.click();
          }
        }
      });
    "))
  ),
  
  sidebar = sidebar(                                  # ---- left control panel ----
    width = 330,                                      # sidebar width in pixels
    div(class = "sub", "Find the cheapest way to power Luzon across all six 4-hour blocks of the day. Turn different power plants on or off, add a carbon emissions limit, and see the lowest-cost energy mix and electricity prices update for each 4-hour window."),   # subtitle
    checkboxGroupInput("selected_groups", "Plant groups",     # id read in server as input$selected_groups
                       choiceNames = plant_choice_names, choiceValues = PLANT_GROUPS, selected = PLANT_GROUPS),      # all ticked by default
    div(class = "d-flex gap-2 mb-3",                  # two small buttons side by side
        actionButton("btn_check_all", "Check all", class = "btn-sm btn-outline-info"),
        actionButton("btn_reset", "Reset", class = "btn-sm btn-outline-secondary")),
    hr(),                                             # divider line
    input_switch("co2_toggle", "Enable CO₂ cap", value = FALSE),    # on/off switch
    numericInput("co2_limit", "Daily CO₂ limit (t/day)", value = 165000, min = 1),  # cap value
    hr(),
    actionButton("btn_run", "RUN SIMULATION", icon = icon("play"), class = "btn-run btn-primary")
  ),
  
  navset_card_tab(                                    # ---- main area with two tabs ----
    nav_panel("Results",                              # TAB 1
              uiOutput("kpis"), br(),                 # KPI cards (built in server)
              layout_columns(col_widths = c(7, 5),    # row of two cards, 7/12 and 5/12 wide
                             card(card_header("Dispatch by block (MW)"), plotlyOutput("dispatch_plot", height = 340)),
                             card(card_header("Spot price per block (PHP / MWh)"), plotlyOutput("price_plot", height = 340))),
              layout_columns(col_widths = c(8, 4),    # second row: tables
                             card(card_header("Optimal dispatch x_gt (MW)"), tableOutput("dispatch_table")),
                             card(card_header("Electricity spot prices (PHP / MWh)"), tableOutput("price_table")))),
    nav_panel("Simplex Tableau",                      # TAB 2
              uiOutput("iter_selector_ui"),           # Prev / dropdown / Next built in server
              div(style = "overflow:auto;max-height:560px", tableOutput("tableau_table")))  # scrollable table
  )
)

# --- SERVER ----------------------------------------------------------------
server <- function(input, output, session) {
  
  # "Check all" button: re-tick every plant group
  observeEvent(input$btn_check_all, {
    updateCheckboxGroupInput(session, "selected_groups", selected = PLANT_GROUPS)
  })
  
  # "Reset" button: uncheck all plant groups and restore CO2 defaults
  observeEvent(input$btn_reset, {
    updateCheckboxGroupInput(session, "selected_groups", selected = character(0))  # uncheck all
    update_switch("co2_toggle", value = FALSE, session = session)                   # CO2 off
    updateNumericInput(session, "co2_limit", value = 165000)                        # default limit
  })
  
  # Runs the solver only when RUN is clicked (and once at startup because ignoreNULL = FALSE)
  sim_results <- eventReactive(input$btn_run, {
    if (length(input$selected_groups) == 0) {
      showNotification("Please select at least one plant group.", type = "error")
      return(NULL)
    }
    if (input$co2_toggle && (is.na(input$co2_limit) || input$co2_limit <= 0)) {
      showNotification("CO2 cap limit must be a positive number.", type = "error")
      return(NULL)
    }
    solve_dual_simplex(input$selected_groups, input$co2_toggle, input$co2_limit)
  }, ignoreNULL = FALSE)
  
  # Small helper that builds one KPI card
  kpi <- function(title, value, icon_name) value_box(title, value, showcase = icon(icon_name))
  
  # Top KPI row / infeasible alert
  output$kpis <- renderUI({
    res <- sim_results()                              # latest solver output
    if (is.null(res)) return(tags$p("Configure inputs and press RUN SIMULATION."))
    if (res$status == "INFEASIBLE")                   # red alert for infeasible runs
      return(div(class = "alert alert-danger",
                 span(class = "status-pill bad", "INFEASIBLE"),
                 p(class = "mt-2 mb-0", paste("Iterations completed:", res$iterations))))
    layout_columns(col_widths = c(5,7,5,7), fill = FALSE,                      # four KPI cards
                   kpi("Status", span(class = "status-pill ok", "OPTIMAL"), "circle-check"),
                   kpi("Total minimum cost (Z)",
                       sprintf("PHP %s", formatC(res$Z_opt, format = "f", digits = 2, big.mark = ",")),
                       "peso-sign"),
                   kpi("Iterations", res$iterations, "rotate"),
                   kpi("Linear Programming setup", sprintf("%d unknowns · %d constraints", res$n_vars, res$n_constraints), "table-cells"))
  })
  
  ok <- function(res) !is.null(res) && res$status != "INFEASIBLE"   # TRUE when there is a usable solution
  
  # Shared dark styling applied to every plotly chart
  dark <- function(p) p |> layout(paper_bgcolor = "rgba(0,0,0,0)", plot_bgcolor = "rgba(0,0,0,0)",  # transparent
                                  font = list(color = "#cbd5e1"), legend = list(orientation = "h", y = -0.2),
                                  xaxis = list(gridcolor = "#1e293b"), yaxis = list(gridcolor = "#1e293b")) |>
    config(displayModeBar = FALSE)                    # hide plotly's toolbar
  
  # Stacked bar chart: one bar per block, one colour per group
  output$dispatch_plot <- renderPlotly({
    res <- sim_results(); req(ok(res)); m <- dispatch_matrix(res)   # groups x blocks matrix
    p <- plot_ly()                                    # empty chart
    for (g in res$groups) p <- add_bars(p, x = BLOCKS, y = round(m[g, ], 2), name = g,
                                        marker = list(color = PAL[[g]]))   # add one series per group
    p |> layout(barmode = "stack") |> dark()          # stack them and apply theme
  })
  
  # Price line/area chart
  output$price_plot <- renderPlotly({
    res <- sim_results(); req(ok(res))
    plot_ly(x = BLOCKS, y = round(res$block_prices, 2), type = "scatter", mode = "lines+markers",
            fill = "tozeroy", fillcolor = "rgba(56,189,248,.15)",       # shaded area under the line
            line = list(color = "#38bdf8", width = 3), marker = list(size = 9, color = "#6366f1")) |> dark()
  })
  
  # Dispatch table
  output$dispatch_table <- renderTable({
    res <- sim_results(); if (!ok(res)) return(NULL)
    df <- data.frame(Plant_Group = res$groups)        # first column = group names
    for (b in BLOCKS) {                               # one column per block
      vals <- sapply(res$groups, function(g) { v <- res$primal_x[[paste0("x_", g, "_", b)]]; if (is.null(v)) 0 else v })
      df[[b]] <- format(round(vals, 2), big.mark = ",")   # 2 decimals + thousands separator
    }
    colnames(df)[1] <- "Plant Group"                  # nicer header
    df
  }, align = "c", striped = TRUE, hover = TRUE)
  
  # One-row price table
  output$price_table <- renderTable({
    res <- sim_results(); if (!ok(res)) return(NULL)
    df <- data.frame(matrix(format(round(res$block_prices, 2), big.mark = ","), nrow = 1))
    colnames(df) <- BLOCKS; df
  }, align = "c")
  
  # Dropdown + circular Prev/Next buttons (starts on the Final tableau)
  output$iter_selector_ui <- renderUI({
    res <- sim_results(); if (is.null(res)) return(NULL)
    n <- length(res$history)
    labels <- paste("Iteration", 0:(n - 1))
    labels[1] <- "Iteration 0 (Initial)"
    labels[n] <- paste0(labels[n], " (Final)")
    
    div(class = "d-flex align-items-end gap-2",
        actionButton("btn_prev_iter", "Prev", icon = icon("chevron-left"), class = "btn-outline-info mb-3"),
        selectInput("selected_iter", "Select iteration to view tableau:",
                    choices = setNames(1:n, labels), selected = n),
        actionButton("btn_next_iter", "Next", icon = icon("chevron-right"), class = "btn-outline-info mb-3"))
  })
  
  # Next button: Final -> Iteration 0 -> Iteration 1 -> ... -> Final (loops endlessly)
  observeEvent(input$btn_next_iter, {
    res <- sim_results(); req(res, input$selected_iter)
    n <- length(res$history)
    curr <- as.numeric(input$selected_iter)
    next_idx <- if (curr >= n) 1 else curr + 1
    updateSelectInput(session, "selected_iter", selected = next_idx)
  })
  
  # Prev button: Final -> ... -> Iteration 1 -> Iteration 0 -> Final (loops endlessly)
  observeEvent(input$btn_prev_iter, {
    res <- sim_results(); req(res, input$selected_iter)
    n <- length(res$history)
    curr <- as.numeric(input$selected_iter)
    prev_idx <- if (curr <= 1) n else curr - 1
    updateSelectInput(session, "selected_iter", selected = prev_idx)
  })
  
  # Show the chosen tableau
  output$tableau_table <- renderTable({
    res <- sim_results(); req(input$selected_iter); if (is.null(res)) return(NULL)
    h <- res$history[[as.numeric(input$selected_iter)]]            # chosen snapshot
    df <- as.data.frame(h$tableau); df[] <- lapply(df, function(col) sprintf("%.2f", col))  # 2-decimals text
    df <- cbind(Basic_Var = c(h$basic_vars, "Z'"), df)             # first column = basic variable of each row
    colnames(df)[1] <- "Basic Var"; df
  }, align = "c", striped = TRUE, hover = TRUE, bordered = TRUE)
}

shinyApp(ui, server)                                  # launches the app