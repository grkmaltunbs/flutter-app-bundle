// app.jsx — main app shell: routing, state, tweaks

// ──────────────────────────────────────────────────────────
// FIXTURE DATA
// ──────────────────────────────────────────────────────────

const RACK_OPENS = [
  { n: 7, color: 'red' }, { n: 7, color: 'black' }, { n: 7, color: 'yellow' }, { n: 7, color: 'blue' },
  { n: 9, color: 'blue' }, { n: 10, color: 'blue' }, { n: 11, color: 'blue' },
  { n: 12, color: 'blue' }, { n: 13, color: 'blue' },
  { n: 3, color: 'red', lowConfidence: true }, { n: 5, color: 'yellow' },
  { n: 2, color: 'black' }, { n: 11, color: 'red' }, { n: '', color: 'joker' },
];

const RESULT_OPENS = {
  total: 104,
  melds: [
    { label: { tr: 'Aynı sayı · 4 renk', en: 'Set · 4 colors' }, score: 28,
      tiles: [{n:7,color:'red'},{n:7,color:'black'},{n:7,color:'yellow'},{n:7,color:'blue'}] },
    { label: { tr: 'Mavi seri · 5', en: 'Blue run · 5' }, score: 55,
      tiles: [{n:9,color:'blue'},{n:10,color:'blue'},{n:11,color:'blue'},{n:12,color:'blue'},{n:13,color:'blue'}] },
    { label: { tr: 'On birli · okey ile', en: 'Elevens · with joker' }, score: 21,
      tiles: [{n:11,color:'red'},{n:'',color:'joker'},{n:11,color:'yellow'}] },
  ],
  leftover: [{n:3,color:'red'},{n:5,color:'yellow'},{n:2,color:'black'}],
  reasoning: {
    tr: [
      'Dört renkten yedi\u2019liler tek seçenek; 28 puan kesin.',
      'Mavi 9\u201313 beş taşlık seri, 55 puan kazandırır.',
      'Okey on bir\u2019liler grubuna katılınca 21 puan daha gelir; toplam 104.',
    ],
    en: [
      'Sevens-in-four-colors is the only set; locks in 28 points.',
      'Blue 9\u201313 is your best run \u2014 worth 55 points.',
      'Okey completes the 11\u2019s for 21 more, totalling 104.',
    ],
  },
};

const RACK_CLOSE = [
  { n: 7, color: 'red' }, { n: 7, color: 'black' }, { n: 7, color: 'yellow' },
  { n: 3, color: 'blue' }, { n: 4, color: 'blue' }, { n: 5, color: 'blue' },
  { n: 9, color: 'red' }, { n: 11, color: 'yellow' }, { n: 13, color: 'black' },
  { n: 1, color: 'red' }, { n: 2, color: 'red' }, { n: 6, color: 'yellow' },
  { n: 8, color: 'black' }, { n: 12, color: 'blue' },
];

const HISTORY = [
  { when: '21:48', mode: '101 Okey', opens: true, score: 104, rack: RACK_OPENS },
  { when: 'Dün · 19:30', mode: '101 Okey', opens: false, score: 87, rack: RACK_CLOSE },
  { when: 'Dün · 18:12', mode: 'Okey', opens: true, score: 142, rack: RACK_OPENS },
  { when: '21 May', mode: '101 Okey', opens: false, score: 76, rack: RACK_CLOSE },
  { when: '20 May', mode: '101 Okey', opens: true, score: 118, rack: RACK_OPENS },
];

// ──────────────────────────────────────────────────────────
// APP — receives tweaks + setter as props (single source of truth)
// ──────────────────────────────────────────────────────────
function App({ tweaks, setTweak }) {
  const [route, setRoute] = React.useState('splash');
  const [isGuest, setIsGuest] = React.useState(false);
  const [rack, setRack] = React.useState(RACK_OPENS);
  const [result, setResult] = React.useState(RESULT_OPENS);

  const appRef = React.useRef(null);
  React.useEffect(() => {
    const el = appRef.current;
    if (!el) return;
    el.setAttribute('data-theme', tweaks.theme);
    el.style.setProperty('--accent', tweaks.accent);
  }, [tweaks.theme, tweaks.accent]);

  const go = (r) => setRoute(r);

  let content;
  if (route === 'splash') {
    content = <SplashScreen
      t={tweaks.language} tile={tweaks.tileStyle}
      onContinue={() => go('login')}
      onGuest={() => { setIsGuest(true); go('home'); }}
    />;
  } else if (route === 'login') {
    content = <LoginScreen
      t={tweaks.language}
      onLogin={() => { setIsGuest(false); go('home'); }}
      onGuest={() => { setIsGuest(true); go('home'); }}
      onBack={() => go('splash')}
    />;
  } else if (route === 'home') {
    content = <>
      <HomeScreen
        t={tweaks.language} tile={tweaks.tileStyle} layout={tweaks.homeLayout}
        gameMode={tweaks.gameMode} setGameMode={(v) => setTweak('gameMode', v)}
        recentRack={RACK_OPENS}
        onScan={() => go('camera')}
        onHistory={() => go('history')}
        onTutorial={() => go('tutorial')}
      />
      <BottomNav t={tweaks.language} active="home" onNav={(k) => go(k)} />
    </>;
  } else if (route === 'history') {
    content = <>
      <HistoryScreen t={tweaks.language} tile={tweaks.tileStyle} items={HISTORY}
                     onOpen={() => { setResult(RESULT_OPENS); go('result'); }} />
      <BottomNav t={tweaks.language} active="history" onNav={(k) => go(k)} />
    </>;
  } else if (route === 'settings') {
    content = <>
      <SettingsScreen
        t={tweaks.language} isGuest={isGuest}
        setLang={(v) => setTweak('language', v)}
        onLogout={() => { setIsGuest(false); go('splash'); }}
      />
      <BottomNav t={tweaks.language} active="settings" onNav={(k) => go(k)} />
    </>;
  } else if (route === 'tutorial') {
    content = <TutorialScreen t={tweaks.language} tile={tweaks.tileStyle} onBack={() => go('home')} />;
  } else if (route === 'camera') {
    content = <CameraScreen
      t={tweaks.language} tile={tweaks.tileStyle}
      captureMode={tweaks.captureMode}
      setCaptureMode={(v) => setTweak('captureMode', v)}
      onCapture={() => { setRack(RACK_OPENS); go('analyzing'); }}
      onBack={() => go('home')}
    />;
  } else if (route === 'analyzing') {
    content = <AnalyzingScreen
      t={tweaks.language} tile={tweaks.tileStyle} rack={rack}
      onDone={() => go('review')}
    />;
  } else if (route === 'review') {
    content = <ReviewScreen
      t={tweaks.language} tile={tweaks.tileStyle}
      rack={rack} setRack={setRack}
      onConfirm={() => { setResult(RESULT_OPENS); go('result'); }}
      onBack={() => go('camera')}
    />;
  } else if (route === 'result') {
    content = <ResultScreen
      t={tweaks.language} tile={tweaks.tileStyle}
      resultLayout={tweaks.resultLayout}
      result={result}
      onAgain={() => go('camera')}
      onHome={() => go('home')}
    />;
  }

  return <div ref={appRef} className="app">{content}</div>;
}

