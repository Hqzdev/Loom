// @ds-adherence-ignore -- omelette starter scaffold (raw elements/hex/px by design)

/* BEGIN USAGE */
// animations.jsx
// Reusable animation starter: Stage, Timeline, Sprite, easing helpers.
// Exports (to window): Stage, Sprite, PlaybackBar, TextSprite, ImageSprite, RectSprite,
//   useTime, useTimeline, useSprite, Easing, interpolate, animate, clamp.
//
// Usage (in an HTML file that loads React + Babel):
//
//   <Stage width={1280} height={720} duration={10} background="#f6f4ef">
//     <MyScene />
//   </Stage>
//
// <Stage> auto-scales to the viewport and provides the scrubber, play/pause,
// ←/→ seek, space, and 0-to-reset controls, and persists the playhead.
// Inside <Stage>, any child can call useTime() to read the current
// playhead (seconds). Or wrap content in <Sprite start={1} end={4}>...</Sprite>
// to only render during that window -- children receive a `localTime` and
// `progress` via the useSprite() hook. Use Easing + interpolate()/animate()
// for tweens; TextSprite / ImageSprite / RectSprite have built-in entry/exit.
// Build YOUR scenes by composing Sprites inside a Stage.
/* END USAGE */
// ─────────────────────────────────────────────────────────────────────────────

// ── Easing functions (hand-rolled, Popmotion-style) ─────────────────────────
// All easings take t ∈ [0,1] and return eased t ∈ [0,1] (may overshoot for back/elastic).
const Easing = {
  linear: (t) => t,

  // Quad
  easeInQuad:    (t) => t * t,
  easeOutQuad:   (t) => t * (2 - t),
  easeInOutQuad: (t) => (t < 0.5 ? 2 * t * t : -1 + (4 - 2 * t) * t),

  // Cubic
  easeInCubic:    (t) => t * t * t,
  easeOutCubic:   (t) => (--t) * t * t + 1,
  easeInOutCubic: (t) => (t < 0.5 ? 4 * t * t * t : (t - 1) * (2 * t - 2) * (2 * t - 2) + 1),

  // Quart
  easeInQuart:    (t) => t * t * t * t,
  easeOutQuart:   (t) => 1 - (--t) * t * t * t,
  easeInOutQuart: (t) => (t < 0.5 ? 8 * t * t * t * t : 1 - 8 * (--t) * t * t * t),

  // Expo
  easeInExpo:  (t) => (t === 0 ? 0 : Math.pow(2, 10 * (t - 1))),
  easeOutExpo: (t) => (t === 1 ? 1 : 1 - Math.pow(2, -10 * t)),
  easeInOutExpo: (t) => {
    if (t === 0) return 0;
    if (t === 1) return 1;
    if (t < 0.5) return 0.5 * Math.pow(2, 20 * t - 10);
    return 1 - 0.5 * Math.pow(2, -20 * t + 10);
  },

  // Sine
  easeInSine:    (t) => 1 - Math.cos((t * Math.PI) / 2),
  easeOutSine:   (t) => Math.sin((t * Math.PI) / 2),
  easeInOutSine: (t) => -(Math.cos(Math.PI * t) - 1) / 2,

  // Back (overshoot)
  easeOutBack: (t) => {
    const c1 = 1.70158, c3 = c1 + 1;
    return 1 + c3 * Math.pow(t - 1, 3) + c1 * Math.pow(t - 1, 2);
  },
  easeInBack: (t) => {
    const c1 = 1.70158, c3 = c1 + 1;
    return c3 * t * t * t - c1 * t * t;
  },
  easeInOutBack: (t) => {
    const c1 = 1.70158, c2 = c1 * 1.525;
    return t < 0.5
      ? (Math.pow(2 * t, 2) * ((c2 + 1) * 2 * t - c2)) / 2
      : (Math.pow(2 * t - 2, 2) * ((c2 + 1) * (t * 2 - 2) + c2) + 2) / 2;
  },

  // Elastic
  easeOutElastic: (t) => {
    const c4 = (2 * Math.PI) / 3;
    if (t === 0) return 0;
    if (t === 1) return 1;
    return Math.pow(2, -10 * t) * Math.sin((t * 10 - 0.75) * c4) + 1;
  },
};

// ── Core interpolation helpers ──────────────────────────────────────────────

// Clamp a value to [min, max]
const clamp = (v, min, max) => Math.max(min, Math.min(max, v));

// interpolate([0, 0.5, 1], [0, 100, 50], ease?) -> fn(t)
// Popmotion-style: linearly maps t across input keyframes to output values,
// with optional easing per segment (single fn or array of fns).
function interpolate(input, output, ease = Easing.linear) {
  return (t) => {
    if (t <= input[0]) return output[0];
    if (t >= input[input.length - 1]) return output[output.length - 1];
    for (let i = 0; i < input.length - 1; i++) {
      if (t >= input[i] && t <= input[i + 1]) {
        const span = input[i + 1] - input[i];
        const local = span === 0 ? 0 : (t - input[i]) / span;
        const easeFn = Array.isArray(ease) ? (ease[i] || Easing.linear) : ease;
        const eased = easeFn(local);
        return output[i] + (output[i + 1] - output[i]) * eased;
      }
    }
    return output[output.length - 1];
  };
}

// animate({from, to, start, end, ease})(t) — simpler single-segment tween.
// Returns `from` before `start`, `to` after `end`.
function animate({ from = 0, to = 1, start = 0, end = 1, ease = Easing.easeInOutCubic }) {
  return (t) => {
    if (t <= start) return from;
    if (t >= end) return to;
    const local = (t - start) / (end - start);
    return from + (to - from) * ease(local);
  };
}

// ── Timeline context ────────────────────────────────────────────────────────

const TimelineContext = React.createContext({ time: 0, duration: 10, playing: false });

const useTime = () => React.useContext(TimelineContext).time;
const useTimeline = () => React.useContext(TimelineContext);

