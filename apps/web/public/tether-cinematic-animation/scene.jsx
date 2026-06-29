// scene.jsx — Tether agent-debug cinematic. Self-contained: engine + scenes.
// Exports window.TetherAnim (a full <Stage> with the 12s choreography).

const clamp = (v, lo, hi) => Math.max(lo, Math.min(hi, v));

const Easing = {
  linear: (t) => t,
  easeOutCubic: (t) => 1 - Math.pow(1 - t, 3),
  easeInCubic: (t) => t * t * t,
  easeInOutCubic: (t) => (t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2),
  easeOutQuad: (t) => t * (2 - t),
  // Apple spring overshoot — cubic-bezier(0.34,1.56,0.64,1)-ish
  spring: (t) => {
    const c1 = 1.70158, c3 = c1 + 1;
    return 1 + c3 * Math.pow(t - 1, 3) + c1 * Math.pow(t - 1, 2);
  },
};

function interpolate(input, output, ease = Easing.linear) {
  return (t) => {
    if (t <= input[0]) return output[0];
    if (t >= input[input.length - 1]) return output[output.length - 1];
    for (let i = 0; i < input.length - 1; i++) {
      if (t >= input[i] && t <= input[i + 1]) {
        const span = input[i + 1] - input[i];
        const local = span === 0 ? 0 : (t - input[i]) / span;
        const e = Array.isArray(ease) ? ease[i] || Easing.linear : ease;
        return output[i] + (output[i + 1] - output[i]) * e(local);
      }
    }
    return output[output.length - 1];
  };
}

const TL = React.createContext({ time: 0, duration: 12 });
const useTime = () => React.useContext(TL).time;
const useTL = () => React.useContext(TL);

// ── Fonts / palette ──────────────────────────────────────────────────────────
const MONO = "'JetBrains Mono','SF Mono',ui-monospace,SFMono-Regular,monospace";
const SANS = "-apple-system,'SF Pro Display','SF Pro Text',system-ui,sans-serif";
const C = {
  green: "#10a37f",
  blue: "#3b82f6",
  red: "#e5484d",
  amber: "#d97706",
  violet: "#6d5ef0",
  bgOuter: "#e8e8ec",
  bgWindow: "#ffffff",
  bgCard: "#ffffff",
  bgSubtle: "#f6f6f9",
  border: "rgba(0,0,0,0.09)",
  borderStrong: "rgba(0,0,0,0.14)",
  textHi: "#1a1a22",
  textMid: "rgba(0,0,0,0.55)",
  textLo: "rgba(0,0,0,0.38)",
  cardShadow: "0 1px 3px rgba(0,0,0,0.06), 0 1px 1px rgba(0,0,0,0.03)",
};

// slide-in helper -> {opacity, ty}
function slide(t, start, dur = 0.42) {
  const lin = clamp((t - start) / dur, 0, 1);
  const sp = Easing.spring(lin);
  return { opacity: lin, ty: (1 - sp) * 22 };
}

// ── Node data ─────────────────────────────────────────────────────────────────
const NODES = [
  { id: "plan.decompose",   color: C.green, model: "claude-sonnet-4.5", lat: "0.42s", appear: 0.45 },
  { id: "retrieve.search",  color: C.blue,  model: "gpt-4o-mini",       lat: "0.88s", appear: 0.73 },
  { id: "tool.call_weather",color: C.red,   model: "gpt-4o",            lat: "0.61s", appear: 1.01, broken: true },
  { id: "patch.output",     color: C.amber, model: "replay branch",     lat: "0.48s", appear: 1.29 },
];
const NODE5 = { id: "repair.result", color: C.green, model: "patched response applied", lat: "0.31s", appear: 9.15 };

const CARD_W = 452;
const CARD_H = 92;
const GAP = 26;
const COL_X = 250;   // left of node column within canvas
const COL_Y = 78;    // top of first card within canvas

function dot(color, size = 9, glow = false) {
  return (
    <span style={{
      width: size, height: size, borderRadius: size,
      background: color, flexShrink: 0, display: "inline-block",
      boxShadow: glow ? `0 0 0 4px ${color}22` : "none",
      transition: "background 200ms linear",
    }} />
  );
}

