// auth_screens.jsx — splash, login, tutorial

// ─────────────────────────────────────────────────────────────
// SPLASH — brand entry
// ─────────────────────────────────────────────────────────────
function SplashScreen({ onContinue, onGuest, t, tile }) {
  return (
    <div className="scroll" style={{ display: 'flex', flexDirection: 'column', height: '100%', padding: '76px 28px 36px' }}>
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', justifyContent: 'center', gap: 18 }}>
        <div className="eyebrow" style={{ marginBottom: 4 }}>
          {t === 'tr' ? '101 OKEY · TARAYICI' : '101 OKEY · SCANNER'}
        </div>

        {/* Logo / wordmark — a small rack of letters as tiles */}
        <div className="scale-in" style={{ display: 'flex', gap: 3, marginBottom: 22 }}>
          <LetterTile ch="1" color="red" />
          <LetterTile ch="0" color="black" />
          <LetterTile ch="1" color="blue" />
        </div>

        <div>
          <div className="serif" style={{
            fontSize: 64, lineHeight: 0.95, color: 'var(--ink)',
            letterSpacing: '-0.025em', fontStyle: 'italic',
          }}>
            Açar mı?
          </div>
          <div className="serif" style={{
            fontSize: 44, lineHeight: 1, color: 'var(--muted)',
            letterSpacing: '-0.02em', marginTop: 6,
          }}>
            {t === 'tr' ? 'Bir bakışta öğren.' : 'Find out at a glance.'}
          </div>
        </div>

        <div className="t-muted" style={{ fontSize: 15, lineHeight: 1.5, marginTop: 14, maxWidth: 320 }}>
          {t === 'tr'
            ? 'Istakanı çek, taşları taratıver. En iyi sıralamayı saniyeler içinde gör.'
            : 'Snap your rack. We detect every tile and lay out your best play in seconds.'}
        </div>
      </div>

      <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
        <button className="btn btn-primary btn-block" onClick={onContinue}>
          {t === 'tr' ? 'Devam et' : 'Get started'}
          <Icon name="arrow-right" size={18} />
        </button>
        <button className="btn btn-ghost btn-block" onClick={onGuest} style={{ color: 'var(--muted)' }}>
          {t === 'tr' ? 'Misafir olarak gir' : 'Continue as guest'}
        </button>
      </div>
    </div>
  );
}