// ── Sprite ──────────────────────────────────────────────────────────────────
// Renders children only when the playhead is inside [start, end]. Provides
// a sub-context with `localTime` (seconds since start) and `progress` (0..1).
//
//   <Sprite start={2} end={5}>
//     {({ localTime, progress }) => <Thing x={progress * 100} />}
//   </Sprite>
//
// Or as a plain wrapper — children can call useSprite() themselves.

const SpriteContext = React.createContext({ localTime: 0, progress: 0, duration: 0 });
const useSprite = () => React.useContext(SpriteContext);

function Sprite({ start = 0, end = Infinity, children, keepMounted = false }) {
  const { time } = useTimeline();
  const visible = time >= start && time <= end;
  if (!visible && !keepMounted) return null;

  const duration = end - start;
  const localTime = Math.max(0, time - start);
  const progress = duration > 0 && isFinite(duration)
    ? clamp(localTime / duration, 0, 1)
    : 0;

  const value = { localTime, progress, duration, visible };

  return (
    <SpriteContext.Provider value={value}>
      {typeof children === 'function' ? children(value) : children}
    </SpriteContext.Provider>
  );
}

// ── Sample sprite components ────────────────────────────────────────────────

// TextSprite: fades/slides text in on entry, holds, then fades out on exit.
// Props: text, x, y, size, color, font, entryDur, exitDur, align
function TextSprite({
  text,
  x = 0, y = 0,
  size = 48,
  color = '#111',
  font = 'Inter, system-ui, sans-serif',
  weight = 600,
  entryDur = 0.45,
  exitDur = 0.35,
  entryEase = Easing.easeOutBack,
  exitEase = Easing.easeInCubic,
  align = 'left',
  letterSpacing = '-0.01em',
}) {
  const { localTime, duration } = useSprite();
  const exitStart = Math.max(0, duration - exitDur);

  let opacity = 1;
  let ty = 0;

  if (localTime < entryDur) {
    const t = entryEase(clamp(localTime / entryDur, 0, 1));
    opacity = t;
    ty = (1 - t) * 16;
  } else if (localTime > exitStart) {
    const t = exitEase(clamp((localTime - exitStart) / exitDur, 0, 1));
    opacity = 1 - t;
    ty = -t * 8;
  }

  const translateX = align === 'center' ? '-50%' : align === 'right' ? '-100%' : '0';

  return (
    <div style={{
      position: 'absolute',
      left: x, top: y,
      transform: `translate(${translateX}, ${ty}px)`,
      opacity,
      fontFamily: font,
      fontSize: size,
      fontWeight: weight,
      color,
      letterSpacing,
      whiteSpace: 'pre',
      lineHeight: 1.1,
      willChange: 'transform, opacity',
    }}>
      {text}
    </div>
  );
}

// ImageSprite: scales + fades in; optional Ken Burns drift during hold.
function ImageSprite({
  src,
  x = 0, y = 0,
  width = 400, height = 300,
  entryDur = 0.6,
  exitDur = 0.4,
  kenBurns = false,
  kenBurnsScale = 1.08,
  radius = 12,
  fit = 'cover',
  placeholder = null, // {label: string} for striped placeholder
}) {
  const { localTime, duration } = useSprite();
  const exitStart = Math.max(0, duration - exitDur);

  let opacity = 1;
  let scale = 1;

  if (localTime < entryDur) {
    const t = Easing.easeOutCubic(clamp(localTime / entryDur, 0, 1));
    opacity = t;
    scale = 0.96 + 0.04 * t;
  } else if (localTime > exitStart) {
    const t = Easing.easeInCubic(clamp((localTime - exitStart) / exitDur, 0, 1));
    opacity = 1 - t;
    scale = (kenBurns ? kenBurnsScale : 1) + 0.02 * t;
  } else if (kenBurns) {
    const holdSpan = exitStart - entryDur;
    const holdT = holdSpan > 0 ? (localTime - entryDur) / holdSpan : 0;
    scale = 1 + (kenBurnsScale - 1) * holdT;
  }

  const content = placeholder ? (
    <div style={{
      width: '100%', height: '100%',
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      background: 'repeating-linear-gradient(135deg, #e9e6df 0 10px, #dcd8cf 10px 20px)',
      color: '#6b6458',
      fontFamily: 'JetBrains Mono, ui-monospace, monospace',
      fontSize: 13,
      letterSpacing: '0.04em',
      textTransform: 'uppercase',
    }}>
      {placeholder.label || 'image'}
    </div>
  ) : (
    <img src={src} alt="" style={{ width: '100%', height: '100%', objectFit: fit, display: 'block' }} />
  );

  return (
    <div style={{
      position: 'absolute',
      left: x, top: y,
      width, height,
      opacity,
      transform: `scale(${scale})`,
      transformOrigin: 'center',
      borderRadius: radius,
      overflow: 'hidden',
      willChange: 'transform, opacity',
    }}>
      {content}
    </div>
  );
}

// RectSprite: simple rectangle that animates position/size/color via props.
// Useful demo primitive — takes a `render` fn for per-frame customization.
function RectSprite({
  x = 0, y = 0,
  width = 100, height = 100,
  color = '#111',
  radius = 8,
  entryDur = 0.4,
  exitDur = 0.3,
  render, // optional: (ctx) => style overrides
}) {
  const spriteCtx = useSprite();
  const { localTime, duration } = spriteCtx;
  const exitStart = Math.max(0, duration - exitDur);

  let opacity = 1;
  let scale = 1;

  if (localTime < entryDur) {
    const t = Easing.easeOutBack(clamp(localTime / entryDur, 0, 1));
    opacity = clamp(localTime / entryDur, 0, 1);
    scale = 0.4 + 0.6 * t;
  } else if (localTime > exitStart) {
    const t = Easing.easeInQuad(clamp((localTime - exitStart) / exitDur, 0, 1));
    opacity = 1 - t;
    scale = 1 - 0.15 * t;
  }

  const overrides = render ? render(spriteCtx) : {};

  return (
    <div style={{
      position: 'absolute',
      left: x, top: y,
      width, height,
      background: color,
      borderRadius: radius,
      opacity,
      transform: `scale(${scale})`,
      transformOrigin: 'center',
      willChange: 'transform, opacity',
      ...overrides,
    }} />
  );
}


