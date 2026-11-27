# =====================================================================
# app.R  -   SHINY USER INTERFACE
# Run with:  shiny::runApp("app.R", launch.browser = TRUE)
# Structure: libraries -> theme/CSS -> ui -> server
# =====================================================================
# Cale, Aaron Cohen D.
# 2025 - 15680
# CMSC 150 - E-5L
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
    class = "plant-chip",
    tags$span(class = "plant-ico",
              style = paste0("background:", PAL[[g]], "26;"),
              icon(PLANT_ICONS[[g]], class = "fa-fw",
                   style = paste0("color:", PAL[[g]], ";"))),
    g
  )
})


# --- THEME: global look of the app -------------------------------------
theme <- bs_theme(
  version = 5,                          # Bootstrap version
  bg = "#0a0c16", fg = "#e8eaf6",       # page background / text colour
  primary = "#b8a6f7",                  # accent colour (buttons, switches)
  secondary = "#1b1f36",                # secondary colour
  base_font = font_google("Plus Jakarta Sans"),  # body font
  heading_font = font_google("Sora"),            # heading font
  code_font = font_google("JetBrains Mono")      # monospace font (tables)
)

# --- EXTRA CSS (plain CSS pasted into the page) ------------------------
css <- "
/* design tokens: dark navy surfaces, lavender accent, lime / rose status chips */
:root{
  --bg:#0a0c16; --card:#141729; --card2:#1b1f36; --line:rgba(255,255,255,.07);
  --lav:#b8a6f7; --lav2:#8b7bea; --lime:#c6f26b; --rose:#ff7a8a;
  --muted:#8f93ad; --text:#e8eaf6;
}
/* page background: soft violet + blue glow on deep navy */
body{
  background:
    radial-gradient(900px 520px at 12% -8%,rgba(139,123,234,.26) 0%,transparent 60%),
    radial-gradient(800px 520px at 100% 0%,rgba(56,189,248,.12) 0%,transparent 55%),
    var(--bg)!important;
  background-attachment:fixed!important;
}
/* floating particle background canvas */
#particle-canvas{position:fixed;top:0;left:0;width:100vw;height:100vh;z-index:0;pointer-events:none}
/* keep layout wrappers transparent above the particle canvas */
.navbar,.container-fluid,.tab-content,.main{position:relative;z-index:1;background:transparent!important}
.container-fluid{max-width:1500px;padding-left:28px;padding-right:28px}