// ── NodeCard ───────────────────────────────────────────────────────────────────
function NodeCard({ node, y, opacity, ty, borderColor, dotColor, progress, shake, dim, badge }) {
  return (
    <div style={{
      position: "absolute", left: COL_X, top: y, width: CARD_W,
      transform: `translate(${shake || 0}px, ${ty}px)`,
      opacity: opacity * (dim ? 0.4 : 1),
      transition: "opacity 320ms linear",
      willChange: "transform, opacity",
    }}>
      <div style={{
        background: C.bgCard,
        border: `1px solid ${borderColor || C.border}`,
        borderRadius: 11,
        padding: "13px 16px 0",
        boxShadow: C.cardShadow,
        height: CARD_H, boxSizing: "border-box",
        display: "flex", flexDirection: "column",
      }}>
        <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
          {dot(dotColor || node.color, 9, !!borderColor)}
          <span style={{ fontFamily: MONO, fontSize: 14.5, fontWeight: 600, color: C.textHi, letterSpacing: "-0.01em" }}>
            {node.id}
          </span>
          {badge}
          <span style={{ marginLeft: "auto", fontFamily: MONO, fontSize: 12.5, color: C.textMid, fontVariantNumeric: "tabular-nums" }}>
            {node.lat}
          </span>
        </div>
        <div style={{ fontFamily: MONO, fontSize: 12, color: C.textLo, marginTop: 7, marginLeft: 19, letterSpacing: "0.01em" }}>
          {node.model}
        </div>
        {/* progress bar */}
        <div style={{ marginTop: "auto", marginBottom: 13, height: 2, background: "rgba(0,0,0,0.08)", borderRadius: 2, position: "relative", overflow: "hidden" }}>
          <div style={{
            position: "absolute", left: 0, top: 0, bottom: 0,
            width: `${(progress == null ? 1 : progress) * 100}%`,
            background: dotColor || node.color, borderRadius: 2,
          }} />
        </div>
      </div>
    </div>
  );
}

// vertical connector between two card dots
function Connector({ y1, y2, opacity, color }) {
  const x = COL_X + 16 + 4.5;
  return (
    <div style={{
      position: "absolute", left: x, top: y1 + CARD_H - 8, width: 1.5,
      height: Math.max(0, y2 - (y1 + CARD_H) + 16),
      background: color || "rgba(0,0,0,0.16)", opacity,
      transition: "background 300ms linear",
    }} />
  );
}

// ── Traffic lights ──────────────────────────────────────────────────────────────
function TrafficLights() {
  return (
    <div style={{ display: "flex", gap: 8, alignItems: "center" }}>
      {["#ff5f57", "#febc2e", "#28c840"].map((c) => (
        <span key={c} style={{ width: 12, height: 12, borderRadius: 12, background: c }} />
      ))}
    </div>
  );
}

// ── Status bar ──────────────────────────────────────────────────────────────────
function Pill({ label, value, valueColor }) {
  return (
    <div style={{
      display: "flex", alignItems: "baseline", gap: 7,
      border: `1px solid ${C.border}`, borderRadius: 7, padding: "6px 11px",
      background: C.bgSubtle,
    }}>
      <span style={{ fontFamily: MONO, fontSize: 10.5, letterSpacing: "0.08em", color: C.textLo, textTransform: "uppercase" }}>{label}</span>
      <span style={{ fontFamily: MONO, fontSize: 12.5, fontWeight: 600, color: valueColor || C.textHi, fontVariantNumeric: "tabular-nums" }}>{value}</span>
    </div>
  );
}