function Stage({
  width = 1280,
  height = 720,
  duration = 10,
  background = '#f6f4ef',
  fps = 60,
  loop = true,
  autoplay = true,
  children,
}) {
  const [time, setTime] = React.useState(0);
  const [playing, setPlaying] = React.useState(autoplay);
  const [scale, setScale] = React.useState(1);

  const stageRef = React.useRef(null);
  const canvasRef = React.useRef(null);
  const rafRef = React.useRef(null);
  const lastTsRef = React.useRef(null);

  // Auto-scale to fit viewport
  React.useEffect(() => {
    if (!stageRef.current) return;
    const el = stageRef.current;
    const measure = () => {
      const s = Math.min(
        el.clientWidth / width,
        el.clientHeight / height
      );
      setScale(Math.max(0.05, s));
    };
    measure();
    const ro = new ResizeObserver(measure);
    ro.observe(el);
    window.addEventListener('resize', measure);
    return () => {
      ro.disconnect();
      window.removeEventListener('resize', measure);
    };
  }, [width, height]);

  // Animation loop
  React.useEffect(() => {
    if (!playing) {
      lastTsRef.current = null;
      return;
    }
    const step = (ts) => {
      if (lastTsRef.current == null) lastTsRef.current = ts;
      const dt = (ts - lastTsRef.current) / 1000;
      lastTsRef.current = ts;
      setTime((t) => {
        let next = t + dt;
        if (next >= duration) {
          if (loop) next = next % duration;
          else { next = duration; setPlaying(false); }
        }
        return next;
      });
      rafRef.current = requestAnimationFrame(step);
    };
    rafRef.current = requestAnimationFrame(step);
    return () => {
      if (rafRef.current) cancelAnimationFrame(rafRef.current);
      lastTsRef.current = null;
    };
  }, [playing, duration, loop]);

  const ctxValue = React.useMemo(
    () => ({ time, duration, playing, setTime, setPlaying }),
    [time, duration, playing]
  );

  return (
    <div
      ref={stageRef}
      style={{
        position: 'absolute', inset: 0,
        display: 'flex', flexDirection: 'column',
        alignItems: 'center',
        background,
        fontFamily: 'Inter, system-ui, sans-serif',
      }}
    >
      <div style={{
        flex: 1,
        width: '100%',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        overflow: 'hidden',
        minHeight: 0,
      }}>
        <div
          ref={canvasRef}
          style={{
            width, height,
            background,
            position: 'relative',
            transform: `scale(${scale})`,
            transformOrigin: 'center',
            flexShrink: 0,
            overflow: 'hidden',
          }}
        >
          <TimelineContext.Provider value={ctxValue}>
            {children}
          </TimelineContext.Provider>
        </div>
      </div>
    </div>
  );
}

// ── Playback bar ────────────────────────────────────────────────────────────
// Play/pause, return-to-begin, scrub track, time display.
// Uses fixed-width time fields so layout doesn't thrash.

function PlaybackBar({ time, duration, playing, onPlayPause, onReset, onSeek, onHover }) {
  const trackRef = React.useRef(null);
  const [dragging, setDragging] = React.useState(false);

  const timeFromEvent = React.useCallback((e) => {
    const rect = trackRef.current.getBoundingClientRect();
    const x = clamp((e.clientX - rect.left) / rect.width, 0, 1);
    return x * duration;
  }, [duration]);

  const onTrackMove = (e) => {
    if (!trackRef.current) return;
    const t = timeFromEvent(e);
    if (dragging) {
      onSeek(t);
    } else {
      onHover(t);
    }
  };

  const onTrackLeave = () => {
    if (!dragging) onHover(null);
  };

  const onTrackDown = (e) => {
    setDragging(true);
    const t = timeFromEvent(e);
    onSeek(t);
    onHover(null);
  };

  React.useEffect(() => {
    if (!dragging) return;
    const onUp = () => setDragging(false);
    const onMove = (e) => {
      if (!trackRef.current) return;
      const t = timeFromEvent(e);
      onSeek(t);
    };
    window.addEventListener('mouseup', onUp);
    window.addEventListener('mousemove', onMove);
    return () => {
      window.removeEventListener('mouseup', onUp);
      window.removeEventListener('mousemove', onMove);
    };
  }, [dragging, timeFromEvent, onSeek]);

  const pct = duration > 0 ? (time / duration) * 100 : 0;
  const fmt = (t) => {
    const total = Math.max(0, t);
    const m = Math.floor(total / 60);
    const s = Math.floor(total % 60);
    const cs = Math.floor((total * 100) % 100);
    return `${String(m).padStart(1, '0')}:${String(s).padStart(2, '0')}.${String(cs).padStart(2, '0')}`;
  };

  const mono = 'JetBrains Mono, ui-monospace, SFMono-Regular, monospace';

  return (
    <div style={{
      display: 'flex', alignItems: 'center', gap: 12,
      padding: '8px 16px',
      background: 'rgba(20,20,20,0.92)',
      borderTop: '1px solid rgba(255,255,255,0.08)',
      width: '100%',
      maxWidth: 680,
      alignSelf: 'center',

      borderRadius: 8,
      color: '#f6f4ef',
      fontFamily: 'Inter, system-ui, sans-serif',
      userSelect: 'none',
      flexShrink: 0,
    }}>
      <IconButton onClick={onReset} title="Return to start (0)">
        <svg width="14" height="14" viewBox="0 0 14 14" fill="none">
          <path d="M3 2v10M12 2L5 7l7 5V2z" stroke="currentColor" strokeWidth="1.5" strokeLinejoin="round" strokeLinecap="round"/>
        </svg>
      </IconButton>
      <IconButton onClick={onPlayPause} title="Play/pause (space)">
        {playing ? (
          <svg width="14" height="14" viewBox="0 0 14 14" fill="none">
            <rect x="3" y="2" width="3" height="10" fill="currentColor"/>
            <rect x="8" y="2" width="3" height="10" fill="currentColor"/>
          </svg>
        ) : (
          <svg width="14" height="14" viewBox="0 0 14 14" fill="none">
            <path d="M3 2l9 5-9 5V2z" fill="currentColor"/>
          </svg>
        )}
      </IconButton>

      {/* Current time: fixed width so it doesn't thrash */}
      <div style={{
        fontFamily: mono,
        fontSize: 12,
        fontVariantNumeric: 'tabular-nums',
        width: 64, textAlign: 'right',
        color: '#f6f4ef',
      }}>
        {fmt(time)}
      </div>

      {/* Scrub track */}
      <div
        ref={trackRef}
        onMouseMove={onTrackMove}
        onMouseLeave={onTrackLeave}
        onMouseDown={onTrackDown}
        style={{
          flex: 1,
          height: 22,
          position: 'relative',
          cursor: 'pointer',
          display: 'flex', alignItems: 'center',
        }}
      >
        <div style={{
          position: 'absolute',
          left: 0, right: 0, height: 4,
          background: 'rgba(255,255,255,0.12)',
          borderRadius: 2,
        }}/>
        <div style={{
          position: 'absolute',
          left: 0, width: `${pct}%`, height: 4,
          background: 'oklch(72% 0.12 250)',
          borderRadius: 2,
        }}/>
        <div style={{
          position: 'absolute',
          left: `${pct}%`, top: '50%',
          width: 12, height: 12,
          marginLeft: -6, marginTop: -6,
          background: '#fff',
          borderRadius: 6,
          boxShadow: '0 2px 4px rgba(0,0,0,0.4)',
        }}/>
      </div>

      {/* Duration: fixed width */}
      <div style={{
        fontFamily: mono,
        fontSize: 12,
        fontVariantNumeric: 'tabular-nums',
        width: 64, textAlign: 'left',
        color: 'rgba(246,244,239,0.55)',
      }}>
        {fmt(duration)}
      </div>
    </div>
  );
}