/* ---------- TOP BAR: logo left, pill navigation centred ---------- */
.navbar{border:0!important;padding-top:1.1rem;padding-bottom:.4rem}
.navbar>.container-fluid{position:relative;justify-content:center}
.navbar-brand{position:absolute;left:28px;margin:0}
.brand{display:flex;align-items:center;gap:.55rem;font-family:'Sora';font-weight:700;font-size:1.25rem;color:var(--text)}
.brand i{color:var(--bg);background:var(--text);border-radius:10px;padding:.42rem .5rem;font-size:.95rem}
.navbar-collapse{flex-grow:0!important}
.navbar .navbar-nav{
  background:var(--card);border:1px solid var(--line);border-radius:99px;
  padding:5px;gap:2px;flex-direction:row;
}
.navbar .nav-link{
  border-radius:99px;padding:.45rem 1.35rem!important;color:var(--muted)!important;
  font-size:.85rem;font-weight:500;border:0!important;
}
.navbar .nav-link:hover{color:var(--text)!important}
.navbar .nav-link.active{background:#fff!important;color:var(--bg)!important;font-weight:600}
.hdr-right{position:absolute;right:28px;top:50%;transform:translateY(-50%);display:flex;gap:.6rem;align-items:center}
.hdr-dot{width:40px;height:40px;border-radius:50%;display:grid;place-items:center;
  background:var(--card);border:1px solid var(--line);color:var(--text)}
.hdr-dot.avatar{background:linear-gradient(135deg,var(--lav),#f0abfc);color:var(--bg)}

/* ---------- PAGE HEADING ---------- */
.page-head{margin:1.2rem 0 1.4rem}
.page-head h1{font-family:'Sora';font-weight:600;font-size:2.6rem;letter-spacing:-.02em;margin:0 0 .5rem}
.sub{color:var(--muted);font-size:.85rem;max-width:760px;line-height:1.55}

/* ---------- HERO CARD (total minimum cost) ---------- */
.hero{
  position:relative;overflow:hidden;border-radius:28px;padding:1.6rem 1.8rem;min-height:290px;
  display:flex;flex-direction:column;justify-content:space-between;color:#0b1220;
  background:linear-gradient(115deg,#7be3b1 0%,#a7ec86 48%,#d4f26a 100%);
  transition:background .3s ease, color .3s ease;
}
.hero.hero-bad{
  background:linear-gradient(115deg,#ff7a8a 0%,#f43f5e 52%,#e11d48 100%);
  color:#fff;
}
.hero.hero-bad .pill-light{
  background:rgba(255,255,255,.92);
  color:#2a0f16;
}
.hero::after{content:'';position:absolute;right:-70px;bottom:-110px;width:380px;height:380px;border-radius:50%;
  background:rgba(255,255,255,.2);pointer-events:none}
.hero::before{content:'';position:absolute;right:90px;bottom:-190px;width:300px;height:300px;border-radius:50%;
  background:rgba(255,255,255,.12);pointer-events:none}
.hero>*{position:relative;z-index:1}
.hero-top{display:flex;justify-content:space-between;align-items:center}
.hero-label{font-family:'Sora';font-weight:500;font-size:1.15rem}
.hero-value{font-family:'Sora';font-weight:600;letter-spacing:-.02em;font-size:clamp(2rem,3.6vw,3.3rem);line-height:1.1;margin-top:.8rem}
.hero-value sup{font-size:.38em;font-weight:500;margin-left:.3rem;top:-.9em}
.hero-note{font-size:.78rem;opacity:.85;margin-top:.5rem;max-width:440px}
.hero-actions{display:flex;gap:.6rem;align-items:center;margin-top:1.4rem;flex-wrap:wrap}
.btn-pill-dark{background:#0a0c16!important;color:#fff!important;border:0!important;border-radius:99px;
  padding:.7rem 1.7rem;font-weight:600;letter-spacing:.01em}
.btn-pill-dark:hover{filter:brightness(1.35)}
.pill-light{display:inline-flex;align-items:center;gap:.45rem;background:#fff;color:#0a0c16;border-radius:99px;
  padding:.7rem 1.3rem;font-size:.85rem;font-weight:600}

/* OPTIMAL / INFEASIBLE pill */
.status-pill{display:inline-block;padding:.25rem .8rem;border-radius:99px;font-size:.72rem;font-weight:700;letter-spacing:.04em}
.ok{background:#0a0c16;color:var(--lime)}.bad{background:#2a0f16;color:var(--rose)}.idle{background:rgba(10,12,22,.12);color:#0a0c16}

/* ---------- STAT TILES (iterations / LP setup) ---------- */
.tile{background:var(--card);border:1px solid var(--line);border-radius:24px;padding:1.15rem 1.35rem;flex:1}
.tile-stack{display:flex;flex-direction:column;gap:1rem;height:100%}
.t-top{display:flex;justify-content:space-between;align-items:center}
.t-label{color:#c9ccdf;font-size:.95rem;font-weight:500}
.t-value{font-family:'Sora';font-weight:600;font-size:2rem;letter-spacing:-.02em;margin:.35rem 0 .1rem}
.t-sub{color:var(--muted);font-size:.72rem}
.chip{display:inline-block;padding:.18rem .6rem;border-radius:99px;font-size:.68rem;font-weight:700;color:#0a0c16}
.chip-lime{background:var(--lime)}.chip-lav{background:var(--lav)}

/* ---------- CARDS (sidebar panels, charts, tables) ---------- */
.card{
  background:var(--card)!important;
  border:1px solid var(--line)!important;
  border-radius:24px;
  --bs-card-bg:transparent;
  --bs-card-cap-bg:transparent;
}
.card-header,.card-body,.tab-pane{background-color:transparent!important}
.card-header{border:0!important;font-family:'Sora';font-weight:500;font-size:1.05rem;padding:1.15rem 1.35rem .35rem}
.card-body{padding:.6rem 1.35rem 1.2rem;display:flex;flex-direction:column}
.panel-hint{color:var(--muted);font-size:.75rem;margin:-.1rem 0 .8rem}
.row-gap{margin-bottom:1rem}

/* ---------- PLANT GROUP LIST (stacked-card look) ---------- */
.shiny-input-checkboxgroup .checkbox,.shiny-input-checkboxgroup .form-check{margin:0 0 .5rem;padding:0;min-height:0}
.shiny-input-checkboxgroup .checkbox label,.shiny-input-checkboxgroup .form-check label{
  display:flex;align-items:center;gap:.7rem;width:100%;padding:.6rem .8rem;margin:0;cursor:pointer;
  background:rgba(255,255,255,.035);border:1px solid var(--line);border-radius:16px;
  transition:background .15s,border-color .15s;font-weight:500;font-size:.9rem;
}
.shiny-input-checkboxgroup label:has(input:checked){background:rgba(184,166,247,.11);border-color:rgba(184,166,247,.5)}
.shiny-input-checkboxgroup label input[type=checkbox]{
  order:2;margin:0 0 0 auto!important;float:none!important;position:static!important;
  accent-color:var(--lav);width:1.05rem;height:1.05rem;flex:none;
}
.plant-chip{display:flex;align-items:center;gap:.7rem;order:1}
.plant-ico{width:34px;height:34px;border-radius:50%;display:grid;place-items:center;flex:none}
.btn-soft{background:#fff!important;color:var(--bg)!important;border:0!important;border-radius:99px;font-weight:600;font-size:.8rem;padding:.4rem 1rem}
.btn-ghost{background:transparent!important;color:var(--text)!important;border:1px solid var(--line)!important;border-radius:99px;font-size:.8rem;padding:.4rem 1rem}
.btn-ghost:hover{background:rgba(255,255,255,.06)!important}

/* ---------- FORM CONTROLS ---------- */
.form-control,.form-select,.selectize-input,.selectize-dropdown{
  background:var(--card2)!important;color:var(--text)!important;border:1px solid var(--line)!important;border-radius:14px!important;
}
.selectize-dropdown .active{background:rgba(184,166,247,.18)!important;color:var(--text)!important}
.selectize-input>div,.selectize-input input{color:var(--text)!important}
.form-label,label.control-label{color:#c9ccdf;font-size:.82rem;font-weight:500}
.form-check-input:checked{background-color:var(--lav);border-color:var(--lav)}

/* ---------- TABLES (FULL-WIDTH STRETCH) ---------- */
.table-scroll{overflow-x:auto;width:100%;flex:1;display:flex;flex-direction:column;justify-content:center}
.table-scroll .shiny-html-output{width:100%}
.table-scroll table{
  font-family:inherit;font-variant-numeric:tabular-nums;font-size:.85rem;
  color:var(--text)!important;width:100%!important;table-layout:fixed;margin-bottom:0!important;
}
.table>:not(caption)>*>*{background:transparent!important;color:var(--text)!important;border-color:var(--line)!important;padding:.72rem .5rem}
.table thead th{color:var(--muted)!important;font-weight:600;font-size:.78rem}

/* Dispatch table: first column wider for plant names, left-aligned */
.dispatch-tbl table th:first-child,
.dispatch-tbl table td:first-child{width:24%;text-align:left!important;padding-left:.4rem}
.dispatch-tbl table tbody td:first-child{font-weight:600}

/* Price table: equal-width columns across the full card, larger readable text */
.price-tbl table th,
.price-tbl table td{text-align:center!important;padding:.85rem .5rem}
.price-tbl table tbody td{font-size:1.05rem;font-weight:600;color:var(--lav)!important}
.price-tbl table tbody td:first-child{text-align:center!important}

/* Tableau table: keep auto layout so wide horizontal scrolling works normally */
#tableau_table table{width:max-content!important;min-width:100%;table-layout:auto;font-size:.8rem}
#tableau_table table tbody td:first-child{font-weight:600;text-align:left!important}

/* ---------- SIMPLEX TABLEAU CONTROLS ---------- */
.btn-circ{background:var(--card2)!important;color:var(--text)!important;border:1px solid var(--line)!important;border-radius:99px;padding:.5rem 1.1rem}
.btn-circ:hover{background:rgba(184,166,247,.2)!important}

/* hide up/down arrows on the CO2 limit input */
#co2_limit::-webkit-outer-spin-button,
#co2_limit::-webkit-inner-spin-button{-webkit-appearance:none;margin:0}
#co2_limit{-moz-appearance:textfield}

/* Custom auto-hiding black & lavender scrollbars */
* {
  scrollbar-width: thin;
  scrollbar-color: transparent transparent;
}
*.is-scrolling, *:hover {
  scrollbar-color: #b8a6f7 #0a0c16;
}
::-webkit-scrollbar {
  width: 7px;
  height: 7px;
}
::-webkit-scrollbar-track,
::-webkit-scrollbar-corner {
  background: #0a0c16;
}
::-webkit-scrollbar-thumb {
  background: transparent;
  border-radius: 99px;
}
.is-scrolling::-webkit-scrollbar-thumb,
::-webkit-scrollbar-thumb:hover,
::-webkit-scrollbar-thumb:active {
  background: linear-gradient(180deg, #b8a6f7, #8b7bea);
}

/* small screens: stack the top bar */
@media (max-width: 991px){
  .navbar-brand,.hdr-right{position:static;transform:none}
  .navbar>.container-fluid{justify-content:space-between}
  .page-head h1{font-size:1.9rem}
}
"

# --- USER INTERFACE -----------------------------------------------------
ui <- page_navbar(                                    # page = top pill navigation + full-width dashboard
  title = div(class = "brand", icon("bolt"), "PikaChoose"),   # logo text (top left)
  id = "main_nav", window_title = "Luzon Grid Dispatch & Price Simulator",
  theme = theme, fillable = FALSE,                    # apply theme; let the page scroll normally
  header = tagList(
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

      // Floating particles background animation
      $(function() {
        const canvas = document.getElementById('particle-canvas');
        if (!canvas) return;
        const ctx = canvas.getContext('2d');

        let particles = [];
        const particleCount = 55;
        const colors = [
          'rgba(56, 189, 248, ',  // Sky blue (#38bdf8)
          'rgba(99, 102, 241, ',  // Indigo (#6366f1)
          'rgba(52, 211, 153, ',  // Emerald (#34d399)
          'rgba(250, 204, 21, '   // Solar yellow (#facc15)
        ];

        function resizeCanvas() {
          canvas.width = window.innerWidth;
          canvas.height = window.innerHeight;
        }
        window.addEventListener('resize', resizeCanvas);
        resizeCanvas();

        class Particle {
          constructor() {
            this.reset(true);
          }
          reset(initial = false) {
            this.x = Math.random() * canvas.width;
            this.y = initial ? Math.random() * canvas.height : canvas.height + 10;
            this.radius = Math.random() * 2.2 + 0.8;
            this.speedY = -(Math.random() * 0.45 + 0.15);
            this.speedX = (Math.random() - 0.5) * 0.3;
            this.alpha = Math.random() * 0.5 + 0.15;
            this.colorBase = colors[Math.floor(Math.random() * colors.length)];
          }
          update() {
            this.x += this.speedX;
            this.y += this.speedY;
            if (this.y < -10 || this.x < -10 || this.x > canvas.width + 10) {
              this.reset(false);
            }
          }
          draw() {
            ctx.beginPath();
            ctx.arc(this.x, this.y, this.radius, 0, Math.PI * 2);
            ctx.fillStyle = this.colorBase + this.alpha + ')';
            ctx.shadowBlur = 8;
            ctx.shadowColor = this.colorBase + '0.6)';
            ctx.fill();
          }
        }

        for (let i = 0; i < particleCount; i++) {
          particles.push(new Particle());
        }

        function animate() {
          ctx.clearRect(0, 0, canvas.width, canvas.height);
          for (let p of particles) {
            p.update();
            p.draw();
          }
          requestAnimationFrame(animate);
        }
        animate();
      });
    "))
    ),
    
    # Background particle layer
    tags$canvas(id = "particle-canvas"),
    
    # Top-right round icons (decorative, like the search / bell / avatar in the design)
    div(class = "hdr-right",
        div(class = "hdr-dot", icon("magnifying-glass")),
        div(class = "hdr-dot", icon("bell")),
        div(class = "hdr-dot avatar", icon("bolt")))
  ),
  
  nav_panel("Dashboard",                              # TAB 1 (was "Results")
            div(class = "page-head",
                h1("Luzon Grid Dispatch & Price Simulator"),
                div(class = "sub", "Find the cheapest way to power Luzon across all six 4-hour blocks of the day. Turn different power plants on or off, add a carbon emissions limit, and see the lowest-cost energy mix and electricity prices update for each 4-hour window.")),   # subtitle
            
            layout_columns(col_widths = c(9, 3), fill = FALSE,   # main area (left) + control panels (right)
                           
                           # ---------------- LEFT: results ----------------
                           div(
                             layout_columns(col_widths = c(7, 5), fill = FALSE, class = "row-gap",   # hero card + two stat tiles
                                            uiOutput("hero_card"),                                 # dynamically green (OPTIMAL) or red (INFEASIBLE)
                                            uiOutput("side_kpis")),                                # iterations + LP setup tiles
                             
                             uiOutput("results_section")                                           # hidden automatically when INFEASIBLE
                           ),
                           
                           # ---------------- RIGHT: control panels (were the sidebar) ----------------
                           div(
                             card(card_header(span("Plant groups")),
                                  div(class = "panel-hint", "Tick the plants that are allowed to generate."),
                                  checkboxGroupInput("selected_groups", NULL,     # id read in server as input$selected_groups
                                                     choiceNames = plant_choice_names, choiceValues = PLANT_GROUPS, selected = PLANT_GROUPS),      # all ticked by default
                                  div(class = "d-flex gap-2",                  # two small buttons side by side
                                      actionButton("btn_check_all", "Check all", class = "btn-soft"),
                                      actionButton("btn_reset", "Reset", class = "btn-ghost"))),
                             card(card_header("Carbon emissions"),
                                  input_switch("co2_toggle", "Enable CO₂ cap", value = FALSE),    # on/off switch
                                  numericInput("co2_limit", "Daily CO₂ limit (t/day)", value = 165000, min = 1))  # cap value
                           )
            )),
  
  nav_panel("Simplex Tableau",                        # TAB 2
            div(class = "page-head",
                h1("Simplex Tableau"),
                div(class = "sub", "Step through every iteration of the dual simplex solver. Use the Prev and Next buttons or the left and right arrow keys.")),
            card(
              uiOutput("iter_selector_ui"),           # Prev / dropdown / Next built in server
              div(style = "overflow:auto;max-height:560px", tableOutput("tableau_table"))))  # scrollable table
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
  
  # Small helper that builds one stat tile (label, big value, small caption, optional chip)
  tile <- function(title, value, sub, chip = NULL, chip_class = "chip-lime")
    div(class = "tile",
        div(class = "t-top", span(class = "t-label", title),
            if (!is.null(chip)) span(class = paste("chip", chip_class), chip)),
        div(class = "t-value", value),
        div(class = "t-sub", sub))
  
  # Hero card container (switches to red when INFEASIBLE)
  output$hero_card <- renderUI({
    res <- sim_results()
    is_bad <- !is.null(res) && res$status == "INFEASIBLE"
    div(
      class = if (is_bad) "hero hero-bad" else "hero",
      div(
        class = "hero-top",
        span(class = "hero-label", "Total minimum cost (Z)"),
        uiOutput("hero_status", inline = TRUE)
      ),
      div(uiOutput("hero_value"), uiOutput("hero_note")),
      div(
        class = "hero-actions",
        actionButton("btn_run", "Run simulation", icon = icon("play"), class = "btn-pill-dark"),
        span(class = "pill-light", icon("clock"), "6 blocks · 4 h each")
      )
    )
  })
  
  # Status pill in the corner of the hero card
  output$hero_status <- renderUI({
    res <- sim_results()                              # latest solver output
    if (is.null(res)) return(span(class = "status-pill idle", "READY"))
    if (res$status == "INFEASIBLE") return(span(class = "status-pill bad", "INFEASIBLE"))
    span(class = "status-pill ok", "OPTIMAL")
  })
  
  # Big number on the hero card: total minimum cost
  output$hero_value <- renderUI({
    res <- sim_results()
    if (is.null(res)) return(div(class = "hero-value", "—"))
    if (res$status == "INFEASIBLE") return(div(class = "hero-value", "Infeasible"))
    div(class = "hero-value",
        formatC(res$Z_opt, format = "f", digits = 2, big.mark = ","),
        tags$sup("PHP"))
  })
  
  # Small caption under the hero number (also carries the infeasible message)
  output$hero_note <- renderUI({
    res <- sim_results()
    if (is.null(res)) return(div(class = "hero-note", "Configure inputs and press RUN SIMULATION."))
    if (res$status == "INFEASIBLE")
      return(div(class = "hero-note", paste("Iterations completed:", res$iterations)))
    div(class = "hero-note", "Lowest total cost of generating Luzon's demand across the day.")
  })
  
  # Two stacked tiles beside the hero card: iterations + linear programming setup
  output$side_kpis <- renderUI({
    res <- sim_results()
    if (is.null(res))
      return(div(class = "tile-stack",
                 tile("Iterations", "—", "pivots performed"),
                 tile("Linear Programming setup", "—", "unknowns · constraints")))
    div(class = "tile-stack",
        tile("Iterations", res$iterations, "pivots performed",
             chip = if (res$status == "INFEASIBLE") "stopped" else "done",
             chip_class = if (res$status == "INFEASIBLE") "chip-lav" else "chip-lime"),
        tile("Linear Programming setup", sprintf("%d unknowns", res$n_vars),
             sprintf("%d constraints", res$n_constraints), chip = "LP", chip_class = "chip-lav"))
  })
  
  ok <- function(res) !is.null(res) && res$status != "INFEASIBLE"   # TRUE when there is a usable solution
  
  # Charts and tables container: only renders when a feasible OPTIMAL solution exists
  output$results_section <- renderUI({
    res <- sim_results()
    req(ok(res))
    tagList(
      layout_columns(col_widths = c(7, 5), fill = FALSE, class = "row-gap",   # row of two cards, 7/12 and 5/12 wide
                     card(card_header("Dispatch by block (MW)"), plotlyOutput("dispatch_plot", height = 340)),
                     card(card_header("Energy mix of the day"), plotlyOutput("mix_plot", height = 340))),
      
      layout_columns(col_widths = c(5, 7), fill = FALSE, class = "row-gap",   # price chart + unknowns table
                     card(card_header("Spot price per block (PHP / MWh)"), plotlyOutput("price_plot", height = 355)),
                     card(card_header("Unknowns x_gt (MW)"),
                          div(class = "table-scroll dispatch-tbl", tableOutput("dispatch_table")))),
      
      card(card_header("Prices of the demand constraints (PHP / MWh)"),
           div(class = "table-scroll price-tbl", tableOutput("price_table")))
    )
  })
  
  # Shared dark styling applied to every plotly chart
  dark <- function(p) p |> layout(paper_bgcolor = "rgba(0,0,0,0)", plot_bgcolor = "rgba(0,0,0,0)",  # transparent
                                  font = list(color = "#cbd5e1"), legend = list(orientation = "h", y = -0.2),
                                  xaxis = list(gridcolor = "rgba(255,255,255,.06)"), yaxis = list(gridcolor = "rgba(255,255,255,.06)")) |>
    config(displayModeBar = FALSE)                    # hide plotly's toolbar
  
  # Stacked bar chart: one bar per block, one colour per group
  output$dispatch_plot <- renderPlotly({
    res <- sim_results(); req(ok(res)); m <- dispatch_matrix(res)   # groups x blocks matrix
    p <- plot_ly()                                    # empty chart
    for (g in res$groups) p <- add_bars(p, x = BLOCKS, y = round(m[g, ], 2), name = g,
                                        marker = list(color = PAL[[g]]))   # add one series per group
    p |> layout(barmode = "stack", bargap = 0.3) |> dark()          # stack them and apply theme
  })
  
  # Donut chart: share of the day's energy (MWh) produced by each group, total in the centre
  output$mix_plot <- renderPlotly({
    res <- sim_results(); req(ok(res)); m <- dispatch_matrix(res)
    e <- rowSums(m) * HOURS                           # MWh per group over the whole day
    keep <- e > 0.5                                   # hide groups that dispatch nothing
    plot_ly(labels = res$groups[keep], values = round(e[keep], 2), type = "pie", hole = 0.68,
            sort = FALSE, textinfo = "none", hoverinfo = "label+percent+value",
            marker = list(colors = unname(PAL[res$groups[keep]]),
                          line = list(color = "#141729", width = 3))) |>
      layout(paper_bgcolor = "rgba(0,0,0,0)", plot_bgcolor = "rgba(0,0,0,0)",
             font = list(color = "#cbd5e1"),
             legend = list(orientation = "h", y = -0.12),
             margin = list(t = 10, b = 40),
             annotations = list(list(text = paste0("<b>Total</b><br>", formatC(sum(e), format = "f", digits = 0, big.mark = ","), " MWh"),
                                     showarrow = FALSE, x = 0.5, y = 0.5, font = list(size = 15, color = "#e8eaf6")))) |>
      config(displayModeBar = FALSE)
  })
  
  # Price line/area chart
  output$price_plot <- renderPlotly({
    res <- sim_results(); req(ok(res))
    plot_ly(x = BLOCKS, y = round(res$block_prices, 2), type = "scatter", mode = "lines+markers",
            fill = "tozeroy", fillcolor = "rgba(184,166,247,.16)",       # shaded area under the line
            line = list(color = "#b8a6f7", width = 3), marker = list(size = 9, color = "#ffffff")) |> dark()
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
  }, align = "c", striped = TRUE, hover = TRUE, width = "100%")
  
  # One-row price table
  output$price_table <- renderTable({
    res <- sim_results(); if (!ok(res)) return(NULL)
    df <- data.frame(matrix(format(round(res$block_prices, 2), big.mark = ","), nrow = 1))
    colnames(df) <- BLOCKS; df
  }, align = "c", width = "100%")
  
  # Dropdown + circular Prev/Next buttons (starts on the Final tableau)
  output$iter_selector_ui <- renderUI({
    res <- sim_results(); if (is.null(res)) return(NULL)
    n <- length(res$history)
    labels <- paste("Iteration", 0:(n - 1))
    labels[1] <- "Iteration 0 (Initial)"
    labels[n] <- paste0(labels[n], " (Final)")
    
    div(class = "d-flex align-items-end gap-2",
        actionButton("btn_prev_iter", "Prev", icon = icon("chevron-left"), class = "btn-circ mb-3"),
        selectInput("selected_iter", "Select iteration to view tableau:",
                    choices = setNames(1:n, labels), selected = n),
        actionButton("btn_next_iter", "Next", icon = icon("chevron-right"), class = "btn-circ mb-3"))
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