function StatusBar({ t }) {
  // status: RUNNING (0-2.4) -> FAILED (2.4-9.4) -> ✓ REPAIRED (9.4+)
  let status = "RUNNING", statusColor = C.textHi, steps = "4";
  if (t >= 2.4 && t < 9.45) { status = "FAILED"; statusColor = C.red; }
  else if (t >= 9.45) { status = "✓ REPAIRED"; statusColor = C.green; steps = "5"; }

  // analyze button pulse 4.5-4.95, auto-click ripple at 4.7
  const pulse = (() => {
    if (t < 4.45 || t > 5.0) return { scale: 1, glow: 0 };
    const p = (t - 4.45) / 0.55;
    const s = 1 + 0.06 * Math.sin(p * Math.PI);
    return { scale: s, glow: Math.sin(p * Math.PI) };
  })();
  const liveDot = t < 2.4;

  return (
    <div style={{
      display: "flex", alignItems: "center", gap: 14,
      padding: "0 22px", height: 56, flexShrink: 0,
      borderBottom: `1px solid ${C.border}`,
    }}>
      <div style={{ display: "flex", flexDirection: "column", gap: 2 }}>
        <span style={{ fontFamily: MONO, fontSize: 10.5, letterSpacing: "0.08em", color: C.textLo, textTransform: "uppercase" }}>Live trace</span>
        <span style={{ fontFamily: SANS, fontSize: 15, fontWeight: 600, color: C.textHi }}>Agent · weather-tool run</span>
      </div>
      <div style={{ display: "flex", alignItems: "center", gap: 8, marginLeft: 14 }}>
        <span style={{
          width: 8, height: 8, borderRadius: 8,
          background: status === "FAILED" ? C.red : status.includes("REPAIRED") ? C.green : C.green,
          boxShadow: liveDot ? `0 0 0 3px ${C.green}33` : "none",
          opacity: liveDot ? (0.5 + 0.5 * Math.abs(Math.sin(t * 4))) : 1,
        }} />
        <Pill label="Total time" value="2.39s" />
        <Pill label="Steps" value={steps} />
        <Pill label="Status" value={status} valueColor={statusColor} />
      </div>
      <button style={{
        marginLeft: "auto", display: "flex", alignItems: "center", gap: 8,
        fontFamily: SANS, fontSize: 13, fontWeight: 600, color: C.textHi,
        background: pulse.glow ? `rgba(229,72,77,${0.1 * pulse.glow})` : "#ffffff",
        border: `1px solid ${pulse.glow ? `rgba(229,72,77,${0.55 * pulse.glow})` : C.borderStrong}`,
        borderRadius: 8, padding: "8px 14px", cursor: "pointer",
        transform: `scale(${pulse.scale})`, transition: "none",
        boxShadow: pulse.glow ? `0 0 ${16 * pulse.glow}px rgba(229,72,77,${0.3 * pulse.glow})` : C.cardShadow,
      }}>
        <svg width="14" height="14" viewBox="0 0 16 16" fill="none">
          <path d="M2 3h12M2 8h12M2 13h7" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" />
        </svg>
        Analyze Failure
      </button>
    </div>
  );
}

