// tiles.jsx — Okey tile primitives
// Tile colors: 'red' | 'black' | 'yellow' | 'blue' | 'joker'
// Styles: 'classic' | 'flat' | 'minimal' | 'bold'

const TILE_COLOR_VAR = {
  red: 'var(--tile-red)',
  black: 'var(--tile-black)',
  yellow: 'var(--tile-yellow)',
  blue: 'var(--tile-blue)',
};

function Tile({ n, color = 'red', size = 'md', style = 'classic', selected, ghost, faded, onClick }) {
  // size presets
  const sizes = {
    xs: { w: 22, h: 30, fs: 13, fs2: 11, r: 3 },
    sm: { w: 30, h: 42, fs: 18, fs2: 12, r: 4 },
    md: { w: 38, h: 54, fs: 22, fs2: 14, r: 5 },
    lg: { w: 46, h: 66, fs: 28, fs2: 16, r: 6 },
    xl: { w: 60, h: 84, fs: 36, fs2: 20, r: 8 },
  };
  const s = sizes[size] || sizes.md;
  const isJoker = color === 'joker';
  const c = isJoker ? 'var(--tile-black)' : TILE_COLOR_VAR[color];

  // shared wrapper
  const wrap = {
    width: s.w, height: s.h, borderRadius: s.r,
    position: 'relative', flexShrink: 0,
    display: 'flex', alignItems: 'center', justifyContent: 'center',
    cursor: onClick ? 'pointer' : 'default',
    opacity: faded ? 0.3 : 1,
    transition: 'transform 0.15s, opacity 0.2s, box-shadow 0.2s',
    transform: selected ? 'translateY(-4px)' : 'none',
  };

  // CLASSIC — cream face, thin top edge, soft inner bevel
  if (style === 'classic') {
    return (
      <div onClick={onClick} style={{
        ...wrap,
        background: 'linear-gradient(180deg, var(--tile-face) 0%, var(--tile-face-edge) 100%)',
        boxShadow: selected
          ? '0 4px 10px rgba(0,0,0,0.18), inset 0 1px 0 rgba(255,255,255,0.7), 0 0 0 1.5px var(--accent)'
          : '0 1px 2px rgba(0,0,0,0.08), inset 0 1px 0 rgba(255,255,255,0.7), inset 0 -1px 0 rgba(0,0,0,0.05)',
      }}>
        {isJoker ? <JokerGlyph c={c} size={s.fs} /> : (
          <div style={{
            fontFamily: 'var(--serif)', fontSize: s.fs * 1.05, lineHeight: 1,
            color: c, fontWeight: 400, fontVariantNumeric: 'lining-nums',
            transform: 'translateY(1px)',
          }}>{n}</div>
        )}
        {/* horizontal seam */}
        <div style={{
          position: 'absolute', left: 3, right: 3, top: '52%',
          height: 1, background: 'rgba(0,0,0,0.05)',
        }} />
      </div>
    );
  }

  // FLAT — colored face matches number color, white digit
  if (style === 'flat') {
    return (
      <div onClick={onClick} style={{
        ...wrap,
        background: isJoker ? 'var(--ink)' : c,
        boxShadow: selected ? `0 4px 12px rgba(0,0,0,0.2), 0 0 0 2px var(--accent)` : '0 1px 2px rgba(0,0,0,0.08)',
      }}>
        {isJoker ? <JokerGlyph c="#fff" size={s.fs} /> : (
          <div style={{
            fontFamily: 'var(--mono)', fontSize: s.fs, lineHeight: 1,
            color: '#fff', fontWeight: 500,
          }}>{n}</div>
        )}
      </div>
    );
  }

  // MINIMAL — white card, colored dot + number stacked
  if (style === 'minimal') {
    return (
      <div onClick={onClick} style={{
        ...wrap,
        background: 'var(--surface)',
        border: '1px solid var(--line)',
        flexDirection: 'column', gap: 3,
        boxShadow: selected ? `0 0 0 2px var(--accent), 0 4px 10px rgba(0,0,0,0.1)` : 'none',
      }}>
        {isJoker ? <JokerGlyph c={c} size={s.fs * 0.7} /> : (
          <>
            <div style={{ width: s.fs * 0.32, height: s.fs * 0.32, borderRadius: '50%', background: c }} />
            <div style={{
              fontFamily: 'var(--mono)', fontSize: s.fs * 0.85, lineHeight: 1,
              color: 'var(--ink)', fontWeight: 500,
            }}>{n}</div>
          </>
        )}
      </div>
    );
  }

  // BOLD — chunky cream tile, oversized serif numeral
  if (style === 'bold') {
    return (
      <div onClick={onClick} style={{
        ...wrap,
        background: 'var(--tile-face)',
        borderRadius: s.r + 2,
        boxShadow: selected
          ? '0 6px 14px rgba(0,0,0,0.2), inset 0 2px 0 rgba(255,255,255,0.7), 0 0 0 2px var(--accent)'
          : '0 2px 4px rgba(0,0,0,0.1), inset 0 2px 0 rgba(255,255,255,0.7), inset 0 -2px 0 rgba(0,0,0,0.06)',
      }}>
        {isJoker ? <JokerGlyph c={c} size={s.fs} /> : (
          <div style={{
            fontFamily: 'var(--serif)', fontSize: s.fs * 1.35, lineHeight: 1,
            color: c, fontWeight: 400, fontStyle: 'italic',
            transform: 'translateY(2px)',
          }}>{n}</div>
        )}
      </div>
    );
  }

  return null;
}