function LetterTile({ ch, color }) {
  const c = {
    red: 'var(--tile-red)', black: 'var(--tile-black)',
    yellow: 'var(--tile-yellow)', blue: 'var(--tile-blue)',
  }[color];
  return (
    <div style={{
      width: 44, height: 60, borderRadius: 6,
      background: 'linear-gradient(180deg, var(--tile-face), var(--tile-face-edge))',
      boxShadow: '0 2px 4px rgba(0,0,0,0.1), inset 0 1px 0 rgba(255,255,255,0.7), inset 0 -1px 0 rgba(0,0,0,0.05)',
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      position: 'relative',
    }}>
      <span style={{ fontFamily: 'var(--serif)', fontSize: 32, color: c, lineHeight: 1, transform: 'translateY(1px)' }}>{ch}</span>
      <div style={{ position: 'absolute', left: 4, right: 4, top: '52%', height: 1, background: 'rgba(0,0,0,0.05)' }} />
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// LOGIN
// ─────────────────────────────────────────────────────────────
function LoginScreen({ onLogin, onGuest, onBack, t }) {
  const [mode, setMode] = React.useState('signin'); // signin | signup
  const [showPw, setShowPw] = React.useState(false);
  const tr = t === 'tr';

  return (
    <div className="scroll" style={{ display: 'flex', flexDirection: 'column', height: '100%' }}>
      <div style={{ padding: '60px 16px 0' }}>
        <button onClick={onBack} style={{
          width: 40, height: 40, background: 'var(--surface-2)', border: '1px solid var(--line)',
          borderRadius: 100, display: 'flex', alignItems: 'center', justifyContent: 'center',
          color: 'var(--ink)', cursor: 'pointer',
        }}>
          <Icon name="arrow-left" size={18} />
        </button>
      </div>

      <div style={{ padding: '24px 28px 24px', flex: 1, display: 'flex', flexDirection: 'column' }}>
        <div>
          <div className="eyebrow">{tr ? 'HOŞ GELDİN' : 'WELCOME'}</div>
          <div className="serif" style={{ fontSize: 42, lineHeight: 1, marginTop: 10, letterSpacing: '-0.02em' }}>
            {mode === 'signin'
              ? (tr ? 'Tekrar hoş\u00a0geldin.' : 'Welcome back.')
              : (tr ? 'Hesap aç.' : 'Make an account.')}
          </div>
          <div className="t-muted" style={{ fontSize: 14, marginTop: 8 }}>
            {tr ? 'E-postanla devam et, ya da bağlan.' : 'Continue with email, or connect.'}
          </div>
        </div>

        <div style={{ marginTop: 26, display: 'flex', flexDirection: 'column', gap: 10 }}>
          <input className="input" placeholder={tr ? 'E-posta adresi' : 'Email address'} defaultValue="" />
          <div style={{ position: 'relative' }}>
            <input className="input" type={showPw ? 'text' : 'password'} placeholder={tr ? 'Şifre' : 'Password'} style={{ paddingRight: 50 }} />
            <button onClick={() => setShowPw(s => !s)} style={{
              position: 'absolute', right: 12, top: 0, bottom: 0, width: 36,
              background: 'transparent', border: 'none', color: 'var(--muted)', cursor: 'pointer',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
            }}>
              <Icon name={showPw ? 'eye-off' : 'eye'} size={18} />
            </button>
          </div>

          {mode === 'signin' && (
            <div style={{ textAlign: 'right' }}>
              <button style={{ background:'none', border:'none', cursor:'pointer', color: 'var(--muted)', fontSize: 13, fontFamily:'var(--sans)' }}>
                {tr ? 'Şifremi unuttum' : 'Forgot password'}
              </button>
            </div>
          )}

          <button className="btn btn-primary btn-block" onClick={onLogin} style={{ marginTop: 6 }}>
            {mode === 'signin' ? (tr ? 'Giriş yap' : 'Sign in') : (tr ? 'Hesap oluştur' : 'Create account')}
          </button>
        </div>

        <div style={{ margin: '24px 0 18px', display: 'flex', alignItems: 'center', gap: 12 }}>
          <div className="divider" style={{ flex: 1 }} />
          <div className="eyebrow" style={{ fontSize: 10 }}>{tr ? 'YA DA' : 'OR'}</div>
          <div className="divider" style={{ flex: 1 }} />
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          <button className="btn btn-secondary btn-block" onClick={onLogin}>
            <Icon name="google" size={18} stroke={0} />
            {tr ? 'Google ile devam et' : 'Continue with Google'}
          </button>
          <button className="btn btn-secondary btn-block" onClick={onLogin}>
            <Icon name="apple" size={18} stroke={0} />
            {tr ? 'Apple ile devam et' : 'Continue with Apple'}
          </button>
          <button className="btn btn-ghost btn-block" onClick={onGuest} style={{ color: 'var(--muted)' }}>
            {tr ? 'Misafir olarak devam et' : 'Continue as guest'} →
          </button>
        </div>

        <div style={{ flex: 1 }} />

        <div style={{ textAlign: 'center', marginTop: 24, fontSize: 13, color: 'var(--muted)' }}>
          {mode === 'signin' ? (tr ? 'Hesabın yok mu?' : 'No account yet?') : (tr ? 'Zaten bir hesabın var mı?' : 'Already have an account?')}
          {' '}
          <button onClick={() => setMode(mode === 'signin' ? 'signup' : 'signin')}
                  style={{ background:'none', border:'none', color: 'var(--ink)', cursor:'pointer', fontFamily:'var(--sans)', fontSize:13, fontWeight:500, padding:0, textDecoration:'underline' }}>
            {mode === 'signin' ? (tr ? 'Hesap oluştur' : 'Sign up') : (tr ? 'Giriş yap' : 'Sign in')}
          </button>
        </div>
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// TUTORIAL — how to use the app
// ─────────────────────────────────────────────────────────────
function TutorialScreen({ onBack, t, tile }) {
  const tr = t === 'tr';
  const steps = tr ? [
    { n: '01', title: 'Istakanı çek', body: 'Telefonu istakanın üstünde tut. Tüm taşların görünür olduğundan emin ol.' },
    { n: '02', title: 'Yapay zekâ tara­sın', body: 'Taşların rengi ve sayısı saniyeler içinde tanınır. Hatalıysa elle düzelt.' },
    { n: '03', title: 'En iyi diziliş', body: 'Algoritma seriler ve eserleri arar. Açacaksan kaç puanla açacağını söyler.' },
  ] : [
    { n: '01', title: 'Snap the rack', body: 'Hold your phone above the rack. Make sure every tile is visible from the camera.' },
    { n: '02', title: 'AI does the rest', body: 'Color and number are detected in seconds. Tap any tile to correct mistakes.' },
    { n: '03', title: 'Best arrangement', body: 'Our solver finds groups and runs, and tells you if you can open with 101.' },
  ];

  return (
    <div className="scroll" style={{ padding: '60px 0 40px' }}>
      <div style={{ padding: '0 16px', display:'flex', justifyContent:'space-between', alignItems:'center' }}>
        <button onClick={onBack} style={{
          width: 40, height: 40, background: 'var(--surface-2)', border: '1px solid var(--line)',
          borderRadius: 100, display: 'flex', alignItems: 'center', justifyContent: 'center',
          color: 'var(--ink)', cursor: 'pointer',
        }}>
          <Icon name="arrow-left" size={18} />
        </button>
        <span className="eyebrow">{tr ? 'NASIL ÇALIŞIR' : 'HOW IT WORKS'}</span>
        <div style={{ width: 40 }} />
      </div>

      <div style={{ padding: '20px 28px 8px' }}>
        <div className="serif" style={{ fontSize: 40, lineHeight: 1, letterSpacing: '-0.02em' }}>
          {tr ? 'Üç adım, doğru hamle.' : 'Three steps, the right move.'}
        </div>
      </div>

      <div style={{ padding: '24px 20px 0', display: 'flex', flexDirection: 'column', gap: 12 }}>
        {steps.map((s, i) => (
          <div key={i} className="card" style={{ padding: 20, display: 'flex', gap: 16 }}>
            <div className="mono" style={{
              fontSize: 13, color: 'var(--accent)', minWidth: 28, paddingTop: 2, letterSpacing: '0.02em',
            }}>{s.n}</div>
            <div style={{ flex: 1 }}>
              <div style={{ fontSize: 17, fontWeight: 500, marginBottom: 4 }}>{s.title}</div>
              <div className="t-muted" style={{ fontSize: 14, lineHeight: 1.5 }}>{s.body}</div>
            </div>
          </div>
        ))}
      </div>

      {/* example detection visualization */}
      <div style={{ padding: '28px 20px 0' }}>
        <div className="eyebrow" style={{ marginBottom: 12 }}>{tr ? 'ÖRNEK' : 'EXAMPLE'}</div>
        <div className="card" style={{ padding: 18 }}>
          <div className="t-muted" style={{ fontSize: 13, marginBottom: 10 }}>
            {tr ? 'Bu kombinasyon 101 ile açar:' : 'This rack opens with 101:'}
          </div>
          <Meld
            tiles={[{n:7,color:'red'},{n:7,color:'black'},{n:7,color:'yellow'},{n:7,color:'blue'}]}
            label={tr ? 'AYNI SAYI · 4 RENK' : 'SET · 4 COLORS'} score={28} tileStyle={tile} size="sm" />
          <div style={{ height: 12 }} />
          <Meld
            tiles={[{n:9,color:'blue'},{n:10,color:'blue'},{n:11,color:'blue'},{n:12,color:'blue'},{n:13,color:'blue'}]}
            label={tr ? 'SERİ · 5 TAŞ' : 'RUN · 5 TILES'} score={55} tileStyle={tile} size="sm" />
          <div style={{ height: 14 }} />
          <div style={{ display:'flex', justifyContent:'space-between', alignItems:'center', borderTop:'1px solid var(--line)', paddingTop:12 }}>
            <span className="eyebrow">{tr ? 'TOPLAM' : 'TOTAL'}</span>
            <span className="mono" style={{ fontSize: 18, color: 'var(--good)', fontWeight: 500 }}>83 + okey = 101 ✓</span>
          </div>
        </div>
      </div>

      <div style={{ padding: '24px 20px 0' }}>
        <button className="btn btn-primary btn-block" onClick={onBack}>
          {tr ? 'Anladım' : 'Got it'}
        </button>
      </div>
    </div>
  );
}

Object.assign(window, { SplashScreen, LoginScreen, TutorialScreen, LetterTile });