// ── Sidebar (calls list) ──────────────────────────────────────────────────────
function Sidebar({ t }) {
  const failed = t >= 2.4 && t < 9.45;
  const repaired = t >= 9.45;
  const accent = repaired ? C.green : failed ? C.red : C.blue;
  return (
    <div style={{
      width: 268, flexShrink: 0, borderRight: `1px solid ${C.border}`,
      padding: "18px 16px", display: "flex", flexDirection: "column", gap: 14,
    }}>
      <div style={{
        display: "flex", alignItems: "center", gap: 9, padding: "9px 12px",
        background: "rgba(52,211,153,0.08)", border: "1px solid rgba(52,211,153,0.18)", borderRadius: 9,
      }}>
        <span style={{ width: 16, height: 16, borderRadius: 16, background: "rgba(52,211,153,0.25)", display: "flex", alignItems: "center", justifyContent: "center" }}>
          <svg width="9" height="9" viewBox="0 0 12 12"><path d="M2 6l3 3 5-6" stroke={C.green} strokeWidth="1.8" fill="none" strokeLinecap="round" strokeLinejoin="round" /></svg>
        </span>
        <span style={{ fontFamily: SANS, fontSize: 13, fontWeight: 600, color: C.green }}>Local Proxy</span>
      </div>
      <div style={{
        display: "flex", alignItems: "center", gap: 8, padding: "9px 12px",
        border: `1px solid ${C.border}`, borderRadius: 9, color: C.textLo, fontFamily: SANS, fontSize: 12.5,
      }}>
        <svg width="12" height="12" viewBox="0 0 12 12" fill="none"><circle cx="5" cy="5" r="4" stroke="currentColor" strokeWidth="1.3" /><path d="M8 8l2.5 2.5" stroke="currentColor" strokeWidth="1.3" strokeLinecap="round" /></svg>
        Filter calls…
      </div>
      <div style={{ display: "flex", justifyContent: "space-between", marginTop: 2 }}>
        <span style={{ fontFamily: MONO, fontSize: 10.5, letterSpacing: "0.08em", color: C.textLo, textTransform: "uppercase" }}>Calls</span>
        <span style={{ fontFamily: MONO, fontSize: 11, color: C.textLo }}>{repaired ? "5 of 5" : "4 of 4"}</span>
      </div>
      {/* selected call */}
      <div style={{
        position: "relative", padding: "12px 13px 12px 15px", borderRadius: 9,
        background: `${accent}0d`, border: `1px solid ${accent}55`,
      }}>
        <span style={{ position: "absolute", left: 0, top: 8, bottom: 8, width: 3, borderRadius: 3, background: accent }} />
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
          <span style={{ fontFamily: SANS, fontSize: 13, fontWeight: 600, color: accent }}>tool.call_weather</span>
          <span style={{ fontFamily: MONO, fontSize: 11, color: C.textMid }}>0.61s</span>
        </div>
        <div style={{ display: "flex", gap: 6, marginTop: 8 }}>
          <span style={{ fontFamily: MONO, fontSize: 10.5, color: C.violet, background: "rgba(109,94,240,0.1)", padding: "2px 7px", borderRadius: 5 }}>⌘ Agent</span>
          <span style={{ fontFamily: MONO, fontSize: 10.5, color: C.textMid, background: C.bgSubtle, padding: "2px 7px", borderRadius: 5 }}>openai / gpt-4o</span>
        </div>
      </div>
      {repaired && (
        <div style={{ padding: "12px 13px", borderRadius: 9, border: `1px solid ${C.border}`, opacity: clamp((t - 9.4) / 0.5, 0, 1) }}>
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
            <span style={{ fontFamily: SANS, fontSize: 13, fontWeight: 600, color: C.green }}>repair.result</span>
            <span style={{ fontFamily: MONO, fontSize: 11, color: C.textMid }}>0.31s</span>
          </div>
          <div style={{ fontFamily: MONO, fontSize: 10.5, color: C.textLo, marginTop: 7 }}>patched · replayed</div>
        </div>
      )}
      <div style={{ marginTop: "auto", display: "flex", alignItems: "center", gap: 8, padding: "9px 12px", border: `1px solid ${C.border}`, borderRadius: 9, color: C.textMid, fontFamily: SANS, fontSize: 12.5 }}>
        <svg width="13" height="13" viewBox="0 0 14 14" fill="none"><circle cx="7" cy="7" r="2.2" stroke="currentColor" strokeWidth="1.2" /><path d="M7 1v2M7 11v2M1 7h2M11 7h2M2.8 2.8l1.4 1.4M9.8 9.8l1.4 1.4M11.2 2.8l-1.4 1.4M4.2 9.8l-1.4 1.4" stroke="currentColor" strokeWidth="1.1" strokeLinecap="round" /></svg>
        Settings
      </div>
    </div>
  );
}

// ── Error box (act 2) ─────────────────────────────────────────────────────────
function ErrorBox({ t }) {
  const { opacity, ty } = slide(t, 2.65, 0.45);
  // fades out when repaired
  const fade = t >= 9.0 ? clamp(1 - (t - 9.0) / 0.5, 0, 1) : 1;
  if (t < 2.65) return null;
  return (
    <div style={{
      position: "absolute", left: COL_X - 4, bottom: 26, width: CARD_W + 8,
      transform: `translateY(${ty}px)`, opacity: opacity * fade,
      background: "rgba(248,113,113,0.07)", border: "1px solid rgba(248,113,113,0.35)",
      borderRadius: 11, padding: "14px 16px",
    }}>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 9 }}>
        <span style={{ fontFamily: MONO, fontSize: 11, fontWeight: 700, letterSpacing: "0.1em", color: C.red }}>ERROR</span>
        <span style={{ fontFamily: MONO, fontSize: 11.5, color: "rgba(248,113,113,0.8)" }}>upstream_tool_error</span>
      </div>
      <div style={{ fontFamily: MONO, fontSize: 12.5, color: "#9b1f24", lineHeight: 1.5 }}>
        The tool handler returned before producing an observation.
      </div>
    </div>
  );
}