function IconButton({ children, onClick, title }) {
  const [hover, setHover] = React.useState(false);
  return (
    <button
      onClick={onClick}
      title={title}
      onMouseEnter={() => setHover(true)}
      onMouseLeave={() => setHover(false)}
      style={{
        width: 28, height: 28,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        background: hover ? 'rgba(255,255,255,0.12)' : 'rgba(255,255,255,0.04)',
        border: '1px solid rgba(255,255,255,0.1)',
        borderRadius: 6,
        color: '#f6f4ef',
        cursor: 'pointer',
        padding: 0,
        transition: 'background 120ms',
      }}
    >
      {children}
    </button>
  );
}


Object.assign(window, {
  Easing, interpolate, animate, clamp,
  TimelineContext, useTime, useTimeline,
  Sprite, SpriteContext, useSprite,
  TextSprite, ImageSprite, RectSprite,
  Stage, PlaybackBar,
});

/* ════════════════════════════════════════════════════════════════════════
   TETHER — cinematic product animation
   Dark macOS dev-tool UI · monochrome + #10B981 green / #7C3AED purple
   ════════════════════════════════════════════════════════════════════════ */

const C = {
  back:    '#e8e9ed',
  win:     '#ffffff',
  panel:   '#ffffff',
  panelB:  '#fbfbfc',
  card:    '#ffffff',
  cardHi:  '#fcfbff',
  border:  'rgba(17,20,27,0.09)',
  borderS: 'rgba(17,20,27,0.14)',
  text:    '#1a1d23',
  sub:     '#5b6371',
  muted:   '#9298a3',
  faint:   '#bcc1c9',
  green:   '#0E9E70',
  greenD:  'rgba(16,185,129,0.11)',
  greenB:  'rgba(16,185,129,0.38)',
  purple:  '#7C3AED',
  purpleD: 'rgba(124,58,237,0.08)',
  purpleB: 'rgba(124,58,237,0.35)',
  orange:  '#D97706',
  orangeD: 'rgba(245,158,11,0.13)',
  shadow:  '0 6px 22px rgba(20,26,44,0.08)',
  shadowHi:'0 0 0 1px rgba(124,58,237,0.22), 0 10px 30px rgba(124,58,237,0.13)',
};
const MONO = "'Geist Mono', ui-monospace, SFMono-Regular, monospace";
const SANS = "'Geist', system-ui, -apple-system, sans-serif";

// ── timing helpers ──────────────────────────────────────────────────────
function rev(time, start, dur = 0.5, dist = 12, ease = Easing.easeOutCubic) {
  const t = clamp((time - start) / dur, 0, 1);
  const e = ease(t);
  return { opacity: e, ty: (1 - e) * dist, t: e };
}
function countNum(time, start, dur, to, ease = Easing.easeOutCubic) {
  return to * ease(clamp((time - start) / dur, 0, 1));
}
const HEX = '0123456789abcdef';
function scramble(time, start, dur, str) {
  const p = clamp((time - start) / dur, 0, 1);
  if (p >= 1) return str;
  const shown = Math.floor(p * str.length);
  let out = '';
  for (let i = 0; i < str.length; i++) {
    if (i < shown) out += str[i];
    else {
      const n = Math.floor((Math.sin(i * 97.13 + time * 55) * 0.5 + 0.5) * 16) % 16;
      out += HEX[n];
    }
  }
  return out;
}
const commas = (n) => Math.round(n).toLocaleString('en-US');

