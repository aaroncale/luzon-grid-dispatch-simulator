// =====================================================================
// src/App.jsx - the whole React interface (one component)
// Flow: state -> run() calls the R API -> render sidebar, tabs, charts, tables
// =====================================================================

import { useEffect, useState, useCallback } from "react";   // React hooks: state, run-on-load, memoised function
import {                                                     // chart building blocks from the recharts library
  BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, Legend,
  AreaChart, Area, ResponsiveContainer,
} from "recharts";

// Where the R plumber API lives. Override by creating web/.env with VITE_API_URL=http://host:port
const API = import.meta.env.VITE_API_URL || "http://localhost:8000";
// All plant groups (must match PLANT_GROUPS in solver.R, same spelling)
const ALL = ["Coal", "Natural Gas", "Geothermal", "Hydro", "Oil-based", "Solar", "Wind"];
// Colour per group (used in chips, chart, table). EDIT to recolour.
const PAL = { Coal: "#64748b", "Natural Gas": "#f59e0b", Geothermal: "#ef4444", Hydro: "#38bdf8",
  "Oil-based": "#a855f7", Solar: "#facc15", Wind: "#34d399" };
// Number formatter: fmt(1234.5) -> "1,234.50"; d = number of decimals
const fmt = (n, d = 2) => Number(n).toLocaleString("en-US", { minimumFractionDigits: d, maximumFractionDigits: d });