// ── Detail panel (act 3) ──────────────────────────────────────────────────────
function typewriter(full, t, start, cps = 38) {
  if (t < start) return "";
  return full.slice(0, Math.floor((t - start) * cps));
}

function DetailPanel({ t }) {
  // slides in from right at 4.0
  const p = Easing.easeOutCubic(clamp((t - 4.0) / 0.55, 0, 1));
  const tx = (1 - p) * 380;
  if (t < 4.0) return null;

  const tabs = ["Context", "LLM Call", "Response", "Metadata"];
  const repaired = t >= 9.45;

  const line1 = typewriter("Caused by: llm.request · node 2", t, 5.15);
  const line2 = typewriter("Prompt: \"Create a visible trace block for the local execution demo…\"", t, 5.95);
  const line3 = typewriter("Fix: patch response and replay downstream", t, 7.05);

  // CTA enters at 7.55
  const cta = slide(t, 7.55, 0.5);
  const subFade = clamp((t - 8.05) / 0.5, 0, 1);
  // click ripple at 8.05
  const ripple = (t >= 8.05 && t < 8.75) ? (t - 8.05) / 0.7 : null;

  return (
    <div style={{
      width: 372, flexShrink: 0, borderLeft: `1px solid ${C.border}`,
      transform: `translateX(${tx}px)`, opacity: p,
      display: "flex", flexDirection: "column", padding: "20px 20px 18px",
      background: C.bgSubtle,
    }}>
      {/* header */}
      <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between" }}>
        <span style={{ fontFamily: SANS, fontSize: 17, fontWeight: 700, color: C.textHi }}>tool.call_weather</span>
        <span style={{
          fontFamily: MONO, fontSize: 10.5, fontWeight: 700, letterSpacing: "0.08em",
          color: repaired ? C.green : C.red,
          background: repaired ? "rgba(52,211,153,0.12)" : "rgba(248,113,113,0.12)",
          padding: "3px 9px", borderRadius: 6,
        }}>{repaired ? "FIXED" : "ERROR"}</span>
      </div>
      <div style={{ display: "flex", gap: 7, marginTop: 11 }}>
        <span style={{ fontFamily: MONO, fontSize: 10.5, color: C.violet, background: "rgba(109,94,240,0.1)", padding: "3px 8px", borderRadius: 6 }}>⌘ Agent</span>
        <span style={{ fontFamily: MONO, fontSize: 10.5, color: C.textMid, background: "#ffffff", border: `1px solid ${C.border}`, padding: "3px 8px", borderRadius: 6 }}>openai / gpt-4o</span>
      </div>
      {/* tabs */}
      <div style={{ display: "flex", gap: 4, marginTop: 16, background: "#ececf2", borderRadius: 9, padding: 4 }}>
        {tabs.map((tab, i) => (
          <span key={tab} style={{
            flex: 1, textAlign: "center", fontFamily: SANS, fontSize: 11.5, fontWeight: 600,
            color: i === 0 ? C.violet : C.textMid,
            background: i === 0 ? "#ffffff" : "transparent",
            border: i === 0 ? `1px solid rgba(109,94,240,0.35)` : "1px solid transparent",
            boxShadow: i === 0 ? "0 1px 2px rgba(0,0,0,0.06)" : "none",
            padding: "6px 4px", borderRadius: 6,
          }}>{tab}</span>
        ))}
      </div>

      {/* diagnosis */}
      <div style={{ marginTop: 18, fontFamily: MONO, fontSize: 10.5, letterSpacing: "0.08em", color: C.textLo, textTransform: "uppercase" }}>
        Failure analysis
      </div>
      <div style={{ marginTop: 12, display: "flex", flexDirection: "column", gap: 11, minHeight: 96 }}>
        <DiagLine text={line1} color={C.textMid} accent={C.amber} />
        <DiagLine text={line2} color={C.textMid} accent={C.blue} />
        <DiagLine text={line3} color={C.green} accent={C.green} bold />
      </div>

      {/* CTA */}
      {t >= 7.55 && (
        <div style={{ marginTop: "auto", opacity: cta.opacity, transform: `translateY(${cta.ty}px)`, position: "relative" }}>
          <button style={{
            width: "100%", padding: "15px", borderRadius: 11, border: "none", cursor: "pointer",
            background: repaired ? C.green : "#1a1a22", color: "#ffffff",
            fontFamily: SANS, fontSize: 14.5, fontWeight: 700, position: "relative", overflow: "hidden",
            transition: "background 300ms linear",
            transform: ripple != null ? `scale(${1 - 0.03 * Math.sin(ripple * Math.PI)})` : "scale(1)",
          }}>
            {repaired ? "✓ Fixed & replayed" : "Auto-fix with your API key"}
            {ripple != null && (
              <span style={{
                position: "absolute", left: "50%", top: "50%",
                width: 12, height: 12, borderRadius: "50%", background: "rgba(12,12,12,0.18)",
                transform: `translate(-50%,-50%) scale(${ripple * 34})`, opacity: 1 - ripple,
              }} />
            )}
          </button>
          <div style={{ textAlign: "center", marginTop: 10, fontFamily: MONO, fontSize: 11, color: C.textLo, opacity: subFade }}>
            Runs on your machine. Uses your token.
          </div>
        </div>
      )}
    </div>
  );
}