// ── deterministic particle field ────────────────────────────────────────
function mulberry32(a) {
  return function () {
    a |= 0; a = (a + 0x6D2B79F5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
const _pr = mulberry32(20240618);
const PARTICLES = Array.from({ length: 46 }, () => ({
  x: _pr() * 1920, y: _pr() * 1080, r: 0.8 + _pr() * 2.4,
  sp: 5 + _pr() * 16, drift: _pr() * 36 - 18, ph: _pr() * Math.PI * 2,
  hue: _pr(),
}));

// ── data ────────────────────────────────────────────────────────────────
const NODES = [
  { title: 'Codex response 1', lat: 23.00, down: 29927, up: 216, ts: '10:54:04', status: 'SUCCESS' },
  { title: 'Codex response 2', lat: 8.00,  down: 30196, up: 320, ts: '10:54:29', status: 'SUCCESS' },
  { title: 'Codex response 3', lat: 9.00,  down: 30705, up: 299, ts: '10:54:38', status: 'SUCCESS' },
  { title: 'Codex response 4', lat: 4.00,  down: 39071, up: 108, ts: '10:55:08', status: 'SUCCESS' },
  { title: 'Codex response streaming', lat: null, down: 0, up: 0, ts: '10:55:13', status: 'RUNNING' },
];

// node geometry within the 1020×1008 center canvas
const CW = 1020, NODE_W = 470, NODE_X = (CW - NODE_W) / 2, NODE_H = 128;
const NODE_TOP0 = 158, NODE_STEP = 174;
const nodeTop = (i) => NODE_TOP0 + i * NODE_STEP;
const NODE_CX = CW / 2;

// reveal schedule
const nodeStart = (i) => 3.05 + i * 0.40;

// ── small presentational atoms ──────────────────────────────────────────
function Chip({ children, color, bg, border, mono }) {
  return (
    <span style={{
      display: 'inline-flex', alignItems: 'center', gap: 5,
      padding: '2px 7px', borderRadius: 5,
      fontSize: 11.5, fontWeight: 500, lineHeight: 1,
      fontFamily: mono ? MONO : SANS,
      color: color || C.sub,
      background: bg || 'rgba(255,255,255,0.04)',
      border: `1px solid ${border || C.border}`,
      whiteSpace: 'nowrap',
    }}>{children}</span>
  );
}

function StatusBadge({ status, glow }) {
  const success = status === 'SUCCESS';
  const col = success ? C.green : C.orange;
  const bg = success ? C.greenD : C.orangeD;
  return (
    <span style={{
      fontFamily: MONO, fontSize: 11, fontWeight: 600, letterSpacing: '0.06em',
      color: col, background: bg, padding: '3px 9px', borderRadius: 5,
      border: `1px solid ${success ? C.greenB : 'rgba(245,158,11,0.4)'}`,
      boxShadow: glow ? `0 0 ${glow}px ${success ? C.greenB : 'rgba(245,158,11,0.5)'}` : 'none',
      whiteSpace: 'nowrap',
    }}>{status}</span>
  );
}

// ── sidebar call item ───────────────────────────────────────────────────
function CallItem({ n, time, start, active }) {
  const r = rev(time, start, 0.55, 14);
  const live = n.status === 'RUNNING';
  return (
    <div style={{
      opacity: r.opacity, transform: `translateY(${r.ty}px)`,
      padding: '12px 12px', borderRadius: 9, marginBottom: 4,
      background: active ? C.purpleD : 'transparent',
      border: `1px solid ${active ? 'rgba(124,58,237,0.35)' : 'transparent'}`,
      position: 'relative',
    }}>
      {active && <div style={{ position: 'absolute', left: -1, top: 10, bottom: 10, width: 3, borderRadius: 3, background: C.purple }} />}
      <div style={{ display: 'flex', alignItems: 'center', gap: 9 }}>
        <span style={{ width: 8, height: 8, borderRadius: 5, background: live ? C.orange : C.green, boxShadow: `0 0 7px ${live ? 'rgba(245,158,11,0.6)' : C.greenB}`, flexShrink: 0 }} />
        <span style={{ fontSize: 14, fontWeight: 600, color: C.text, letterSpacing: '-0.01em' }}>{n.title}</span>
        <span style={{ flex: 1 }} />
        <span style={{ fontFamily: MONO, fontSize: 12, color: C.muted }}>$0.0000</span>
      </div>
      <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginTop: 8, paddingLeft: 17 }}>
        <Chip color={C.purple} bg={C.purpleD} border="rgba(124,58,237,0.3)">▣ Codex</Chip>
        <Chip mono color={C.sub} border={C.border}>codex-log / gpt-5.5</Chip>
        <span style={{ fontFamily: MONO, fontSize: 11.5, color: C.faint }}>{n.ts}</span>
        <span style={{ flex: 1 }} />
        <span style={{ fontFamily: MONO, fontSize: 11.5, color: C.muted }}>{live ? 'live' : n.lat.toFixed(2) + 's'}</span>
      </div>
    </div>
  );
}

// ── center node card ────────────────────────────────────────────────────
function NodeCard({ n, i, time }) {
  const start = nodeStart(i);
  const la = time - start;
  const r = rev(time, start, 0.5, 0, Easing.easeOutCubic);
  const pop = la < 0 ? 0.9 : 0.9 + 0.1 * Easing.easeOutBack(clamp(la / 0.5, 0, 1));
  // badge glow flash
  const glow = la > 0 && la < 0.9 ? interpolate([0, 0.18, 0.9], [0, 18, 5], Easing.easeOutCubic)(la) : (la >= 0.9 ? 5 : 0);
  const running = n.status === 'RUNNING';
  // count-ups
  const lat = running ? null : countNum(time, start + 0.1, 0.7, n.lat);
  const down = countNum(time, start + 0.1, 0.8, n.down);
  const up = countNum(time, start + 0.1, 0.8, n.up);

  return (
    <div style={{
      position: 'absolute', left: NODE_X, top: nodeTop(i), width: NODE_W,
      opacity: clamp(r.opacity * 1.2, 0, 1), transform: `scale(${pop})`, transformOrigin: 'center top',
    }}>
      <div style={{
        background: running ? C.cardHi : C.card, borderRadius: 13,
        border: `1px solid ${running ? 'rgba(124,58,237,0.5)' : C.border}`,
        boxShadow: running ? C.shadowHi : C.shadow,
        overflow: 'hidden', position: 'relative',
      }}>
        <div style={{ position: 'absolute', left: 0, top: 14, bottom: 14, width: 3, borderRadius: 3, background: running ? C.orange : C.green }} />
        <div style={{ padding: '15px 18px 13px 20px' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 9 }}>
            <span style={{ width: 8, height: 8, borderRadius: 5, background: running ? C.orange : C.green, boxShadow: `0 0 8px ${running ? 'rgba(245,158,11,0.7)' : C.greenB}` }} />
            <span style={{ fontSize: 16, fontWeight: 650, color: C.text, letterSpacing: '-0.01em' }}>{n.title}</span>
            <span style={{ flex: 1 }} />
            <StatusBadge status={n.status} glow={glow} />
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 9, marginTop: 9, paddingLeft: 17 }}>
            <Chip color={C.purple} bg={C.purpleD} border="rgba(124,58,237,0.3)">▣ Codex</Chip>
            <span style={{ fontFamily: MONO, fontSize: 12.5, color: C.muted }}>codex-log / gpt-5…</span>
          </div>
        </div>
        <div style={{ height: 1, background: C.border }} />
        <div style={{ display: 'flex', alignItems: 'center', padding: '12px 18px 13px 20px', fontFamily: MONO, fontSize: 13 }}>
          <span style={{ color: C.faint }}>lat&nbsp;</span>
          <span style={{ color: running ? C.orange : C.text, fontWeight: 600 }}>{running ? 'live' : lat.toFixed(2) + 's'}</span>
          <span style={{ color: C.faint, marginLeft: 16 }}>cost&nbsp;</span>
          <span style={{ color: C.text }}>$0.0000</span>
          <span style={{ flex: 1 }} />
          <span style={{ color: C.sub }}>
            <span style={{ color: C.text, fontWeight: 600 }}>{commas(down)}</span> down <span style={{ color: C.text, fontWeight: 600 }}>{commas(up)}</span> up tok
          </span>
        </div>
      </div>
    </div>
  );
}