// ──────────────────────────────────────────────────────────
// ROOT — owns tweaks state, wraps App in device frame, mounts panel
// ──────────────────────────────────────────────────────────
function Root() {
  const defaults = /*EDITMODE-BEGIN*/{
    "theme": "light",
    "tileStyle": "classic",
    "accent": "oklch(0.55 0.13 165)",
    "gameMode": "101",
    "resultLayout": "rack",
    "homeLayout": "cards",
    "captureMode": "photo",
    "language": "tr"
  }/*EDITMODE-END*/;
  const [tweaks, setTweak] = useTweaks(defaults);

  return (
    <div style={{
      minHeight: '100vh', display: 'flex', alignItems: 'center', justifyContent: 'center',
      padding: 24, background: '#ECECEC',
    }}>
      <IOSDevice width={402} height={874} dark={tweaks.theme === 'dark' || tweaks.theme === 'felt'}>
        <App tweaks={tweaks} setTweak={setTweak} />
      </IOSDevice>

      <TweaksPanel title="Tweaks">
        <TweakSection label="Görünüm · Theme">
          <TweakRadio
            label="Mode"
            value={tweaks.theme}
            onChange={(v) => setTweak('theme', v)}
            options={[
              { value: 'light', label: 'Light' },
              { value: 'dark', label: 'Dark' },
              { value: 'felt', label: 'Felt' },
            ]}
          />
        </TweakSection>

        <TweakSection label="Accent color">
          <TweakColor
            label="Accent"
            value={tweaks.accent}
            onChange={(v) => setTweak('accent', v)}
            options={[
              'oklch(0.55 0.13 165)',
              'oklch(0.62 0.17 25)',
              'oklch(0.48 0.16 270)',
              'oklch(0.66 0.15 70)',
            ]}
          />
        </TweakSection>

        <TweakSection label="Tile style">
          <TweakSelect
            label="Style"
            value={tweaks.tileStyle}
            onChange={(v) => setTweak('tileStyle', v)}
            options={[
              { value: 'classic', label: 'Classic (cream + serif)' },
              { value: 'flat',    label: 'Flat (color block)' },
              { value: 'minimal', label: 'Minimal (dot + mono)' },
              { value: 'bold',    label: 'Bold (italic serif)' },
            ]}
          />
        </TweakSection>

        <TweakSection label="Game mode">
          <TweakRadio
            label="Mode"
            value={tweaks.gameMode}
            onChange={(v) => setTweak('gameMode', v)}
            options={[
              { value: '101', label: '101 Okey' },
              { value: 'okey', label: 'Plain Okey' },
            ]}
          />
        </TweakSection>

        <TweakSection label="Result layout">
          <TweakSelect
            label="Layout"
            value={tweaks.resultLayout}
            onChange={(v) => setTweak('resultLayout', v)}
            options={[
              { value: 'rack',     label: 'Visual rack' },
              { value: 'list',     label: 'List of melds' },
              { value: 'detailed', label: 'Rack + reasoning' },
            ]}
          />
        </TweakSection>

        <TweakSection label="Capture mode">
          <TweakRadio
            label="Mode"
            value={tweaks.captureMode}
            onChange={(v) => setTweak('captureMode', v)}
            options={[
              { value: 'photo', label: 'Photo' },
              { value: 'video', label: 'Video' },
              { value: 'gallery', label: 'Gallery' },
            ]}
          />
        </TweakSection>

        <TweakSection label="Language">
          <TweakRadio
            label="Lang"
            value={tweaks.language}
            onChange={(v) => setTweak('language', v)}
            options={[
              { value: 'tr', label: 'Türkçe' },
              { value: 'en', label: 'English' },
            ]}
          />
        </TweakSection>
      </TweaksPanel>
    </div>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(<Root />);