function DiagLine({ text, color, accent, bold }) {
  if (!text) return <div style={{ minHeight: 17 }} />;
  return (
    <div style={{ display: "flex", gap: 9, alignItems: "flex-start" }}>
      <span style={{ width: 4, height: 4, borderRadius: 4, background: accent, marginTop: 7, flexShrink: 0 }} />
      <span style={{ fontFamily: MONO, fontSize: 12, lineHeight: 1.5, color, fontWeight: bold ? 600 : 400 }}>
        {text}<Caret />
      </span>
    </div>
  );
}
function Caret() {
  const t = useTime();
  return <span style={{ opacity: Math.abs(Math.sin(t * 5)) > 0.5 ? 1 : 0.15, color: "rgba(0,0,0,0.45)" }}>▋</span>;
}

// ── The app frame (everything inside the macOS window) ──────────────────────────
function AppFrame() {
  const t = useTime();

  // Node visual state machine
  const nodeStates = NODES.map((node, i) => {
    const { opacity, ty } = slide(t, node.appear, 0.42);
    let dotColor = node.color, borderColor = null, progress = null, shake = 0, dim = false, badge = null;

    if (node.broken) {
      // act2: pulse red border + shake (2.05-2.6)
      if (t >= 2.05 && t < 9.0) {
        const flash = Math.abs(Math.sin((t - 2.05) * 6));
        borderColor = `rgba(248,113,113,${0.55 + 0.45 * flash})`;
        dotColor = C.red;
      }
      if (t >= 2.15 && t < 2.65) {
        shake = Math.sin((t - 2.15) * 38) * 3 * (1 - (t - 2.15) / 0.5);
      }
      // act4 repair: red -> amber -> green
      if (t >= 8.05) {
        if (t < 8.55) { dotColor = C.red; borderColor = "rgba(248,113,113,0.7)"; }
        else if (t < 9.0) { dotColor = C.amber; borderColor = "rgba(251,191,36,0.7)"; }
        else { dotColor = C.green; borderColor = "rgba(52,211,153,0.6)"; }
        // progress bar fills green 8.55-9.5
        if (t >= 8.55) progress = clamp((t - 8.55) / 0.95, 0, 1);
        else progress = 1;
      } else {
        progress = 1;
      }
      // history indicator after repair
      if (t >= 9.45) {
        badge = (
          <span title="was broken" style={{
            width: 6, height: 6, borderRadius: 6, background: C.red, marginLeft: 7,
            boxShadow: "0 0 0 2px rgba(248,113,113,0.25)", opacity: clamp((t - 9.45) / 0.4, 0, 1),
          }} />
        );
      }
    } else {
      progress = 1;
    }

    // dimming: non-broken nodes dim 40% during act2/act3 (2.95 - 9.0)
    if (!node.broken && t >= 2.95 && t < 9.0) dim = true;

    return { node, y: COL_Y + i * (CARD_H + GAP), opacity, ty, dotColor, borderColor, progress, shake, dim, badge };
  });

  // node 5
  const n5 = (() => {
    if (t < NODE5.appear) return null;
    const { opacity, ty } = slide(t, NODE5.appear, 0.45);
    return { node: NODE5, y: COL_Y + 4 * (CARD_H + GAP), opacity, ty, dotColor: C.green, borderColor: "rgba(52,211,153,0.45)", progress: clamp((t - NODE5.appear) / 0.5, 0, 1), shake: 0, dim: false, badge: null };
  })();

  return (
    <div style={{ display: "flex", flexDirection: "column", height: "100%", background: C.bgWindow }}>
      {/* title bar */}
      <div style={{ height: 44, flexShrink: 0, display: "flex", alignItems: "center", padding: "0 18px", borderBottom: `1px solid ${C.border}` }}>
        <TrafficLights />
        <span style={{ margin: "0 auto", fontFamily: SANS, fontSize: 12.5, color: C.textLo, fontWeight: 500 }}>Tether — Local Trace Inspector</span>
        <div style={{ width: 52 }} />
      </div>
      {/* body */}
      <div style={{ flex: 1, display: "flex", minHeight: 0 }}>
        <Sidebar t={t} />
        {/* main */}
        <div style={{ flex: 1, display: "flex", flexDirection: "column", minWidth: 0 }}>
          <StatusBar t={t} />
          <div style={{ flex: 1, position: "relative", overflow: "hidden",
            backgroundImage: "radial-gradient(rgba(0,0,0,0.055) 1px, transparent 1px)",
            backgroundSize: "26px 26px", backgroundPosition: "12px 12px" }}>
            {/* connectors */}
            {nodeStates.slice(0, 3).map((s, i) => (
              <Connector key={i} y1={s.y} y2={nodeStates[i + 1].y}
                opacity={Math.min(s.opacity, nodeStates[i + 1].opacity)}
                color={i === 1 || i === 2 ? (t >= 2.4 && t < 9.0 ? "rgba(248,113,113,0.3)" : null) : null} />
            ))}
            {n5 && <Connector y1={nodeStates[3].y} y2={n5.y} opacity={n5.opacity} color="rgba(52,211,153,0.35)" />}
            {/* nodes */}
            {nodeStates.map((s, i) => <NodeCard key={i} {...s} />)}
            {n5 && <NodeCard {...n5} />}
            <ErrorBox t={t} />
          </div>
        </div>
        <DetailPanel t={t} />
      </div>
    </div>
  );
}