// ── edges between nodes (SVG, flowing downward) ─────────────────────────
function Edges({ time }) {
  return (
    <svg width={CW} height={1008} style={{ position: 'absolute', left: 0, top: 0, pointerEvents: 'none', overflow: 'visible' }}>
      {NODES.slice(0, -1).map((_, i) => {
        const y1 = nodeTop(i) + NODE_H + 2;
        const y2 = nodeTop(i + 1) - 2;
        const purpleEdge = i === NODES.length - 2;
        const col = purpleEdge ? C.purple : C.green;
        const r = rev(time, nodeStart(i + 1) - 0.05, 0.4, 0);
        const len = y2 - y1;
        return (
          <g key={i} opacity={r.opacity}>
            <line x1={NODE_CX} y1={y1} x2={NODE_CX} y2={y2} stroke={col} strokeOpacity={0.28} strokeWidth={2.5} />
            <line x1={NODE_CX} y1={y1} x2={NODE_CX} y2={y2}
              stroke={col} strokeWidth={2.5} strokeLinecap="round"
              strokeDasharray="7 11" strokeDashoffset={-(time * 46) % 18}
              style={{ filter: `drop-shadow(0 0 4px ${purpleEdge ? C.purpleB : C.greenB})` }} />
          </g>
        );
      })}
      {NODES.map((n, i) => {
        const r = rev(time, nodeStart(i), 0.5, 0);
        const running = n.status === 'RUNNING';
        const col = running ? C.orange : C.green;
        return (
          <g key={'c' + i} opacity={r.opacity}>
            <circle cx={NODE_CX} cy={nodeTop(i)} r={6} fill={C.win} stroke={col} strokeWidth={2} />
            <circle cx={NODE_CX} cy={nodeTop(i) + NODE_H + 2} r={6} fill={C.win} stroke={col} strokeWidth={2} />
          </g>
        );
      })}
    </svg>
  );
}

// ── top metric bar ──────────────────────────────────────────────────────
function StatPill({ big, label, color, time, start }) {
  const r = rev(time, start, 0.5, 8);
  return (
    <div style={{
      opacity: r.opacity, transform: `translateY(${r.ty}px)`,
      minWidth: 92, padding: '10px 16px', borderRadius: 11,
      background: C.card, border: `1px solid ${C.border}`, textAlign: 'center',
    }}>
      <div style={{ fontFamily: MONO, fontSize: 20, fontWeight: 650, color: color || C.text, letterSpacing: '-0.01em' }}>{big}</div>
      <div style={{ fontSize: 10.5, fontWeight: 600, letterSpacing: '0.12em', color: C.muted, marginTop: 4 }}>{label}</div>
    </div>
  );
}
function TopBar({ time }) {
  const r = rev(time, 0.7, 0.6, 10);
  const total = countNum(time, 1.2, 1.8, 44);
  const steps = Math.round(countNum(time, 1.2, 1.3, 5));
  return (
    <div style={{ position: 'absolute', left: 36, right: 36, top: 30, display: 'flex', alignItems: 'center', gap: 14 }}>
      <div style={{ opacity: r.opacity, transform: `translateY(${r.ty}px)` }}>
        <div style={{ fontSize: 12.5, color: C.muted, marginBottom: 5 }}>Live trace · Codex response streaming</div>
        <div style={{ fontSize: 22, fontWeight: 650, color: C.text, letterSpacing: '-0.02em' }}>Codex response streaming</div>
      </div>
      <span style={{ flex: 1 }} />
      <StatPill big={total.toFixed(2) + 's'} label="TOTAL TIME" time={time} start={0.9} />
      <StatPill big={steps} label="STEPS" time={time} start={1.05} />
      <StatPill big="1" label="AGENTS" time={time} start={1.2} />
      <StatPill big="LIVE" label="STATUS" color={C.green} time={time} start={1.35} />
    </div>
  );
}

