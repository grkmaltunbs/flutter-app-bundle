// result_screens.jsx — result, history, settings

// ─────────────────────────────────────────────────────────────
// RESULT — visual rack with optimal arrangement + verdict
// ─────────────────────────────────────────────────────────────
function ResultScreen({ result, onAgain, onHome, t, tile, resultLayout = 'rack' }) {
  const tr = t === 'tr';
  const opens = result.total >= 101;

  return (
    <div className="scroll" style={{ paddingBottom: 110 }}>
      {/* top bar */}
      <div style={{ padding: '60px 16px 0', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <button onClick={onHome} style={{
          width: 40, height: 40, background: 'var(--surface-2)', border: '1px solid var(--line)',
          borderRadius: 100, display: 'flex', alignItems: 'center', justifyContent: 'center',
          color: 'var(--ink)', cursor: 'pointer',
        }}>
          <Icon name="x" size={18} />
        </button>
        <span className="eyebrow" style={{ whiteSpace: 'nowrap' }}>{tr ? '3/3 · SONUÇ' : '3/3 · RESULT'}</span>
        <div style={{ width: 40 }} />
      </div>

      {/* VERDICT — the bold moment */}
      <div className="scale-in" style={{ padding: '24px 24px 16px', textAlign: 'left' }}>
        <div className="eyebrow" style={{ color: opens ? 'var(--good)' : 'var(--warn)', marginBottom: 6 }}>
          {opens ? (tr ? 'AÇABİLİRSİN' : 'YOU CAN OPEN') : (tr ? 'HENÜZ AÇMIYOR' : 'NOT YET')}
        </div>
        <div className="serif" style={{
          fontSize: 88, lineHeight: 0.9, letterSpacing: '-0.04em',
          fontStyle: 'italic',
          color: opens ? 'var(--ink)' : 'var(--muted)',
        }}>
          {opens ? (tr ? 'Açar.' : 'Opens.') : (tr ? 'Açmaz.' : 'No open.')}
        </div>
        <div style={{ marginTop: 14, display: 'flex', alignItems: 'baseline', gap: 14 }}>
          <span className="mono" style={{ fontSize: 14, color: 'var(--muted)', letterSpacing: '0.02em' }}>
            {tr ? 'PUAN' : 'SCORE'}
          </span>
          <span className="mono" style={{ fontSize: 32, fontWeight: 500, color: opens ? 'var(--good)' : 'var(--bad)', letterSpacing: '-0.02em' }}>
            {result.total}
          </span>
          <span className="mono" style={{ fontSize: 14, color: 'var(--faint)' }}>/ 101</span>
        </div>
        {!opens && (
          <div className="t-muted" style={{ fontSize: 14, marginTop: 8 }}>
            {tr ? `${101 - result.total} puan eksik. En iyi olası diziliş:` : `${101 - result.total} short. Best possible play:`}
          </div>
        )}
      </div>

      {/* RACK or LIST */}
      {resultLayout === 'rack' && <RackLayout result={result} tile={tile} tr={tr} />}
      {resultLayout === 'list' && <ListLayout result={result} tile={tile} tr={tr} />}
      {resultLayout === 'detailed' && <DetailedLayout result={result} tile={tile} tr={tr} />}

      {/* CTA */}
      <div style={{
        position: 'absolute', left: 0, right: 0, bottom: 0,
        padding: '14px 20px 40px',
        background: 'color-mix(in oklab, var(--bg) 92%, transparent)',
        backdropFilter: 'blur(20px)', borderTop: '1px solid var(--line)',
        display: 'flex', gap: 10,
      }}>
        <button className="btn btn-secondary" style={{ flex: 1 }} onClick={onAgain}>
          <Icon name="rotate" size={16} /> {tr ? 'Tekrar' : 'Again'}
        </button>
        <button className="btn btn-primary" style={{ flex: 1.4 }} onClick={onHome}>
          {tr ? 'Bitir' : 'Done'} <Icon name="check" size={18} />
        </button>
      </div>
    </div>
  );
}

// ─── Rack layout — visual rack with bracket indicators ───
function RackLayout({ result, tile, tr }) {
  // build a 14-tile array with group highlights
  const all = [];
  const colors = ['var(--accent)', 'var(--tile-blue)', 'var(--tile-red)', 'var(--warn)'];
  result.melds.forEach((m, mi) => {
    m.tiles.forEach(t => all.push({ ...t, hl: colors[mi % colors.length], mi }));
  });
  result.leftover.forEach(t => all.push({ ...t, hl: null, mi: -1 }));

  return (
    <div style={{ padding: '8px 20px 0' }}>
      <div className="eyebrow" style={{ marginBottom: 10 }}>{tr ? 'EN İYİ DİZİLİŞ' : 'BEST ARRANGEMENT'}</div>
      <div className="rack" style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
        {[all.slice(0,7), all.slice(7,14)].map((row, ri) => (
          <div key={ri} style={{ display: 'flex', gap: 3, position: 'relative' }}>
            {row.map((t, i) => (
              <div key={i} style={{ position: 'relative' }}>
                <Tile n={t.n} color={t.color} size="md" style={tile} faded={t.mi === -1} />
                {t.hl && (
                  <div style={{
                    position: 'absolute', inset: -3, borderRadius: 7,
                    border: `1.5px solid ${t.hl}`, pointerEvents: 'none',
                  }} />
                )}
              </div>
            ))}
          </div>
        ))}
      </div>

      {/* legend */}
      <div style={{ marginTop: 16, display: 'flex', flexDirection: 'column', gap: 10 }}>
        {result.melds.map((m, mi) => (
          <div key={mi} style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            <div style={{
              width: 14, height: 14, borderRadius: 4,
              border: `1.5px solid ${colors[mi % colors.length]}`,
            }} />
            <div style={{ flex: 1 }}>
              <span style={{ fontSize: 14, fontWeight: 500 }}>{m.label[tr ? 'tr' : 'en']}</span>
              <span className="t-muted" style={{ fontSize: 13, marginLeft: 6 }}>
                · {m.tiles.length} {tr ? 'taş' : 'tiles'}
              </span>
            </div>
            <span className="mono" style={{ fontSize: 14, fontWeight: 500, color: 'var(--accent)' }}>+{m.score}</span>
          </div>
        ))}
        {result.leftover.length > 0 && (
          <div style={{ display: 'flex', alignItems: 'center', gap: 10, paddingTop: 8, borderTop: '1px solid var(--line)' }}>
            <div style={{ width: 14, height: 14, borderRadius: 4, border: '1.5px dashed var(--faint)' }} />
            <div style={{ flex: 1, fontSize: 14, color: 'var(--muted)' }}>
              {tr ? 'Kalan taşlar' : 'Leftover'} · {result.leftover.length}
            </div>
            <span className="mono" style={{ fontSize: 14, color: 'var(--muted)' }}>—</span>
          </div>
        )}
      </div>
    </div>
  );
}

// ─── List layout — each meld as a separate row ───
function ListLayout({ result, tile, tr }) {
  return (
    <div style={{ padding: '8px 20px 0', display: 'flex', flexDirection: 'column', gap: 10 }}>
      <div className="eyebrow">{tr ? 'GRUPLAR' : 'GROUPS'}</div>
      {result.melds.map((m, mi) => (
        <div key={mi} className="card" style={{ padding: 14 }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 10 }}>
            <span className="eyebrow">{m.label[tr ? 'tr' : 'en']}</span>
            <span className="pill pill-accent">+{m.score}</span>
          </div>
          <div style={{ display: 'flex', gap: 3 }}>
            {m.tiles.map((t, i) => (
              <Tile key={i} n={t.n} color={t.color} size="sm" style={tile} />
            ))}
          </div>
        </div>
      ))}
      {result.leftover.length > 0 && (
        <div className="card" style={{ padding: 14, borderStyle: 'dashed' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 10 }}>
            <span className="eyebrow t-muted">{tr ? 'KALAN' : 'LEFTOVER'}</span>
            <span className="mono" style={{ fontSize: 11, color: 'var(--muted)' }}>—</span>
          </div>
          <div style={{ display: 'flex', gap: 3 }}>
            {result.leftover.map((t, i) => (
              <Tile key={i} n={t.n} color={t.color} size="sm" style={tile} faded />
            ))}
          </div>
        </div>
      )}
    </div>
  );
}

// ─── Detailed — rack + step-by-step explanation ───
function DetailedLayout({ result, tile, tr }) {
  return (
    <>
      <RackLayout result={result} tile={tile} tr={tr} />
      <div style={{ padding: '20px 20px 0' }}>
        <div className="eyebrow" style={{ marginBottom: 10 }}>{tr ? 'NEDEN BÖYLE?' : 'WHY THIS?'}</div>
        <div className="card" style={{ padding: 16 }}>
          {result.reasoning[tr ? 'tr' : 'en'].map((r, i) => (
            <div key={i} style={{ display:'flex', gap: 12, padding: '8px 0', borderBottom: i < 2 ? '1px solid var(--line)' : 'none' }}>
              <span className="mono" style={{ fontSize: 11, color: 'var(--accent)', minWidth: 18 }}>{String(i+1).padStart(2,'0')}</span>
              <span style={{ fontSize: 13, lineHeight: 1.5, flex: 1 }}>{r}</span>
            </div>
          ))}
        </div>
      </div>
    </>
  );
}

// ─────────────────────────────────────────────────────────────
// HISTORY
// ─────────────────────────────────────────────────────────────
function HistoryScreen({ items, onOpen, t, tile }) {
  const tr = t === 'tr';
  return (
    <div className="scroll" style={{ paddingBottom: 110 }}>
      <div style={{ padding: '60px 24px 0' }}>
        <div className="eyebrow">{tr ? 'GEÇMİŞ' : 'HISTORY'}</div>
        <div className="serif" style={{ fontSize: 36, lineHeight: 1.05, letterSpacing: '-0.02em', marginTop: 6 }}>
          {tr ? 'Önceki ellerin.' : 'Your past hands.'}
        </div>
      </div>

      {/* filter chips */}
      <div style={{ padding: '16px 20px 0', display: 'flex', gap: 8 }}>
        {[
          { k: 'all', label: tr ? 'Tümü' : 'All', n: items.length },
          { k: 'open', label: tr ? 'Açanlar' : 'Opened', n: items.filter(i=>i.opens).length },
          { k: 'no', label: tr ? 'Açmayanlar' : 'Closed', n: items.filter(i=>!i.opens).length },
        ].map((f, i) => (
          <button key={f.k} style={{
            padding: '8px 12px', borderRadius: 100,
            background: i === 0 ? 'var(--ink)' : 'var(--surface)',
            color: i === 0 ? 'var(--bg)' : 'var(--ink)',
            border: '1px solid ' + (i === 0 ? 'var(--ink)' : 'var(--line)'),
            fontSize: 12, fontFamily: 'var(--sans)', cursor: 'pointer',
            display: 'flex', alignItems: 'center', gap: 6,
          }}>
            {f.label} <span className="mono" style={{ fontSize: 10, opacity: 0.7 }}>{f.n}</span>
          </button>
        ))}
      </div>

      <div style={{ padding: '14px 20px 0', display: 'flex', flexDirection: 'column', gap: 10 }}>
        {items.map((it, i) => (
          <button key={i} onClick={() => onOpen(it)} style={{
            textAlign: 'left', padding: 14, borderRadius: 'var(--r-lg)',
            background: 'var(--surface)', border: '1px solid var(--line)',
            cursor: 'pointer', fontFamily: 'var(--sans)',
          }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 10 }}>
              <div>
                <span className="mono" style={{ fontSize: 11, color: 'var(--muted)' }}>{it.when}</span>
                <span className="mono" style={{ fontSize: 11, color: 'var(--faint)', marginLeft: 8 }}>· {it.mode}</span>
              </div>
              <span className={`pill ${it.opens ? 'pill-good' : 'pill-bad'}`}>
                {it.opens ? <Icon name="check" size={11} stroke={2.4} /> : <Icon name="x" size={11} stroke={2.4} />}
                {it.opens ? (tr ? 'Açtı' : 'Open') : (tr ? 'Açmadı' : 'No')} · {it.score}
              </span>
            </div>
            <Rack tiles={it.rack} tileStyle={tile} size="xs" />
          </button>
        ))}
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// SETTINGS
// ─────────────────────────────────────────────────────────────
function SettingsScreen({ t, setLang, onLogout, isGuest }) {
  const tr = t === 'tr';

  const Section = ({ children, label }) => (
    <div style={{ marginTop: 18 }}>
      <div className="eyebrow" style={{ padding: '0 24px 8px' }}>{label}</div>
      <div style={{
        background: 'var(--surface)', border: '1px solid var(--line)',
        borderRadius: 'var(--r-lg)', overflow: 'hidden', margin: '0 16px',
      }}>{children}</div>
    </div>
  );
  const Row = ({ label, value, onClick, last }) => (
    <div onClick={onClick} style={{
      padding: '14px 18px', display: 'flex', justifyContent: 'space-between', alignItems: 'center',
      borderBottom: last ? 'none' : '1px solid var(--line)', cursor: onClick ? 'pointer' : 'default',
    }}>
      <span style={{ fontSize: 15 }}>{label}</span>
      <span style={{ display: 'flex', alignItems: 'center', gap: 8, color: 'var(--muted)', fontSize: 13 }}>
        {value} {onClick && <Icon name="chevron-right" size={16} />}
      </span>
    </div>
  );

  return (
    <div className="scroll" style={{ paddingBottom: 110 }}>
      <div style={{ padding: '60px 24px 0' }}>
        <div className="eyebrow">{tr ? 'PROFİL' : 'PROFILE'}</div>
        <div className="serif" style={{ fontSize: 36, lineHeight: 1.05, letterSpacing: '-0.02em', marginTop: 6 }}>
          {isGuest ? (tr ? 'Misafir oyuncu.' : 'Guest player.') : (tr ? 'Selam, Mehmet.' : 'Hi, Mehmet.')}
        </div>
      </div>

      {/* profile card */}
      <div style={{ padding: '18px 16px 0' }}>
        <div className="card" style={{ padding: 16, display: 'flex', alignItems: 'center', gap: 14 }}>
          <div style={{
            width: 52, height: 52, borderRadius: 100,
            background: isGuest ? 'var(--surface-2)' : 'var(--accent-soft)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            color: isGuest ? 'var(--muted)' : 'var(--accent-ink)',
          }}>
            <Icon name="user" size={24} stroke={1.5} />
          </div>
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 15, fontWeight: 500 }}>
              {isGuest ? (tr ? 'Misafir hesap' : 'Guest account') : 'mehmet@example.com'}
            </div>
            <div className="t-muted" style={{ fontSize: 12, marginTop: 2 }}>
              {isGuest
                ? (tr ? 'Geçmişin cihazda kalır' : 'History stays on device')
                : (tr ? 'Üye · 4 ay' : 'Member · 4mo')}
            </div>
          </div>
          {isGuest && (
            <button className="btn btn-sm btn-secondary">
              {tr ? 'Üye ol' : 'Sign up'}
            </button>
          )}
        </div>
      </div>

      <Section label={tr ? 'GENEL' : 'GENERAL'}>
        <Row label={tr ? 'Dil' : 'Language'} value={tr ? 'Türkçe' : 'English'} onClick={() => setLang(tr ? 'en' : 'tr')} />
        <Row label={tr ? 'Bildirimler' : 'Notifications'} value={tr ? 'Açık' : 'On'} onClick={() => {}} />
        <Row label={tr ? 'Hesap güvenliği' : 'Security'} value="" onClick={() => {}} last />
      </Section>

      <Section label={tr ? 'GÖRÜNÜM' : 'APPEARANCE'}>
        <Row label={tr ? 'Görünüm' : 'Theme'} value={tr ? 'Tweaks panelinden' : 'Via Tweaks panel'} />
        <Row label={tr ? 'Taş tipi' : 'Tile style'} value={tr ? 'Tweaks panelinden' : 'Via Tweaks panel'} last />
      </Section>

      <Section label={tr ? 'OYUN' : 'GAME'}>
        <Row label={tr ? 'Varsayılan mod' : 'Default mode'} value="101 Okey" onClick={() => {}} />
        <Row label={tr ? 'Sıralama kuralları' : 'Sort rules'} value={tr ? 'Klasik' : 'Classic'} onClick={() => {}} last />
      </Section>

      <Section label={tr ? 'HAKKINDA' : 'ABOUT'}>
        <Row label={tr ? 'Kullanım koşulları' : 'Terms'} onClick={() => {}} />
        <Row label={tr ? 'Gizlilik' : 'Privacy'} onClick={() => {}} />
        <Row label={tr ? 'Sürüm' : 'Version'} value="1.0.0" last />
      </Section>

      <div style={{ padding: '20px 16px 0' }}>
        <button onClick={onLogout} style={{
          width: '100%', padding: 14, borderRadius: 'var(--r-lg)',
          background: 'transparent', border: '1px solid var(--line)',
          color: 'var(--bad)', fontSize: 14, fontFamily: 'var(--sans)', cursor: 'pointer',
          display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8,
        }}>
          <Icon name="logout" size={16} /> {tr ? 'Çıkış yap' : 'Sign out'}
        </button>
      </div>
    </div>
  );
}

Object.assign(window, { ResultScreen, HistoryScreen, SettingsScreen });