// ── Camera + window chrome ──────────────────────────────────────────────────────
function CameraStage() {
  const t = useTime();

  // window appears 0-0.5
  const appear = Easing.easeOutCubic(clamp(t / 0.55, 0, 1));

  // camera scale / translate keyframes
  const scale = interpolate(
    [0, 1.8, 2.4, 3.9, 4.3, 7.8, 8.6, 9.6, 10.2, 12],
    [1.0, 1.03, 1.16, 1.16, 1.08, 1.08, 1.04, 1.0, 1.0, 1.012],
    Easing.easeInOutCubic
  )(t);
  const tx = interpolate(
    [0, 1.8, 2.4, 3.9, 4.3, 7.8, 8.6, 9.6, 12],
    [0, 0, 150, 150, -150, -150, 0, 0, 0],
    Easing.easeInOutCubic
  )(t);
  const ty = interpolate(
    [0, 2.4, 3.9, 4.3, 7.8, 8.6, 12],
    [0, 30, 30, 10, 10, 0, 0],
    Easing.easeInOutCubic
  )(t);

  // breathing pop at 9.6-10.2
  const breathe = (t >= 9.55 && t < 10.4) ? 1 + 0.01 * Math.sin(((t - 9.55) / 0.85) * Math.PI) : 1;

  return (
    <div style={{ position: "absolute", inset: 0, background: C.bgOuter, overflow: "hidden" }}>
      <div style={{
        position: "absolute", inset: 0,
        transform: `scale(${scale * breathe}) translate(${tx}px, ${ty}px)`,
        transformOrigin: "center center",
        willChange: "transform",
      }}>
        {/* macOS window */}
        <div style={{
          position: "absolute", left: 0, top: 0, right: 0, bottom: 0,
          background: C.bgWindow, borderRadius: 0, overflow: "hidden",
          opacity: appear,
          transform: `scale(${0.985 + 0.015 * appear})`,
          transformOrigin: "center center",
        }}>
          <AppFrame />
        </div>
      </div>
    </div>
  );
}