// ── right panel ─────────────────────────────────────────────────────────
function Field({ label, children, time, start, mono }) {
  const r = rev(time, start, 0.5, 8);
  return (
    <div style={{ opacity: r.opacity, transform: `translateY(${r.ty}px)`, display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', padding: '9px 0', borderBottom: `1px solid ${C.border}` }}>
      <span style={{ fontSize: 13.5, color: C.sub }}>{label}</span>
      <span style={{ fontFamily: mono ? MONO : SANS, fontSize: mono ? 13 : 13.5, color: C.text, fontWeight: mono ? 500 : 500 }}>{children}</span>
    </div>
  );
}
function SectionLabel({ children, time, start }) {
  const r = rev(time, start, 0.5, 8);
  return <div style={{ opacity: r.opacity, transform: `translateY(${r.ty}px)`, fontSize: 12, fontWeight: 600, letterSpacing: '0.08em', textTransform: 'uppercase', color: C.muted, margin: '20px 0 4px' }}>{children}</div>;
}
function RightPanel({ time }) {
  const head = rev(time, 5.5, 0.6, 10);
  const b1 = rev(time, 8.4, 0.55, 14);
  const b2 = rev(time, 8.6, 0.55, 14);
  const inHash = scramble(time, 6.05, 0.9, 'b766571dfb12c742');
  const outHash = scramble(time, 6.25, 0.9, 'c9a4c9bcd43e924a');
  const outHash2 = scramble(time, 7.6, 0.9, 'c9a4c9bcd43e924a');
  const tabs = ['Context', 'LLM Call', 'Response', 'Metadata'];
  return (
    <div style={{ position: 'relative', height: '100%', display: 'flex', flexDirection: 'column' }}>
      <div style={{ padding: '26px 26px 0', flex: 1, overflow: 'hidden' }}>
        <div style={{ opacity: head.opacity, transform: `translateY(${head.ty}px)` }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            <span style={{ width: 9, height: 9, borderRadius: 5, background: C.orange, boxShadow: '0 0 8px rgba(245,158,11,0.6)' }} />
            <span style={{ fontSize: 17, fontWeight: 650, color: C.text, letterSpacing: '-0.01em' }}>Codex response streaming</span>
          </div>
          <div style={{ display: 'flex', gap: 8, marginTop: 11, paddingLeft: 19 }}>
            <Chip color={C.purple} bg={C.purpleD} border="rgba(124,58,237,0.3)">▣ Codex</Chip>
            <Chip mono color={C.sub}>codex-log / gpt-5.5</Chip>
          </div>
          <div style={{ display: 'flex', gap: 26, marginTop: 20, borderBottom: `1px solid ${C.border}` }}>
            {tabs.map((t, i) => (
              <span key={t} style={{ paddingBottom: 11, fontSize: 13.5, fontWeight: i === 0 ? 600 : 500, color: i === 0 ? C.text : C.muted, borderBottom: i === 0 ? `2px solid ${C.green}` : '2px solid transparent', marginBottom: -1 }}>{t}</span>
            ))}
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginTop: 16 }}>
            <span style={{ fontFamily: MONO, fontSize: 13, color: C.muted, flex: 1 }}>context.assembly</span>
            <Chip>2 sources</Chip><Chip>0 withheld</Chip>
            <Chip color={C.green} bg={C.greenD} border={C.greenB}>fresh</Chip>
          </div>
        </div>

        <SectionLabel time={time} start={5.9}>Boundary Hashes</SectionLabel>
        <Field label="Input Hash" mono time={time} start={6.0}>{inHash}</Field>
        <Field label="Output Hash" mono time={time} start={6.15}>{outHash}</Field>
        <Field label="Trace ID" mono time={time} start={6.3}>n/a</Field>
        <Field label="Parent Span" mono time={time} start={6.45}>root</Field>

        <SectionLabel time={time} start={6.7}>Input Sources</SectionLabel>
        <Field label="› Inline Segments" time={time} start={6.85}><span style={{ fontFamily: MONO, color: C.sub }}>2</span></Field>

        <SectionLabel time={time} start={7.1}>Withheld / Deferred</SectionLabel>
        <Field label="" mono time={time} start={7.25}><span style={{ color: C.faint }}>none</span></Field>

        <SectionLabel time={time} start={7.45}>Replay Boundary</SectionLabel>
        <Field label="Reason" time={time} start={7.55}><span style={{ color: C.faint }}>none</span></Field>
        <Field label="Output Hash" mono time={time} start={7.7}>{outHash2}</Field>
      </div>

      <div style={{ padding: '0 26px 26px', display: 'flex', flexDirection: 'column', gap: 12 }}>
        <button style={{
          opacity: b1.opacity, transform: `translateY(${b1.ty}px)`,
          width: '100%', padding: '15px 0', borderRadius: 11,
          background: '#1a1f27', color: '#ffffff', border: `1px solid ${C.borderS}`,
          fontFamily: SANS, fontSize: 14.5, fontWeight: 600, letterSpacing: '-0.01em', cursor: 'pointer',
        }}>Time-Travel · Edit Response</button>
        <button style={{
          opacity: b2.opacity, transform: `translateY(${b2.ty}px)`,
          width: '100%', padding: '15px 0', borderRadius: 11,
          background: 'transparent', color: C.sub, border: `1px solid ${C.border}`,
          fontFamily: SANS, fontSize: 14.5, fontWeight: 600, letterSpacing: '-0.01em', cursor: 'pointer',
        }}>Run 3× and compare</button>
      </div>
    </div>
  );
}

// ── sidebar ─────────────────────────────────────────────────────────────
function Sidebar({ time }) {
  const head = rev(time, 0.5, 0.6, 10);
  const filt = rev(time, 0.7, 0.5, 8);
  const callsHdr = rev(time, 0.85, 0.5, 8);
  const settings = rev(time, 1.0, 0.5, 8);
  return (
    <div style={{ width: 360, flexShrink: 0, borderRight: `1px solid ${C.border}`, background: C.panel, display: 'flex', flexDirection: 'column', height: '100%' }}>
      <div style={{ padding: '20px 20px 0', flex: 1, overflow: 'hidden' }}>
        <div style={{ display: 'flex', gap: 8, marginBottom: 20 }}>
          <span style={{ width: 12, height: 12, borderRadius: 6, background: '#ff5f57' }} />
          <span style={{ width: 12, height: 12, borderRadius: 6, background: '#febc2e' }} />
          <span style={{ width: 12, height: 12, borderRadius: 6, background: '#28c840' }} />
        </div>
        <div style={{ opacity: head.opacity, transform: `translateY(${head.ty}px)`, background: C.greenD, border: `1px solid ${C.greenB}`, borderRadius: 11, padding: '13px 15px', display: 'flex', gap: 12, alignItems: 'center' }}>
          <span style={{ width: 34, height: 34, borderRadius: 9, background: 'rgba(16,185,129,0.18)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: C.green, fontFamily: MONO, fontSize: 16 }}>❯_</span>
          <div>
            <div style={{ color: C.green, fontWeight: 650, fontSize: 14.5 }}>Tether</div>
            <div style={{ color: 'rgba(16,185,129,0.7)', fontSize: 12.5, marginTop: 2 }}>Observing Terminal Codex</div>
          </div>
        </div>
        <div style={{ opacity: filt.opacity, transform: `translateY(${filt.ty}px)`, marginTop: 16, padding: '11px 14px', borderRadius: 9, background: C.card, border: `1px solid ${C.border}`, color: C.faint, fontSize: 13.5 }}>Filter calls…</div>
        <div style={{ opacity: callsHdr.opacity, display: 'flex', justifyContent: 'space-between', alignItems: 'center', margin: '22px 4px 10px' }}>
          <span style={{ fontSize: 12, fontWeight: 600, letterSpacing: '0.08em', textTransform: 'uppercase', color: C.muted }}>Calls</span>
          <span style={{ fontSize: 12, color: C.faint, fontFamily: MONO }}>5 of 5</span>
        </div>
        {NODES.map((n, i) => (
          <CallItem key={i} n={n} time={time} start={1.0 + i * 0.3} active={i === NODES.length - 1} />
        ))}
      </div>
      <div style={{ padding: '0 20px 20px' }}>
        <div style={{ opacity: settings.opacity, transform: `translateY(${settings.ty}px)`, padding: '13px 0', borderRadius: 9, border: `1px solid ${C.border}`, textAlign: 'center', color: C.sub, fontSize: 13.5, fontWeight: 500 }}>⚙ Settings</div>
      </div>
    </div>
  );
}

// ── window (the whole app) ──────────────────────────────────────────────
function AppWindow({ time }) {
  return (
    <div style={{
      position: 'absolute', left: 40, top: 36, width: 1840, height: 1008,
      background: C.win, borderRadius: 18, overflow: 'hidden',
      border: `1px solid ${C.borderS}`,
      boxShadow: '0 30px 90px rgba(20,26,44,0.16), 0 2px 8px rgba(20,26,44,0.06)',
      display: 'flex',
    }}>
      <Sidebar time={time} />
      <div style={{ width: 1020, flexShrink: 0, position: 'relative', background: C.panelB }}>
        <TopBar time={time} />
        <Edges time={time} />
        {NODES.map((n, i) => <NodeCard key={i} n={n} i={i} time={time} />)}
      </div>
      <div style={{ width: 460, flexShrink: 0, borderLeft: `1px solid ${C.border}`, background: C.panel }}>
        <RightPanel time={time} />
      </div>
    </div>
  );
}

// ── particle layer ──────────────────────────────────────────────────────
function Particles({ time }) {
  return (
    <div style={{ position: 'absolute', inset: 0, overflow: 'hidden', pointerEvents: 'none' }}>
      {PARTICLES.map((p, i) => {
        const y = ((p.y - time * p.sp) % 1080 + 1080) % 1080;
        const x = p.x + Math.sin(time * 0.3 + p.ph) * p.drift;
        const col = p.hue < 0.68 ? 'rgba(40,50,70,0.45)' : p.hue < 0.85 ? 'rgba(16,185,129,0.6)' : 'rgba(124,58,237,0.6)';
        return <div key={i} style={{ position: 'absolute', left: x, top: y, width: p.r * 2, height: p.r * 2, borderRadius: '50%', background: col, opacity: 0.16 + 0.1 * Math.sin(time * 0.8 + p.ph) }} />;
      })}
    </div>
  );
}

// ── camera ──────────────────────────────────────────────────────────────
const CAM_T = [0, 0.8, 2.8, 5.8, 8.3, 9.6, 11.3, 12];
const CAM_EASE = Array(7).fill(Easing.easeInOutCubic);
const camS = interpolate(CAM_T, [1.00, 1.00, 1.18, 1.42, 1.46, 1.52, 1.00, 1.00], CAM_EASE);
const camX = interpolate(CAM_T, [960, 960, 600, 1010, 1660, 1660, 960, 960], CAM_EASE);
const camY = interpolate(CAM_T, [540, 540, 520, 600, 540, 860, 540, 540], CAM_EASE);

// ── app layer (camera + particles + window), driven by appTime ───────────
function AppLayer({ time }) {
  const S = camS(time), fx = camX(time), fy = camY(time);
  const tx = 960 - S * fx, ty = 540 - S * fy;
  const fadeIn = 1 - clamp(time / 0.7, 0, 1);
  const fadeOut = clamp((time - 11.4) / 0.6, 0, 1);
  const whiteout = Math.max(fadeIn, fadeOut);
  return (
    <div style={{ position: 'absolute', inset: 0, background: C.back, overflow: 'hidden' }}>
      <div style={{ position: 'absolute', inset: 0, background: 'radial-gradient(130% 120% at 50% 28%, transparent 62%, rgba(20,26,44,0.07) 100%)', pointerEvents: 'none', zIndex: 3 }} />
      <div style={{ position: 'absolute', inset: 0, transform: `translate(${tx}px, ${ty}px) scale(${S})`, transformOrigin: '0 0', willChange: 'transform' }}>
        <Particles time={time} />
        <AppWindow time={time} />
      </div>
      <div style={{ position: 'absolute', inset: 0, background: '#fff', opacity: whiteout, pointerEvents: 'none', zIndex: 5 }} />
    </div>
  );
}

function TetherScene() {
  const time = useTime();
  return (
    <div data-screen-label={String(Math.floor(time)) + 's'} style={{ position: 'absolute', inset: 0, background: '#fff', overflow: 'hidden' }}>
      <AppLayer time={time} />
    </div>
  );
}

const TOTAL = 12;
function TetherVideoLight() {
  return (
    <Stage width={1920} height={1080} duration={TOTAL} background="#fff">
      <TetherScene />
    </Stage>
  );
}

window.TetherVideoLight = TetherVideoLight;
if (typeof module !== 'undefined') { try { module.exports = { TetherVideoLight }; } catch (e) {} }