function JokerGlyph({ c, size = 22 }) {
  // a simple star/asterisk-like mark to represent the okey/joker
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none">
      <path d="M12 3v18M5 8l14 8M5 16l14-8M3 12h18"
            stroke={c} strokeWidth="2.2" strokeLinecap="round" />
      <circle cx="12" cy="12" r="2" fill={c} />
    </svg>
  );
}

// Ghost slot for empty positions
function TileSlot({ size = 'md' }) {
  const sizes = { xs:[22,30,3], sm:[30,42,4], md:[38,54,5], lg:[46,66,6], xl:[60,84,8] };
  const [w, h, r] = sizes[size];
  return (
    <div style={{
      width: w, height: h, borderRadius: r, flexShrink: 0,
      border: '1.5px dashed var(--line-2)',
      background: 'transparent',
    }} />
  );
}

// Group — labels a row/column of tiles as a meld
function Meld({ tiles, label, score, tileStyle, size = 'md' }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 8 }}>
        <div className="eyebrow" style={{ whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{label}</div>
        {score !== undefined && (
          <div className="mono" style={{ fontSize: 11, color: 'var(--accent)', fontWeight: 500 }}>
            +{score}
          </div>
        )}
      </div>
      <div style={{
        display: 'flex', gap: 3, padding: '6px 8px',
        background: 'var(--accent-soft)',
        borderRadius: 8,
        alignSelf: 'flex-start',
      }}>
        {tiles.map((t, i) => (
          <Tile key={i} n={t.n} color={t.color} size={size} style={tileStyle} />
        ))}
      </div>
    </div>
  );
}

// Rack — physical-looking rack with rows of tiles
function Rack({ tiles, tileStyle, size = 'sm', highlights = {} }) {
  // split into two rows of 7
  const row1 = tiles.slice(0, 7);
  const row2 = tiles.slice(7, 14);
  return (
    <div className="rack" style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
      {[row1, row2].map((row, ri) => (
        <div key={ri} style={{ display: 'flex', gap: 3, justifyContent: 'flex-start' }}>
          {row.map((t, i) => {
            const idx = ri * 7 + i;
            const hl = highlights[idx];
            return (
              <div key={i} style={{ position: 'relative' }}>
                <Tile n={t.n} color={t.color} size={size} style={tileStyle} />
                {hl && (
                  <div style={{
                    position: 'absolute', inset: -2, borderRadius: 7,
                    border: `1.5px solid ${hl}`,
                    pointerEvents: 'none',
                  }} />
                )}
              </div>
            );
          })}
        </div>
      ))}
    </div>
  );
}

Object.assign(window, { Tile, TileSlot, Meld, Rack, JokerGlyph });