// ── Stage (engine) ──────────────────────────────────────────────────────────────
function Stage({ width, height, duration }) {
  const [time, setTime] = React.useState(() => {
    try { const v = parseFloat(localStorage.getItem("tether:t") || "0"); return isFinite(v) ? clamp(v, 0, duration) : 0; } catch { return 0; }
  });
  const [playing, setPlaying] = React.useState(true);
  const [scale, setScale] = React.useState(1);
  const stageRef = React.useRef(null), rafRef = React.useRef(null), lastRef = React.useRef(null);

  React.useEffect(() => { try { localStorage.setItem("tether:t", String(time)); } catch {} }, [time]);

  React.useEffect(() => {
    if (!stageRef.current) return;
    const el = stageRef.current;
    const measure = () => setScale(Math.max(0.05, Math.min(el.clientWidth / width, el.clientHeight / height)));
    measure();
    const ro = new ResizeObserver(measure); ro.observe(el);
    window.addEventListener("resize", measure);
    return () => { ro.disconnect(); window.removeEventListener("resize", measure); };
  }, [width, height]);

  React.useEffect(() => {
    if (!playing) { lastRef.current = null; return; }
    const step = (ts) => {
      if (lastRef.current == null) lastRef.current = ts;
      const dt = (ts - lastRef.current) / 1000; lastRef.current = ts;
      setTime((t) => { let n = t + dt; if (n >= duration) n = n % duration; return n; });
      rafRef.current = requestAnimationFrame(step);
    };
    rafRef.current = requestAnimationFrame(step);
    return () => { if (rafRef.current) cancelAnimationFrame(rafRef.current); lastRef.current = null; };
  }, [playing, duration]);

  React.useEffect(() => {
    const onKey = (e) => {
      if (e.code === "Space") { e.preventDefault(); setPlaying((p) => !p); }
      else if (e.code === "ArrowLeft") setTime((t) => clamp(t - (e.shiftKey ? 1 : 0.1), 0, duration));
      else if (e.code === "ArrowRight") setTime((t) => clamp(t + (e.shiftKey ? 1 : 0.1), 0, duration));
      else if (e.key === "0") setTime(0);
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [duration]);

  const fmt = (x) => { const m = Math.floor(x / 60), s = Math.floor(x % 60), cs = Math.floor((x * 100) % 100); return `${m}:${String(s).padStart(2, "0")}.${String(cs).padStart(2, "0")}`; };
  const pct = (time / duration) * 100;

  return (
    <div ref={stageRef} data-screen-label={`t=${time.toFixed(1)}s`} style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", background: "#d6d6db" }}>
      <div style={{ flex: 1, width: "100%", display: "flex", alignItems: "center", justifyContent: "center", overflow: "hidden", minHeight: 0 }}>
        <div style={{ width, height, position: "relative", transform: `scale(${scale})`, transformOrigin: "center", flexShrink: 0, overflow: "hidden" }}>
          <TL.Provider value={{ time, duration }}>
            <CameraStage />
          </TL.Provider>
        </div>
      </div>
    </div>
  );
}
const btnStyle = { width: 28, height: 28, display: "flex", alignItems: "center", justifyContent: "center", background: "#f2f2f5", border: "1px solid rgba(0,0,0,0.1)", borderRadius: 6, color: "#1a1a22", cursor: "pointer", padding: 0 };

function TetherAnim() {
  return <Stage width={1600} height={900} duration={12} />;
}

window.TetherAnim = TetherAnim;
if (typeof module !== "undefined") module.exports = { TetherAnim };