export default function App() {
  // ---------- STATE (values that re-render the page when they change) ----------
  const [groups, setGroups] = useState(ALL);        // currently selected plant groups
  const [co2On, setCo2On] = useState(false);        // is the CO2 cap enabled?
  const [co2Limit, setCo2Limit] = useState(165000); // CO2 limit in t/day
  const [res, setRes] = useState(null);             // last result returned by the API
  const [err, setErr] = useState("");               // error message shown in red
  const [loading, setLoading] = useState(false);    // true while waiting for the API
  const [tab, setTab] = useState("results");        // active tab: "results" or "tableau"
  const [iter, setIter] = useState(0);              // iteration index shown in Tableau tab

  // ---------- RUN: send inputs to R, store the answer ----------
  const run = useCallback(async (g = groups, on = co2On, lim = co2Limit) => {
    setErr("");                                                                   // clear old error
    if (g.length === 0) return setErr("Please select at least one plant group."); // same validation as Shiny
    if (on && (!(Number(lim) > 0))) return setErr("CO2 cap limit must be a positive number.");
    setLoading(true);                                                             // show "SOLVING…"
    try {
      const r = await fetch(`${API}/solve`, {                                     // POST to the R API
        method: "POST", headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ groups: g, co2_toggle: on, co2_limit: Number(lim) }),  // inputs as JSON
      });
      const data = await r.json();                                                // parse the reply
      if (!r.ok) throw new Error(data.error || "Request failed");                 // API-side validation error
      setRes(data); setIter(data.history.length - 1);                             // save; default to the final tableau
    } catch (e) { setErr(`${e.message}. Is the R API running on ${API}?`); }      // network or API error
    setLoading(false);                                                            // hide loading state
  }, [groups, co2On, co2Limit]);

  // Run once when the page opens (mirrors the original app's behaviour)
  useEffect(() => { run(); }, []); // eslint-disable-line

  // Tick/untick one group
  const toggle = (g) => setGroups((s) => (s.includes(g) ? s.filter((x) => x !== g) : [...s, g]));
  // Restore defaults (does not re-run until RUN is pressed, same as Shiny)
  const reset = () => { setGroups(ALL); setCo2On(false); setCo2Limit(165000); };

  // ---------- DERIVED DATA for charts/tables ----------
  const optimal = res?.status === "OPTIMAL";                   // true when a solution exists
  const blocks = res?.blocks || [];                            // ["B1".."B6"]
  // Stacked-bar rows: [{block:"B1", Coal:2800, Hydro:..}, ...]
  const stack = optimal ? blocks.map((b, i) => ({ block: b, ...Object.fromEntries(res.groups.map((g) => [g, res.dispatch[g][i]])) })) : [];
  // Price rows: [{block:"B1", price:...}, ...]
  const prices = optimal ? blocks.map((b, i) => ({ block: b, price: res.block_prices[i] })) : [];
  const h = res?.history?.[iter];                              // tableau snapshot chosen in the dropdown

  return (
    <div className="layout">{/* two-column grid: sidebar + main */}

      {/* ================= SIDEBAR: controls ================= */}
      <aside className="card side">
        <h1 className="brand">⚡ Luzon Grid</h1>
        <p className="sub">Dispatch & price simulator · dual simplex</p>

        <h4>Plant groups</h4>
        {ALL.map((g) => (                                      // one clickable chip per group
          <div key={g} className={`chip ${groups.includes(g) ? "on" : ""}`} onClick={() => toggle(g)}>
            <span className="dot" style={{ background: PAL[g] }} /> {g}   {/* coloured dot + name */}
          </div>
        ))}
        <div className="row" style={{ marginTop: 8 }}>
          <button onClick={() => setGroups(ALL)}>Check all</button>   {/* select every group */}
          <button onClick={reset}>Reset</button>                      {/* back to defaults */}
        </div>

        <h4>Emissions</h4>
        <div className="switch" onClick={() => setCo2On(!co2On)}>Enable CO₂ cap <i className={co2On ? "on" : ""} /></div>
        <label className="sub" style={{ display: "block", margin: "0 0 6px" }}>Daily CO₂ limit (t/day)</label>
        <input type="number" min="1" value={co2Limit} onChange={(e) => setCo2Limit(e.target.value)} />

        <button className="run" disabled={loading} onClick={() => run()}>   {/* RUN button */}
          {loading ? "SOLVING…" : "RUN SIMULATION"}
        </button>
      </aside>

      {/* ================= MAIN AREA ================= */}
      <main>
        <div className="tabs">                                 {/* tab buttons */}
          {[["results", "Results"], ["tableau", "Simplex Tableau"]].map(([k, l]) => (
            <button key={k} className={`tab ${tab === k ? "active" : ""}`} onClick={() => setTab(k)}>{l}</button>
          ))}
        </div>
        {err && <div className="err">{err}</div>}               {/* error banner */}
        {!res && !err && <div className="card empty">Configure inputs and press RUN SIMULATION.</div>}

        {/* ---------- RESULTS TAB ---------- */}
        {res && tab === "results" && (
          <>
            {!optimal ? (                                       // infeasible message
              <div className="err">
                <span className="pill bad">INFEASIBLE</span> No solution possible. Iterations completed: {res.iterations}
              </div>
            ) : (
              <>
                <div className="kpis">                          {/* four KPI cards */}
                  <div className="kpi"><small>Status</small><b><span className="pill ok">OPTIMAL</span></b></div>
                  <div className="kpi"><small>Total minimum cost (Z)</small><b>PHP {fmt(res.Z_opt)}</b></div>
                  <div className="kpi"><small>Iterations</small><b>{res.iterations}</b></div>
                  <div className="kpi"><small>LP system setup</small><b>{res.n_vars} × {res.n_constraints}</b></div>
                </div>

                <div className="grid2">                         {/* two charts side by side */}
                  <div className="card">
                    <h3>Dispatch by block (MW)</h3>
                    <ResponsiveContainer width="100%" height={320}>   {/* auto-fit width */}
                      <BarChart data={stack}>
                        <CartesianGrid stroke="#1e293b" vertical={false} />   {/* horizontal grid lines */}
                        <XAxis dataKey="block" stroke="#94a3b8" /><YAxis stroke="#94a3b8" />
                        <Tooltip contentStyle={{ background: "#0b1424", border: "1px solid #223049" }} />  {/* hover box */}
                        <Legend />
                        {res.groups.map((g) => <Bar key={g} dataKey={g} stackId="a" fill={PAL[g]} />)}   {/* same stackId = stacked */}
                      </BarChart>
                    </ResponsiveContainer>
                  </div>
                  <div className="card">
                    <h3>Spot price per block (PHP / MWh)</h3>
                    <ResponsiveContainer width="100%" height={320}>
                      <AreaChart data={prices}>
                        <defs><linearGradient id="g" x1="0" y1="0" x2="0" y2="1">        {/* fade-out fill */}
                          <stop offset="0%" stopColor="#38bdf8" stopOpacity={0.5} /><stop offset="100%" stopColor="#38bdf8" stopOpacity={0} />
                        </linearGradient></defs>
                        <CartesianGrid stroke="#1e293b" vertical={false} />
                        <XAxis dataKey="block" stroke="#94a3b8" /><YAxis stroke="#94a3b8" />
                        <Tooltip contentStyle={{ background: "#0b1424", border: "1px solid #223049" }} />
                        <Area dataKey="price" stroke="#38bdf8" strokeWidth={3} fill="url(#g)" dot={{ r: 5, fill: "#6366f1" }} />
                      </AreaChart>
                    </ResponsiveContainer>
                  </div>
                </div>

                <div className="card" style={{ marginBottom: 16 }}>   {/* dispatch table */}
                  <h3>Optimal power dispatch x_gt (MW)</h3>
                  <table>
                    <thead><tr><th>Plant Group</th>{blocks.map((b) => <th key={b}>{b}</th>)}</tr></thead>
                    <tbody>{res.groups.map((g) => (
                      <tr key={g}><td><span className="dot" style={{ background: PAL[g], display: "inline-block", marginRight: 8 }} />{g}</td>
                        {res.dispatch[g].map((v, i) => <td key={i} className={v > 0 ? "hi" : ""}>{fmt(v)}</td>)}</tr>   {/* highlight > 0 */}
                    ))}</tbody>
                  </table>
                </div>

                <div className="card">                                {/* price table */}
                  <h3>Electricity spot prices (PHP / MWh)</h3>
                  <table>
                    <thead><tr>{blocks.map((b) => <th key={b}>{b}</th>)}</tr></thead>
                    <tbody><tr>{res.block_prices.map((p, i) => <td key={i}>{fmt(p)}</td>)}</tr></tbody>
                  </table>
                </div>
              </>
            )}
          </>
        )}

        {/* ---------- TABLEAU TAB ---------- */}
        {res && tab === "tableau" && h && (
          <div className="card">
            <div className="toolbar">
              <label>Select iteration to view tableau:</label>
              <select value={iter} onChange={(e) => setIter(Number(e.target.value))}>   {/* pick iteration */}
                {res.history.map((_, i) => <option key={i} value={i}>Iteration {i}</option>)}
              </select>
            </div>
            <div className="scroll">                              {/* scrollable wide table */}
              <table>
                <thead><tr><th>Basic Var</th>{res.columns.map((c) => <th key={c}>{c}</th>)}</tr></thead>
                <tbody>{h.tableau.map((row, r) => (
                  <tr key={r}><td>{h.basic_vars[r]}</td>{row.map((v, c) => <td key={c}>{v.toFixed(2)}</td>)}</tr>   {/* row label + numbers */}
                ))}</tbody>
              </table>
            </div>
          </div>
        )}
      </main>
    </div>
  );
}
