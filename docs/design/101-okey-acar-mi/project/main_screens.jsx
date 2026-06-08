// main_screens.jsx — home, camera, analyze, review, result, history, settings

// ─── shared bottom nav ───
function BottomNav({ active, onNav, t }) {
  const tr = t === 'tr';
  const items = [
    { k: 'home', label: tr ? 'Ana' : 'Home', icon: 'home' },
    { k: 'history', label: tr ? 'Geçmiş' : 'History', icon: 'history' },
    { k: 'settings', label: tr ? 'Ayar' : 'Settings', icon: 'settings' },
  ];
  return (
    <div style={{
      position: 'absolute', left: 0, right: 0, bottom: 0,
      paddingBottom: 30, paddingTop: 10, paddingLeft: 12, paddingRight: 12,
      background: 'color-mix(in oklab, var(--bg) 88%, transparent)',
      borderTop: '1px solid var(--line)',
      backdropFilter: 'blur(20px)', WebkitBackdropFilter: 'blur(20px)',
      display: 'flex', justifyContent: 'space-around', zIndex: 30,
    }}>
      {items.map(it => {
        const on = active === it.k;
        return (
          <button key={it.k} onClick={() => onNav(it.k)} style={{
            background: 'none', border: 'none', cursor: 'pointer', padding: '6px 12px',
            display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 3,
            color: on ? 'var(--ink)' : 'var(--muted)', fontFamily: 'var(--sans)',
          }}>
            <Icon name={it.icon} size={22} stroke={on ? 1.8 : 1.5} />
            <span style={{ fontSize: 10, fontWeight: on ? 500 : 400, letterSpacing: '0.02em' }}>{it.label}</span>
          </button>
        );
      })}
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// HOME
// ─────────────────────────────────────────────────────────────
function HomeScreen({ onScan, onHistory, onTutorial, t, gameMode, setGameMode, recentRack, tile, layout = 'cards' }) {
  const tr = t === 'tr';
  return (
    <div className="scroll" style={{ paddingBottom: 110 }}>
      {/* top bar */}
      <div style={{ padding: '60px 20px 0', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <div className="eyebrow" style={{ whiteSpace: 'nowrap' }}>{tr ? 'AÇAR MI?' : 'AÇAR MI?'}</div>
        <button onClick={onTutorial} style={{
          width: 40, height: 40, background: 'var(--surface-2)', border: '1px solid var(--line)',
          borderRadius: 100, display: 'flex', alignItems: 'center', justifyContent: 'center',
          color: 'var(--ink)', cursor: 'pointer',
        }}>
          <Icon name="help" size={18} />
        </button>
      </div>

      {/* greeting */}
      <div style={{ padding: '8px 24px 14px' }}>
        <div className="serif" style={{ fontSize: 36, lineHeight: 1.05, letterSpacing: '-0.02em' }}>
          {tr ? 'Selam,' : 'Hello,'}<br/>
          <span style={{ color: 'var(--muted)' }}>{tr ? 'oyuna başlayalım.' : 'shall we play?'}</span>
        </div>
      </div>

      {/* game mode chooser */}
      <div style={{ padding: '6px 20px 16px' }}>
        <div className="eyebrow" style={{ marginBottom: 8 }}>{tr ? 'OYUN MODU' : 'GAME MODE'}</div>
        <div style={{ display: 'flex', gap: 8 }}>
          {[
            { k: '101', label: '101 Okey', sub: tr ? 'Puanla aç' : 'Open with 101' },
            { k: 'okey', label: 'Okey', sub: tr ? 'Klasik' : 'Classic' },
          ].map(m => {
            const on = gameMode === m.k;
            return (
              <button key={m.k} onClick={() => setGameMode(m.k)} style={{
                flex: 1, textAlign: 'left', padding: '14px 14px',
                borderRadius: 'var(--r-md)', cursor: 'pointer',
                background: on ? 'var(--ink)' : 'var(--surface)',
                border: '1px solid ' + (on ? 'var(--ink)' : 'var(--line)'),
                color: on ? 'var(--bg)' : 'var(--ink)',
                fontFamily: 'var(--sans)',
                transition: 'background 0.15s, color 0.15s',
              }}>
                <div style={{ fontSize: 15, fontWeight: 500 }}>{m.label}</div>
                <div style={{ fontSize: 12, opacity: 0.7, marginTop: 2 }}>{m.sub}</div>
              </button>
            );
          })}
        </div>
      </div>

      {/* PRIMARY: scan CTA */}
      <div style={{ padding: '4px 20px 18px' }}>
        <button onClick={onScan} style={{
          width: '100%', minHeight: layout === 'hero' ? 220 : 180, borderRadius: 'var(--r-xl)',
          border: 'none', cursor: 'pointer', position: 'relative', overflow: 'hidden',
          background: 'var(--ink)', color: 'var(--bg)',
          padding: '22px 22px', textAlign: 'left', fontFamily: 'var(--sans)',
        }}>
          {/* faint tile illustration */}
          <div style={{
            position: 'absolute', right: -10, bottom: -20,
            display: 'flex', gap: 4, opacity: 0.16, transform: 'rotate(-8deg)',
          }}>
            {[{n:7,c:'red'},{n:8,c:'red'},{n:9,c:'red'}].map((x,i)=>(
              <div key={i} style={{
                width: 60, height: 84, borderRadius: 8,
                background: 'rgba(255,255,255,0.9)',
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                fontFamily: 'var(--serif)', fontSize: 44, color: 'var(--ink)',
              }}>{x.n}</div>
            ))}
          </div>

          <div className="eyebrow" style={{ color: 'rgba(255,255,255,0.5)' }}>
            {tr ? 'YENİ TARAMA' : 'NEW SCAN'}
          </div>
          <div className="serif" style={{ fontSize: 36, lineHeight: 1, marginTop: 8, letterSpacing: '-0.02em' }}>
            {tr ? 'Istakanı çek.' : 'Snap the rack.'}
          </div>
          <div style={{
            fontSize: 13, opacity: 0.65, marginTop: 8, maxWidth: 220, lineHeight: 1.4,
          }}>
            {tr ? '14 taşını taratıver — en iyi açılışı sana söyleyelim.' : 'Detect all 14 — we\u2019ll find your best play.'}
          </div>
          <div style={{
            position: 'absolute', right: 16, bottom: 16,
            width: 56, height: 56, borderRadius: 100,
            background: 'var(--bg)', color: 'var(--ink)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            boxShadow: '0 6px 16px rgba(0,0,0,0.3)',
          }}>
            <Icon name="camera" size={26} stroke={1.5} />
          </div>
        </button>
      </div>

      {/* recent scan */}
      <div style={{ padding: '8px 20px 0' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 10 }}>
          <span className="eyebrow">{tr ? 'SON TARAMA' : 'LAST SCAN'}</span>
          <button onClick={onHistory} style={{ background: 'none', border: 'none', color: 'var(--muted)', fontSize: 12, fontFamily: 'var(--sans)', cursor: 'pointer' }}>
            {tr ? 'Tümü →' : 'See all →'}
          </button>
        </div>

        <div className="card" style={{ padding: 14 }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 10 }}>
            <span className="mono" style={{ fontSize: 11, color: 'var(--muted)' }}>
              {tr ? 'Bugün · 21:48' : 'Today · 21:48'}
            </span>
            <span className="pill pill-good">
              <Icon name="check" size={11} stroke={2.4} /> {tr ? 'Açtı' : 'Opened'} · 104
            </span>
          </div>
          <Rack tiles={recentRack} tileStyle={tile} size="xs" />
        </div>
      </div>

      {/* stats */}
      <div style={{ padding: '20px 20px 0', display: 'flex', gap: 10 }}>
        <StatCard label={tr ? 'TOPLAM TARAMA' : 'TOTAL SCANS'} value="47" />
        <StatCard label={tr ? 'AÇILIŞ ORANI' : 'OPEN RATE'} value="68%" accent />
        <StatCard label={tr ? 'EN İYİ' : 'BEST'} value="142" />
      </div>
    </div>
  );
}

function StatCard({ label, value, accent }) {
  return (
    <div className="card" style={{ flex: 1, padding: 14 }}>
      <div className="eyebrow" style={{ fontSize: 9.5, marginBottom: 6 }}>{label}</div>
      <div className="mono" style={{
        fontSize: 22, fontWeight: 500, color: accent ? 'var(--accent)' : 'var(--ink)', letterSpacing: '-0.02em',
      }}>{value}</div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// CAMERA
// ─────────────────────────────────────────────────────────────
function CameraScreen({ onCapture, onBack, t, captureMode, setCaptureMode, tile }) {
  const tr = t === 'tr';
  const [flash, setFlash] = React.useState(false);

  return (
    <div style={{
      position: 'absolute', inset: 0,
      background: '#0a0a0a', color: '#fff',
      display: 'flex', flexDirection: 'column',
    }}>
      {/* faux camera viewfinder background */}
      <div style={{
        position: 'absolute', inset: 0,
        background: 'radial-gradient(ellipse at center, oklch(0.32 0.04 60) 0%, oklch(0.18 0.03 60) 60%, #000 100%)',
      }} />

      {/* simulated rack on the table */}
      <div style={{
        position: 'absolute', left: '50%', top: '50%',
        transform: 'translate(-50%, -50%) perspective(900px) rotateX(18deg)',
        opacity: 0.85,
      }}>
        <div style={{
          background: 'linear-gradient(180deg, #5a3a1c, #3b240f)',
          padding: '14px 12px 26px', borderRadius: 4,
          boxShadow: '0 20px 50px rgba(0,0,0,0.6)',
        }}>
          <div style={{ display: 'flex', gap: 3, marginBottom: 6 }}>
            {[{n:5,c:'red'},{n:6,c:'red'},{n:7,c:'red'},{n:11,c:'blue'},{n:11,c:'yellow'},{n:11,c:'black'},{n:1,c:'yellow'}].map((x,i)=>(
              <Tile key={i} n={x.n} color={x.c} size="sm" style={tile} />
            ))}
          </div>
          <div style={{ display: 'flex', gap: 3 }}>
            {[{n:9,c:'blue'},{n:10,c:'blue'},{n:12,c:'red'},{n:3,c:'black'},{n:7,c:'yellow'},{n:13,c:'yellow'},{n:'',c:'joker'}].map((x,i)=>(
              <Tile key={i} n={x.n} color={x.c} size="sm" style={tile} />
            ))}
          </div>
        </div>
      </div>

      {/* viewfinder reticle */}
      <ViewfinderReticle />

      {/* top controls */}
      <div style={{
        position: 'absolute', top: 60, left: 0, right: 0, zIndex: 10,
        padding: '0 18px', display: 'flex', justifyContent: 'space-between', alignItems: 'center',
      }}>
        <GlassBtn onClick={onBack}><Icon name="arrow-left" size={20} /></GlassBtn>
        <div style={{
          padding: '8px 14px', background: 'rgba(0,0,0,0.35)', borderRadius: 100,
          fontFamily: 'var(--mono)', fontSize: 11, letterSpacing: '0.08em', color: '#fff',
          backdropFilter: 'blur(20px)', whiteSpace: 'nowrap',
        }}>
          {tr ? 'ISTAKAYI ÇERÇEVELE' : 'FRAME THE RACK'}
        </div>
        <GlassBtn onClick={() => setFlash(f => !f)}>
          <Icon name="flash" size={20} style={{ fill: flash ? 'var(--accent)' : 'none', color: flash ? 'var(--accent)' : '#fff' }} />
        </GlassBtn>
      </div>

      {/* bottom controls */}
      <div style={{
        position: 'absolute', bottom: 0, left: 0, right: 0, zIndex: 10,
        padding: '0 20px 50px', display: 'flex', flexDirection: 'column', gap: 22,
      }}>
        {/* mode toggle */}
        <div style={{ display: 'flex', justifyContent: 'center', gap: 6 }}>
          {[
            { k: 'photo', label: tr ? 'Fotoğraf' : 'Photo', icon: 'camera' },
            { k: 'video', label: tr ? 'Video' : 'Video', icon: 'video' },
            { k: 'gallery', label: tr ? 'Galeri' : 'Gallery', icon: 'gallery' },
          ].map(m => {
            const on = captureMode === m.k;
            return (
              <button key={m.k} onClick={() => setCaptureMode(m.k)} style={{
                padding: '8px 14px', borderRadius: 100, cursor: 'pointer',
                background: on ? 'rgba(255,255,255,0.95)' : 'rgba(255,255,255,0.12)',
                color: on ? '#000' : '#fff', border: 'none',
                fontSize: 12, fontFamily: 'var(--sans)', fontWeight: 500,
                display: 'flex', alignItems: 'center', gap: 6,
                backdropFilter: 'blur(20px)',
              }}>
                <Icon name={m.icon} size={14} /> {m.label}
              </button>
            );
          })}
        </div>

        {/* shutter row */}
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <div style={{ width: 50, height: 50, borderRadius: 12, background: 'rgba(255,255,255,0.15)', backdropFilter: 'blur(10px)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <Icon name="gallery" size={20} />
          </div>
          <button onClick={onCapture} style={{
            width: 78, height: 78, borderRadius: '50%', cursor: 'pointer',
            background: 'transparent', border: '3px solid #fff',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            padding: 0,
          }}>
            <div style={{
              width: 64, height: 64, borderRadius: '50%',
              background: captureMode === 'video' ? '#e53935' : '#fff',
            }} />
          </button>
          <button style={{ width: 50, height: 50, borderRadius: 12, background: 'rgba(255,255,255,0.15)', backdropFilter: 'blur(10px)', border: 'none', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#fff' }}>
            <Icon name="rotate" size={22} />
          </button>
        </div>
      </div>
    </div>
  );
}

function ViewfinderReticle() {
  // animated corner brackets framing the tile rack
  const c = '#fff';
  return (
    <div style={{
      position: 'absolute', left: '50%', top: '50%',
      transform: 'translate(-50%, -50%)',
      width: 330, height: 220, pointerEvents: 'none',
    }}>
      {[[0,0],[1,0],[0,1],[1,1]].map(([x, y], i) => (
        <div key={i} style={{
          position: 'absolute',
          [x ? 'right' : 'left']: -2,
          [y ? 'bottom' : 'top']: -2,
          width: 26, height: 26,
          borderTop: y ? 'none' : `2px solid ${c}`,
          borderBottom: y ? `2px solid ${c}` : 'none',
          borderLeft: x ? 'none' : `2px solid ${c}`,
          borderRight: x ? `2px solid ${c}` : 'none',
          borderTopLeftRadius: !x && !y ? 4 : 0,
          borderTopRightRadius: x && !y ? 4 : 0,
          borderBottomLeftRadius: !x && y ? 4 : 0,
          borderBottomRightRadius: x && y ? 4 : 0,
        }} />
      ))}
    </div>
  );
}

function GlassBtn({ children, onClick }) {
  return (
    <button onClick={onClick} style={{
      width: 44, height: 44, borderRadius: 100, cursor: 'pointer',
      background: 'rgba(0,0,0,0.35)', border: 'none', color: '#fff',
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      backdropFilter: 'blur(20px)', WebkitBackdropFilter: 'blur(20px)',
    }}>{children}</button>
  );
}

// ─────────────────────────────────────────────────────────────
// ANALYZING (loading)
// ─────────────────────────────────────────────────────────────
function AnalyzingScreen({ onDone, t, tile, rack }) {
  const tr = t === 'tr';
  const [step, setStep] = React.useState(0);
  const steps = tr
    ? ['Görüntü işleniyor…', 'Taşlar tanınıyor…', 'Renk + sayı eşleniyor…', 'En iyi diziliş hesaplanıyor…']
    : ['Processing image…', 'Detecting tiles…', 'Matching color + number…', 'Computing best arrangement…'];

  React.useEffect(() => {
    const t1 = setTimeout(() => setStep(1), 600);
    const t2 = setTimeout(() => setStep(2), 1300);
    const t3 = setTimeout(() => setStep(3), 2000);
    const t4 = setTimeout(() => onDone(), 2900);
    return () => [t1,t2,t3,t4].forEach(clearTimeout);
  }, []);

  return (
    <div style={{ position: 'absolute', inset: 0, background: '#0a0a0a', color: '#fff', display:'flex', flexDirection:'column' }}>
      {/* faux scanning visualization */}
      <div style={{ flex: 1, position: 'relative', display:'flex', alignItems:'center', justifyContent:'center', overflow:'hidden' }}>
        <div style={{
          background: 'rgba(255,255,255,0.05)', padding: 14, borderRadius: 6,
          border: '1px solid rgba(255,255,255,0.1)',
        }}>
          <div style={{ display:'flex', gap: 3, marginBottom: 4 }}>
            {rack.slice(0,7).map((x, i) => (
              <DetectedTile key={i} x={x} delay={i*120} tile={tile} />
            ))}
          </div>
          <div style={{ display:'flex', gap: 3 }}>
            {rack.slice(7,14).map((x, i) => (
              <DetectedTile key={i} x={x} delay={(i+7)*120} tile={tile} />
            ))}
          </div>
        </div>
        {/* scan line */}
        <div style={{
          position:'absolute', left:0, right:0, height: 2,
          background: 'linear-gradient(90deg, transparent, var(--accent), transparent)',
          boxShadow: '0 0 18px var(--accent)',
          animation: 'scanLine 1.8s ease-in-out infinite',
        }} />
        <style>{`@keyframes scanLine { 0%, 100% { top: 15%; } 50% { top: 80%; } }`}</style>
      </div>

      {/* bottom */}
      <div style={{ padding: '0 24px 60px' }}>
        <div className="eyebrow" style={{ color: 'var(--accent)', marginBottom: 8 }}>
          <Icon name="sparkle" size={11} stroke={2} style={{ display:'inline', marginRight: 4, verticalAlign:'middle' }} />
          {tr ? 'YAPAY ZEKÂ ÇALIŞIYOR' : 'AI WORKING'}
        </div>
        <div className="serif" style={{ fontSize: 28, lineHeight: 1.1 }}>
          {steps[step]}
        </div>
        {/* progress */}
        <div style={{ marginTop: 20, height: 3, background: 'rgba(255,255,255,0.1)', borderRadius: 100, overflow: 'hidden' }}>
          <div style={{
            height: '100%', background: 'var(--accent)',
            width: `${((step+1)/steps.length)*100}%`,
            transition: 'width 0.5s ease',
          }} />
        </div>
        <div className="mono" style={{ fontSize: 11, color: 'rgba(255,255,255,0.5)', marginTop: 10, display:'flex', justifyContent:'space-between' }}>
          <span>{step+1}/{steps.length}</span>
          <span>{rack.length} {tr ? 'taş bulundu' : 'tiles found'}</span>
        </div>
      </div>
    </div>
  );
}

function DetectedTile({ x, delay, tile }) {
  const [shown, setShown] = React.useState(false);
  React.useEffect(() => { const t = setTimeout(() => setShown(true), delay); return () => clearTimeout(t); }, [delay]);
  return (
    <div style={{ position: 'relative' }}>
      <Tile n={x.n} color={x.color} size="sm" style={tile} faded={!shown} />
      {shown && (
        <div style={{
          position: 'absolute', inset: -3, border: '1.5px solid var(--accent)',
          borderRadius: 6, animation: 'fadeIn 0.3s ease both', pointerEvents: 'none',
        }} />
      )}
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// REVIEW / EDIT detected tiles
// ─────────────────────────────────────────────────────────────
function ReviewScreen({ rack, setRack, onConfirm, onBack, t, tile }) {
  const tr = t === 'tr';
  const [editing, setEditing] = React.useState(null); // index of tile being edited

  const updateTile = (idx, patch) => {
    setRack(r => r.map((x, i) => i === idx ? { ...x, ...patch } : x));
  };

  return (
    <div className="scroll" style={{ paddingBottom: 100 }}>
      <div style={{ padding: '60px 16px 0', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <button onClick={onBack} style={{
          width: 40, height: 40, background: 'var(--surface-2)', border: '1px solid var(--line)',
          borderRadius: 100, display: 'flex', alignItems: 'center', justifyContent: 'center',
          color: 'var(--ink)', cursor: 'pointer',
        }}>
          <Icon name="arrow-left" size={18} />
        </button>
        <span className="eyebrow" style={{ whiteSpace: 'nowrap' }}>{tr ? '2/3 · ONAYLA' : '2/3 · REVIEW'}</span>
        <div style={{ width: 40 }} />
      </div>

      <div style={{ padding: '16px 24px 8px' }}>
        <div className="serif" style={{ fontSize: 32, lineHeight: 1.05, letterSpacing: '-0.02em' }}>
          {tr ? 'Doğru tanındı mı?' : 'Did we get it right?'}
        </div>
        <div className="t-muted" style={{ fontSize: 14, marginTop: 6 }}>
          {tr ? 'Yanlış bir taş varsa üstüne dokun, değiştir.' : 'Tap any wrong tile to fix it.'}
        </div>
      </div>

      {/* tiles grid — 2 rows of 7 */}
      <div style={{ padding: '14px 20px 0' }}>
        <div className="rack" style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
          {[rack.slice(0,7), rack.slice(7,14)].map((row, ri) => (
            <div key={ri} style={{ display: 'flex', gap: 4, justifyContent: 'flex-start' }}>
              {row.map((tl, i) => {
                const idx = ri*7 + i;
                return (
                  <div key={idx} onClick={() => setEditing(idx)} style={{ position: 'relative' }}>
                    <Tile n={tl.n} color={tl.color} size="md" style={tile} selected={editing === idx} />
                    {tl.lowConfidence && (
                      <div style={{
                        position: 'absolute', top: -4, right: -4, width: 14, height: 14, borderRadius: '50%',
                        background: 'var(--warn)', border: '2px solid var(--bg)',
                      }} />
                    )}
                  </div>
                );
              })}
            </div>
          ))}
        </div>

        <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginTop: 12, fontSize: 12, color: 'var(--muted)' }}>
          <div style={{ width: 9, height: 9, borderRadius:'50%', background: 'var(--warn)' }} />
          <span>{tr ? 'Düşük güven · gözden geçir' : 'Low confidence · please review'}</span>
        </div>
      </div>

      {/* edit panel */}
      {editing !== null && (
        <div className="fade-in" style={{ padding: '24px 20px 0' }}>
          <div className="card" style={{ padding: 18 }}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 14 }}>
              <span className="eyebrow">{tr ? 'TAŞI DÜZENLE' : 'EDIT TILE'} · #{editing + 1}</span>
              <button onClick={() => setEditing(null)} style={{ background:'none', border:'none', color: 'var(--muted)', cursor:'pointer' }}>
                <Icon name="x" size={18} />
              </button>
            </div>

            <div className="eyebrow" style={{ marginBottom: 8 }}>{tr ? 'RENK' : 'COLOR'}</div>
            <div style={{ display: 'flex', gap: 8, marginBottom: 16 }}>
              {['red','black','yellow','blue','joker'].map(c => {
                const on = rack[editing].color === c;
                return (
                  <button key={c} onClick={() => updateTile(editing, { color: c, lowConfidence: false })} style={{
                    width: 44, height: 44, borderRadius: 100, cursor: 'pointer',
                    border: '2px solid ' + (on ? 'var(--ink)' : 'transparent'),
                    background: c === 'joker' ? 'var(--surface-2)' : `var(--tile-${c})`,
                    display: 'flex', alignItems: 'center', justifyContent: 'center',
                  }}>
                    {c === 'joker' && <JokerGlyph c="var(--ink)" size={20} />}
                  </button>
                );
              })}
            </div>

            {rack[editing].color !== 'joker' && (
              <>
                <div className="eyebrow" style={{ marginBottom: 8 }}>{tr ? 'SAYI' : 'NUMBER'}</div>
                <div style={{ display: 'grid', gridTemplateColumns: 'repeat(7, 1fr)', gap: 6 }}>
                  {Array.from({length:13}, (_,i) => i+1).map(n => {
                    const on = rack[editing].n === n;
                    return (
                      <button key={n} onClick={() => updateTile(editing, { n, lowConfidence: false })} style={{
                        height: 38, borderRadius: 8, cursor: 'pointer',
                        border: '1px solid ' + (on ? 'var(--ink)' : 'var(--line)'),
                        background: on ? 'var(--ink)' : 'var(--surface)',
                        color: on ? 'var(--bg)' : 'var(--ink)',
                        fontFamily: 'var(--mono)', fontSize: 14, fontWeight: 500,
                      }}>{n}</button>
                    );
                  })}
                </div>
              </>
            )}
          </div>
        </div>
      )}

      {/* footer CTA */}
      <div style={{
        position: 'absolute', left: 0, right: 0, bottom: 0,
        padding: '16px 20px 40px',
        background: 'color-mix(in oklab, var(--bg) 90%, transparent)',
        backdropFilter: 'blur(20px)', borderTop: '1px solid var(--line)',
      }}>
        <button className="btn btn-primary btn-block" onClick={onConfirm}>
          {tr ? 'Hesapla' : 'Calculate'} <Icon name="arrow-right" size={18} />
        </button>
      </div>
    </div>
  );
}

Object.assign(window, { HomeScreen, CameraScreen, AnalyzingScreen, ReviewScreen, BottomNav });
