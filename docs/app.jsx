// app.jsx — Hutch LP main app

const { useState, useEffect, useRef, useMemo } = React;

const TWEAK_DEFAULTS = /*EDITMODE-BEGIN*/{
  "accent": "#5B7CFA",
  "glassStrength": 0.62,
  "preset": "indigo"
}/*EDITMODE-END*/;

const ACCENT_PRESETS = {
  indigo:  '#5B7CFA',
  emerald: '#1FB57A',
  rose:    '#E0567C',
  amber:   '#E8A23A',
  graphite:'#454963',
};

// ─── Hero: menu bar + popover ───────────────────────────────────────────────

const MenuBar = ({ accent, time }) => (
  <div className="menubar">
    <div className="mb-left">
      <div className="mb-apple">
        <svg width="14" height="14" viewBox="0 0 16 16" fill="currentColor">
          <path d="M11.2 8.4c0-1.7 1.4-2.5 1.5-2.6-0.8-1.2-2.1-1.4-2.5-1.4-1.1-0.1-2.1 0.6-2.6 0.6-0.5 0-1.4-0.6-2.3-0.6C4.1 4.5 3 5.2 2.4 6.4c-1.2 2.1-0.3 5.2 0.9 6.9 0.6 0.8 1.3 1.8 2.2 1.7 0.9 0 1.2-0.6 2.3-0.6 1.1 0 1.4 0.6 2.3 0.5 1 0 1.6-0.8 2.2-1.7 0.7-1 0.9-1.9 1-2-0.0 0-1.9-0.7-1.9-2.8zM9.6 3.4c0.5-0.6 0.8-1.4 0.7-2.2-0.7 0-1.5 0.5-2 1.1-0.4 0.5-0.8 1.3-0.7 2.1 0.8 0.1 1.5-0.4 2-1z"/>
        </svg>
      </div>
      <span className="mb-app">Finder</span>
      <span className="mb-item">ファイル</span>
      <span className="mb-item">編集</span>
      <span className="mb-item">表示</span>
      <span className="mb-item">移動</span>
      <span className="mb-item">ウインドウ</span>
      <span className="mb-item">ヘルプ</span>
    </div>
    <div className="mb-right">
      <span className="mb-icon">􀙇</span>
      <span className="mb-icon">􀛨</span>
      <span className="mb-hutch" style={{ color: accent }}>
        <img src="hutch-icon.png" alt="Hutch" style={{ width: 16, height: 16, display: 'block' }} />
      </span>
      <span className="mb-time">{time}</span>
    </div>
  </div>
);

const Hero = ({ accent, glassStrength }) => {
  const [open, setOpen] = useState(false);
  const [completed, setCompleted] = useState([]);

  useEffect(() => {
    const timer = setTimeout(() => setOpen(true), 600);
    return () => clearTimeout(timer);
  }, []);

  return (
    <section className="hero" data-screen-label="01 Hero">
      <div className="hero-bg" />

      <div className="hero-inner">
        <div className="hero-copy">
          <div className="eyebrow">
            <span className="eyebrow-dot" style={{ background: accent }} />
            AI Reminder Assistant for macOS
          </div>
          <h1 className="hero-title">
            いつものリマインダーが、<br/>
            <span className="hero-emph" style={{ color: accent }}>ぐっと近く</span>なる。
          </h1>
          <p className="hero-lede">
            Apple純正リマインダーを、メニューバーから1クリックで。<br/>
            データはそのまま iCloud。入り口だけ、すぐそこに。
          </p>

          <div className="hero-cta">
            <a href="https://github.com/Riku4230/Hutch" className="btn-primary" style={{ background: accent }} target="_blank" rel="noopener">
              <svg width="13" height="13" viewBox="0 0 16 16" fill="currentColor"><path d="M8 1.3c-3.7 0-6.7 3-6.7 6.7 0 3 1.9 5.5 4.6 6.4.3.1.5-.1.5-.3v-1.2c-1.9.4-2.3-.9-2.3-.9-.3-.8-.7-1-.7-1-.6-.4 0-.4 0-.4.7 0 1 .7 1 .7.6 1 1.6.7 2 .6 0-.5.2-.7.4-.9-1.5-.2-3.1-.7-3.1-3.3 0-.7.3-1.3.7-1.8-.1-.2-.3-.9.1-1.9 0 0 .6-.2 2 .7.6-.2 1.2-.3 1.8-.3.6 0 1.2.1 1.8.3 1.4-.9 2-.7 2-.7.4 1 .1 1.7.1 1.9.4.5.7 1.1.7 1.8 0 2.6-1.6 3.1-3.1 3.3.2.2.4.6.4 1.2v1.7c0 .2.1.4.5.3 2.7-.9 4.6-3.4 4.6-6.4 0-3.7-3-6.7-6.7-6.7Z"/></svg>
              GitHubを見る
            </a>
          </div>
          <div className="hero-meta">
            <span>macOS 14+</span>
            <span className="dot">·</span>
            <span>無料</span>
            <span className="dot">·</span>
            <span>Open Source (MIT)</span>
          </div>
        </div>

        <div className="hero-stage">
          <MenuBar accent={accent} time="22:37" />
          <div className={`hero-anchor ${open ? 'is-open' : ''}`}>
            <div className="hero-tether" />
          </div>

          <div className={`hero-popwrap ${open ? 'is-open' : ''}`}>
            <HutchPopover
              accent={accent}
              glassStrength={glassStrength}
              completedIds={completed}
              onToggleComplete={(id) => {
                setCompleted(c => c.includes(id) ? c.filter(x => x !== id) : [...c, id]);
              }}
              hoverable
            />
          </div>
        </div>
      </div>
    </section>
  );
};

// ─── Features grid ──────────────────────────────────────────────────────────

const features = [
  {
    icon: (
      <svg viewBox="0 0 32 32" fill="none">
        <rect x="4" y="6" width="24" height="20" rx="3" stroke="currentColor" strokeWidth="1.5"/>
        <path d="M4 11h24" stroke="currentColor" strokeWidth="1.5"/>
        <circle cx="9" cy="18" r="1.5" fill="currentColor"/>
        <path d="M14 18h10" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"/>
        <path d="M14 22h7" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"/>
      </svg>
    ),
    title: '乗り換えは、いらない。',
    body: '純正リマインダーのデータをそのまま使えるから、リスト・iCloud同期・iPhone連携はいつもどおり。Hutchを消しても、データは残ります。'
  },
  {
    icon: (
      <svg viewBox="0 0 32 32" fill="none">
        <path d="M8 12 16 4l8 8" stroke="currentColor" strokeWidth="1.5" strokeLinejoin="round"/>
        <rect x="6" y="12" width="20" height="14" rx="2" stroke="currentColor" strokeWidth="1.5"/>
        <circle cx="16" cy="20" r="3" stroke="currentColor" strokeWidth="1.5"/>
      </svg>
    ),
    title: '思いついた瞬間に、書ける。',
    body: 'Fnダブルタップ、もしくは任意のショートカットで一瞬で開く。書いて、閉じる。Cmd+Tabもアプリ切替も、もう要りません。'
  },
  {
    icon: (
      <svg viewBox="0 0 32 32" fill="none">
        <path d="M16 5 18 11 24 13 18 15 16 21 14 15 8 13 14 11 16 5Z" stroke="currentColor" strokeWidth="1.5" strokeLinejoin="round"/>
        <circle cx="24" cy="6" r="1.5" fill="currentColor"/>
        <circle cx="7" cy="24" r="1.5" fill="currentColor"/>
      </svg>
    ),
    title: '話しことばで、書くだけ。',
    body: '「明日15時に歯医者」「金曜までに資料」と打つだけ。日付・時刻・URL・リストを自動で読み取って、きれいなタスクに整えます。'
  },
  {
    icon: (
      <svg viewBox="0 0 32 32" fill="none">
        <circle cx="9" cy="9" r="3" stroke="currentColor" strokeWidth="1.5"/>
        <path d="M9 12v8M9 20h8" stroke="currentColor" strokeWidth="1.5"/>
        <circle cx="20" cy="20" r="3" stroke="currentColor" strokeWidth="1.5"/>
        <path d="M9 16h5M14 16v6M14 22h3" stroke="currentColor" strokeWidth="1.5"/>
        <circle cx="20" cy="22" r="3" stroke="currentColor" strokeWidth="1.5"/>
      </svg>
    ),
    title: '大きなタスクも、ひるまない。',
    body: '親タスクをAIが3〜7個のサブタスクに分解。確認・編集してから、まとめて登録。手をつけ始めるまでが、ずっと軽くなります。'
  },
  {
    icon: (
      <svg viewBox="0 0 32 32" fill="none">
        <circle cx="16" cy="16" r="11" stroke="currentColor" strokeWidth="1.5"/>
        <path d="M16 5a11 11 0 0 1 0 22" stroke="currentColor" strokeWidth="1.5"/>
        <circle cx="16" cy="16" r="3" stroke="currentColor" strokeWidth="1.5"/>
      </svg>
    ),
    title: '“進行中” が、ちゃんと分かる。',
    body: '未着手・進行中・完了の3状態を表示。#wip タグで表現するので、iPhoneの純正リマインダーでもそのまま見えます。'
  },
  {
    icon: (
      <svg viewBox="0 0 32 32" fill="none">
        <rect x="5" y="7" width="22" height="20" rx="2" stroke="currentColor" strokeWidth="1.5"/>
        <path d="M5 12h22M11 4v6M21 4v6" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"/>
        <rect x="9" y="16" width="3" height="3" rx="0.5" fill="currentColor"/>
        <rect x="14.5" y="16" width="3" height="3" rx="0.5" fill="currentColor" opacity="0.4"/>
      </svg>
    ),
    title: '今週が、一目で見える。',
    body: 'カレンダービューで月をまるごと俯瞰。日本の祝日にも対応しているので、月曜の朝の段取りがすぐ立ちます。'
  },
];

const Features = ({ accent }) => (
  <section className="section" data-screen-label="02 Features" id="features">
    <div className="section-head">
      <div className="kicker" style={{ color: accent }}>FEATURES</div>
      <h2>小さく、軽く、<br/>でも、ちゃんと深い。</h2>
      <p>クイック入力ツールでは終わらない。メニューバーの中だけで、毎日のタスク管理がきちんと完結します。</p>
    </div>
    <div className="feature-grid">
      {features.map((f, i) => (
        <div className="feature-card" key={i}>
          <div className="feature-icon" style={{ color: accent }}>{f.icon}</div>
          <h3>{f.title}</h3>
          <p>{f.body}</p>
        </div>
      ))}
    </div>
  </section>
);

// ─── AI Input Demo ──────────────────────────────────────────────────────────

const AI_PHRASES = [
  { input: '明日15時に歯医者', list: '暮らし', listColor: '#3CC97A', date: '明日 15:00', extra: null },
  { input: '今週金曜までに資料作る', list: '仕事', listColor: '#4A8BFF', date: '4/24 (金)', extra: null },
  { input: 'developer.apple.comの記事を読む', list: 'あとで読む', listColor: '#A26BFA', date: null, extra: 'developer.apple.com' },
];

const AIDemo = ({ accent, glassStrength }) => {
  const [phraseIdx, setPhraseIdx] = useState(0);
  const [typed, setTyped] = useState('');
  const [phase, setPhase] = useState('typing');
  const ref = useRef(null);
  const [active, setActive] = useState(false);

  useEffect(() => {
    const obs = new IntersectionObserver(([e]) => setActive(e.isIntersecting), { threshold: 0.3 });
    if (ref.current) obs.observe(ref.current);
    return () => obs.disconnect();
  }, []);

  useEffect(() => {
    if (!active) return;
    let cancelled = false;
    const phrase = AI_PHRASES[phraseIdx].input;

    const run = async () => {
      setTyped('');
      setPhase('typing');
      for (let i = 0; i <= phrase.length; i++) {
        if (cancelled) return;
        await new Promise(r => setTimeout(r, 60));
        setTyped(phrase.slice(0, i));
      }
      await new Promise(r => setTimeout(r, 500));
      if (cancelled) return;
      setPhase('parsing');
      await new Promise(r => setTimeout(r, 900));
      if (cancelled) return;
      setPhase('done');
      await new Promise(r => setTimeout(r, 2200));
      if (cancelled) return;
      setPhraseIdx(p => (p + 1) % AI_PHRASES.length);
    };
    run();
    return () => { cancelled = true; };
  }, [phraseIdx, active]);

  const cur = AI_PHRASES[phraseIdx];

  return (
    <section className="section section-ai" ref={ref} data-screen-label="03 AI Demo">
      <div className="section-head">
        <div className="kicker" style={{ color: accent }}>AI INPUT</div>
        <h2>書いた文章が、そのままタスクになる。</h2>
        <p>日付、時刻、URL、リスト。意味のある情報を自動で抽出してくれます。</p>
      </div>

      <div className="ai-stage">
        <div className="ai-pop">
          <HutchPopover
            accent={accent}
            glassStrength={glassStrength}
            mode="ai"
            aiTyping={typed}
            hoverable={false}
          />
        </div>

        <div className="ai-arrows">
          <svg width="80" height="120" viewBox="0 0 80 120" fill="none">
            <path d="M70 20 Q40 30 20 60 Q15 75 18 100" stroke={accent} strokeWidth="1.2" strokeDasharray="3 4" opacity={phase === 'parsing' || phase === 'done' ? 0.6 : 0.15} style={{ transition: 'opacity 0.4s' }}/>
            <path d="M65 30 Q35 45 25 70" stroke={accent} strokeWidth="1.2" strokeDasharray="3 4" opacity={phase === 'parsing' || phase === 'done' ? 0.6 : 0.15} style={{ transition: 'opacity 0.4s' }}/>
          </svg>
        </div>

        <div className="ai-output">
          <div className="ai-out-label">抽出された属性</div>
          <div className={`ai-chips ${phase === 'parsing' || phase === 'done' ? 'is-on' : ''}`}>
            <div className="ai-chip" style={{ '--c': cur.listColor, animationDelay: '0ms' }}>
              <span className="ai-chip-key">リスト</span>
              <span className="ai-chip-val">
                <span className="ai-diamond" style={{ background: cur.listColor }} />
                {cur.list}
              </span>
            </div>
            {cur.date && (
              <div className="ai-chip" style={{ '--c': accent, animationDelay: '120ms' }}>
                <span className="ai-chip-key">日時</span>
                <span className="ai-chip-val" style={{ color: accent }}>
                  <svg width="11" height="11" viewBox="0 0 16 16"><rect x="2.5" y="3.5" width="11" height="10" rx="1.5" stroke="currentColor" strokeWidth="1.2" fill="none"/><path d="M2.5 6.5h11" stroke="currentColor" strokeWidth="1.2"/></svg>
                  {cur.date}
                </span>
              </div>
            )}
            {cur.extra && (
              <div className="ai-chip" style={{ '--c': '#A26BFA', animationDelay: '240ms' }}>
                <span className="ai-chip-key">URL</span>
                <span className="ai-chip-val" style={{ color: '#A26BFA' }}>
                  <svg width="11" height="11" viewBox="0 0 16 16"><path d="M6.5 9.5 9.5 6.5M6 5h-.5a3 3 0 0 0 0 6H7M9 11h.5a3 3 0 0 0 0-6H8" stroke="currentColor" strokeWidth="1.2" fill="none" strokeLinecap="round"/></svg>
                  {cur.extra}
                </span>
              </div>
            )}
            <div className={`ai-chip ai-chip-final ${phase === 'done' ? 'is-final' : ''}`}>
              <svg width="12" height="12" viewBox="0 0 16 16"><path d="m3.5 8 3 3 6-6.5" stroke={accent} strokeWidth="1.6" fill="none" strokeLinecap="round" strokeLinejoin="round"/></svg>
              タスクとして登録
            </div>
          </div>
        </div>
      </div>
    </section>
  );
};

// ─── Subtask decompose demo ─────────────────────────────────────────────────

const SubtaskDemo = ({ accent, glassStrength }) => {
  const [step, setStep] = useState(0);

  useEffect(() => {
    let mounted = true;
    const cycle = async () => {
      while (mounted) {
        setStep(0);
        await new Promise(r => setTimeout(r, 1200));
        if (!mounted) return;
        setStep(1);
        await new Promise(r => setTimeout(r, 1200));
        if (!mounted) return;
        setStep(2);
        await new Promise(r => setTimeout(r, 4000));
      }
    };
    cycle();
    return () => { mounted = false; };
  }, []);

  return (
    <section className="section section-sub" data-screen-label="04 Subtask">
      <div className="section-head">
        <div className="kicker" style={{ color: accent }}>SUBTASKS</div>
        <h2>大きな仕事は、小さく分けて。</h2>
        <p>親タスクをAIが3〜7個のサブタスクに分解。確認してから、一括で登録できます。</p>
      </div>

      <div className="sub-stage">
        <div className="sub-pop">
          <HutchPopover
            accent={accent}
            glassStrength={glassStrength}
            expandedTask={step >= 2 ? 't5' : null}
            subtaskState={step >= 2 ? 'full' : 'idle'}
            hoverable={false}
          />
        </div>

        <div className="sub-side">
          <div className={`sub-step ${step >= 0 ? 'on' : ''}`}>
            <div className="sub-step-num">1</div>
            <div>
              <div className="sub-step-title">親タスクを書く</div>
              <div className="sub-step-body">"提案書のドラフト作成"</div>
            </div>
          </div>
          <div className={`sub-step ${step >= 1 ? 'on' : ''}`}>
            <div className="sub-step-num">2</div>
            <div>
              <div className="sub-step-title">AIで分解</div>
              <div className="sub-step-body">
                {step === 1 ? <span className="sub-thinking">考え中...</span> : '5つのサブタスクを提案'}
              </div>
            </div>
          </div>
          <div className={`sub-step ${step >= 2 ? 'on' : ''}`}>
            <div className="sub-step-num">3</div>
            <div>
              <div className="sub-step-title">確認 → 一括登録</div>
              <div className="sub-step-body">編集も並べ替えもしてから保存。</div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
};

// ─── Reminders sync section ─────────────────────────────────────────────────

const SyncSection = ({ accent }) => (
  <section className="section section-sync" data-screen-label="05 Sync">
    <div className="sync-grid">
      <div className="sync-copy">
        <div className="kicker" style={{ color: accent }}>NATIVE INTEGRATION</div>
        <h2>乗り換え、不要。</h2>
        <p>
          Hutch は独自のデータストアを持ちません。EventKit で純正リマインダーを直接読み書きします。
          だから、いま使っているリスト、iCloud 同期、共有リスト、iPhone 連携が、何もしなくてもそのまま使えます。
        </p>
        <ul className="sync-list">
          <li><span className="sync-check" style={{ background: accent }}>✓</span> 既存のリスト構成をそのまま利用</li>
          <li><span className="sync-check" style={{ background: accent }}>✓</span> iCloud で iPhone / iPad と双方向同期</li>
          <li><span className="sync-check" style={{ background: accent }}>✓</span> 家族と共有しているリストもそのまま</li>
          <li><span className="sync-check" style={{ background: accent }}>✓</span> Hutch を削除してもデータは残る</li>
        </ul>
      </div>

      <div className="sync-diagram">
        <div className="sync-node sync-node-mac">
          <div className="sync-glyph" style={{ borderColor: accent }}>
            <svg width="22" height="22" viewBox="0 0 32 32" fill="none">
              <rect x="4" y="6" width="24" height="16" rx="2" stroke="currentColor" strokeWidth="1.5"/>
              <path d="M11 26h10M14 22v4M18 22v4" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"/>
            </svg>
          </div>
          <span>Hutch</span>
          <small>menu bar</small>
        </div>

        <div className="sync-cloud" style={{ borderColor: accent }}>
          <svg width="32" height="20" viewBox="0 0 32 20" fill="none">
            <path d="M9 16h14a5 5 0 0 0 .4-9.96A7 7 0 0 0 9.5 8 4 4 0 0 0 9 16Z" stroke={accent} strokeWidth="1.4" fill="rgba(255,255,255,0.6)"/>
          </svg>
          <span>iCloud</span>
        </div>

        <div className="sync-node sync-node-iphone">
          <div className="sync-glyph" style={{ borderColor: accent }}>
            <svg width="14" height="22" viewBox="0 0 16 26" fill="none">
              <rect x="2" y="2" width="12" height="22" rx="2.5" stroke="currentColor" strokeWidth="1.5"/>
              <path d="M6 4h4" stroke="currentColor" strokeWidth="1.2" strokeLinecap="round"/>
            </svg>
          </div>
          <span>iPhone</span>
          <small>純正アプリ</small>
        </div>

        <div className="sync-node sync-node-ipad">
          <div className="sync-glyph" style={{ borderColor: accent }}>
            <svg width="20" height="22" viewBox="0 0 24 26" fill="none">
              <rect x="2" y="2" width="20" height="22" rx="2.5" stroke="currentColor" strokeWidth="1.5"/>
            </svg>
          </div>
          <span>iPad</span>
          <small>純正アプリ</small>
        </div>

        <svg className="sync-lines" viewBox="0 0 600 320" preserveAspectRatio="none">
          <path d="M120 60 Q300 60 300 130" stroke={accent} strokeWidth="1.5" fill="none" strokeDasharray="4 5" opacity="0.6"/>
          <path d="M300 170 Q300 240 480 270" stroke={accent} strokeWidth="1.5" fill="none" strokeDasharray="4 5" opacity="0.6"/>
          <path d="M300 170 Q300 240 130 270" stroke={accent} strokeWidth="1.5" fill="none" strokeDasharray="4 5" opacity="0.6"/>
        </svg>
      </div>
    </div>
  </section>
);

// ─── For Whom ───────────────────────────────────────────────────────────────

const personas = [
  {
    title: 'リマインダーをよく使う方',
    body: '既存の Apple リマインダーを使っている方の体験を、何も壊さずに拡張します。',
    icon: (<svg viewBox="0 0 32 32" fill="none"><circle cx="16" cy="11" r="5" stroke="currentColor" strokeWidth="1.5"/><path d="M6 26c2-5 6-7 10-7s8 2 10 7" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"/></svg>),
  },
  {
    title: '素早くタスクを書きたい方',
    body: '思いついたときに、ウインドウを切り替えず、メニューバーから1秒で書ける。',
    icon: (<svg viewBox="0 0 32 32" fill="none"><path d="M22 5 27 10 12 25l-7 2 2-7L22 5Z" stroke="currentColor" strokeWidth="1.5" strokeLinejoin="round"/><path d="M19 8l5 5" stroke="currentColor" strokeWidth="1.5"/></svg>),
  },
  {
    title: '作業の流れを止めたくない方',
    body: 'アプリの切り替えを最小限に。集中が途切れないように設計しています。',
    icon: (<svg viewBox="0 0 32 32" fill="none"><circle cx="16" cy="16" r="11" stroke="currentColor" strokeWidth="1.5"/><path d="M16 9v7l5 3" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"/></svg>),
  },
  {
    title: 'iPhone / iPad と連携したい方',
    body: 'データはすべて iCloud。Apple デバイス間でシームレスに使えます。',
    icon: (<svg viewBox="0 0 32 32" fill="none"><path d="M12 4 8 8l4 4M20 28l4-4-4-4" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/><path d="M8 8h12a4 4 0 0 1 4 4M24 24H12a4 4 0 0 1-4-4" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"/></svg>),
  },
];

const Personas = ({ accent }) => (
  <section className="section" data-screen-label="06 Personas">
    <div className="section-head">
      <div className="kicker" style={{ color: accent }}>WHO IT'S FOR</div>
      <h2>こんな方におすすめ。</h2>
    </div>
    <div className="persona-grid">
      {personas.map((p, i) => (
        <div className="persona-card" key={i}>
          <div className="persona-icon" style={{ color: accent, background: `${accent}14` }}>{p.icon}</div>
          <h4>{p.title}</h4>
          <p>{p.body}</p>
        </div>
      ))}
    </div>
  </section>
);

// ─── Install ────────────────────────────────────────────────────────────────

const Install = ({ accent }) => {
  const [copied, setCopied] = useState(false);
  const cmd = `git clone https://github.com/Riku4230/Hutch.git\ncd Hutch\n./scripts/build_app.sh --install`;
  const onCopy = () => {
    navigator.clipboard?.writeText(cmd);
    setCopied(true);
    setTimeout(() => setCopied(false), 1600);
  };
  return (
    <section className="section section-install" id="install" data-screen-label="07 Install">
      <div className="section-head">
        <div className="kicker" style={{ color: accent }}>INSTALL</div>
        <h2>ソースから、ビルドする。</h2>
        <p>
          Hutch は現在、未署名・未公証の OSS 版として配布しています。<br/>
          最も安全な利用方法は、ソースコードを確認した上で、ローカル環境でビルドすることです。
        </p>
      </div>

      <div className="install-card">
        <div className="install-tabs">
          <span className="install-tab is-on" style={{ color: accent }}>Recommended</span>
          <span className="install-tab-sub">3コマンドでインストール</span>
        </div>
        <div className="install-code">
          <pre><code>{cmd}</code></pre>
          <button className="install-copy" onClick={onCopy} style={{ color: copied ? accent : undefined }}>
            {copied ? '✓ Copied' : 'Copy'}
          </button>
        </div>
        <div className="install-meta">
          <span><span className="dot" /> Xcode 15+ が必要です</span>
          <span><span className="dot" /> Apple Silicon / Intel</span>
          <span><span className="dot" /> macOS 13 Ventura 以降</span>
        </div>
      </div>

      <div className="advanced-card" id="advanced">
        <div className="advanced-l">
          <h4>上級者向けダウンロード</h4>
          <p>
            利便性のため、GitHub Releases で事前ビルド済みの <code>.dmg</code> を配布しています。<br/>
            現在のビルドは未署名・未公証のため、初回起動時に macOS Gatekeeper にブロックされる場合があります。
          </p>
        </div>
        <a href="https://github.com/Riku4230/Hutch/releases" target="_blank" rel="noopener" className="advanced-btn">
          <svg width="13" height="13" viewBox="0 0 16 16" fill="none"><path d="M8 11V3m0 8L5 8m3 3 3-3M3 13h10" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round"/></svg>
          未署名ビルドをダウンロード
        </a>
      </div>
    </section>
  );
};

// ─── Security ───────────────────────────────────────────────────────────────

const Security = ({ accent }) => (
  <section className="section section-security" data-screen-label="08 Security">
    <div className="security-grid">
      <div className="security-copy">
        <div className="kicker" style={{ color: accent }}>SECURITY & PRIVACY</div>
        <h2>ローカルファースト、<br/>透明な設計。</h2>
        <p>Hutch は中継サーバーを持ちません。あなたのデータは、あなたのデバイスとあなたが選んだ AI プロバイダーの間だけを流れます。</p>
      </div>
      <div className="security-list">
        <div className="security-item">
          <div className="security-icon" style={{ color: accent }}>
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none"><path d="M12 2 4 6v6c0 5 3.5 9 8 10 4.5-1 8-5 8-10V6l-8-4Z" stroke="currentColor" strokeWidth="1.6"/><circle cx="12" cy="11" r="2" stroke="currentColor" strokeWidth="1.6"/><path d="M12 13v3" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round"/></svg>
          </div>
          <div>
            <h5>API キーは macOS Keychain に保存</h5>
            <p>OS のセキュア領域に格納。Hutch から外には出ません。</p>
          </div>
        </div>
        <div className="security-item">
          <div className="security-icon" style={{ color: accent }}>
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none"><rect x="3" y="6" width="18" height="14" rx="2" stroke="currentColor" strokeWidth="1.6"/><path d="M3 10h18" stroke="currentColor" strokeWidth="1.6"/><path d="M8 14h4" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round"/></svg>
          </div>
          <div>
            <h5>リマインダーは純正 / iCloud 上に</h5>
            <p>Hutch のデータベースは存在しません。EventKit 経由で読み書きするだけ。</p>
          </div>
        </div>
        <div className="security-item">
          <div className="security-icon" style={{ color: accent }}>
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none"><path d="M5 12h14M12 5l7 7-7 7" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round"/></svg>
          </div>
          <div>
            <h5>AI リクエストは直接送信</h5>
            <p>選択したプロバイダーへ直接通信。Hutch 専用の中継サーバーは使いません。</p>
          </div>
        </div>
        <div className="security-item">
          <div className="security-icon" style={{ color: accent }}>
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none"><circle cx="12" cy="12" r="9" stroke="currentColor" strokeWidth="1.6"/><path d="M12 8v5M12 16v.5" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round"/></svg>
          </div>
          <div>
            <h5>未署名ビルド（現在）</h5>
            <p>事前ビルドは未署名・未公証です。安全を最優先するならソースからビルドしてください。</p>
          </div>
        </div>
      </div>
    </div>
  </section>
);

// ─── Why Unsigned ───────────────────────────────────────────────────────────

const WhyUnsigned = ({ accent }) => (
  <section className="section section-why" data-screen-label="09 Why Unsigned">
    <div className="why-card">
      <div className="kicker" style={{ color: accent }}>WHY UNSIGNED?</div>
      <h2>なぜ、未署名なのか。</h2>
      <p>
        Hutch は現在、初期 OSS フェーズのプロジェクトです。
        署名・公証済みビルドの配布には Apple Developer Program への加入が必要です。
      </p>
      <p>
        現時点では、ソースコードを確認してローカルでビルドする方法を推奨しています。
        今後、より広く配布する段階で <strong>Developer ID 署名と Apple 公証</strong>に対応する予定です。
      </p>
    </div>
  </section>
);

// ─── FAQ ────────────────────────────────────────────────────────────────────

const faqs = [
  {
    q: '普通にダウンロードして使えますか？',
    a: 'はい。ただし、現在の事前ビルド済みアプリは未署名・未公証です。そのため、macOS の Gatekeeper 警告が表示される場合があります。安全性を重視する場合は、ソースからビルドしてください。',
  },
  {
    q: 'Apple Developer ID で署名されていますか？',
    a: 'まだ対応していません。現在の Hutch は、Developer ID 署名・Apple 公証済みビルドを提供していません。将来のリリースで対応予定です。',
  },
  {
    q: 'API キーはどこに保存されますか？',
    a: 'API キーは macOS Keychain に保存されます。Hutch 専用のサーバーには送信されません。',
  },
  {
    q: 'リマインダーのデータはどこに保存されますか？',
    a: 'すべて Apple 純正のリマインダー（iCloud）に保存されます。Hutch 独自のデータストアは持ちません。Hutch を削除しても、データは純正側に残ります。',
  },
  {
    q: '料金はかかりますか？',
    a: 'Hutch 自体は無料・オープンソース（MIT License）です。AI 機能を使う場合は、利用する AI プロバイダーへの API 利用料が別途かかります。',
  },
];

const FAQ = ({ accent }) => {
  const [openIdx, setOpenIdx] = useState(0);
  return (
    <section className="section section-faq" data-screen-label="10 FAQ">
      <div className="section-head">
        <div className="kicker" style={{ color: accent }}>FAQ</div>
        <h2>よくある質問</h2>
      </div>
      <div className="faq-list">
        {faqs.map((f, i) => (
          <div className={`faq-item ${openIdx === i ? 'is-open' : ''}`} key={i} onClick={() => setOpenIdx(openIdx === i ? -1 : i)}>
            <div className="faq-q">
              <span>{f.q}</span>
              <span className="faq-toggle" style={{ color: accent }}>{openIdx === i ? '−' : '+'}</span>
            </div>
            {openIdx === i && <div className="faq-a">{f.a}</div>}
          </div>
        ))}
      </div>
    </section>
  );
};

// ─── CTA + Footer ───────────────────────────────────────────────────────────

const CTA = ({ accent }) => (
  <section className="section section-cta" data-screen-label="11 CTA">
    <div className="cta-card" style={{ '--accent': accent }}>
      <h2>
        いつも手元にある、<br/>
        <span style={{ color: accent }}>小さな棚を。</span>
      </h2>
      <p>無料・オープンソース。透明で、ローカルファーストな設計です。</p>
      <div className="cta-buttons">
        <a href="https://github.com/Riku4230/Hutch" className="btn-primary btn-lg" style={{ background: accent }} target="_blank" rel="noopener">
          <svg width="14" height="14" viewBox="0 0 16 16" fill="currentColor"><path d="M8 1.3c-3.7 0-6.7 3-6.7 6.7 0 3 1.9 5.5 4.6 6.4.3.1.5-.1.5-.3v-1.2c-1.9.4-2.3-.9-2.3-.9-.3-.8-.7-1-.7-1-.6-.4 0-.4 0-.4.7 0 1 .7 1 .7.6 1 1.6.7 2 .6 0-.5.2-.7.4-.9-1.5-.2-3.1-.7-3.1-3.3 0-.7.3-1.3.7-1.8-.1-.2-.3-.9.1-1.9 0 0 .6-.2 2 .7.6-.2 1.2-.3 1.8-.3.6 0 1.2.1 1.8.3 1.4-.9 2-.7 2-.7.4 1 .1 1.7.1 1.9.4.5.7 1.1.7 1.8 0 2.6-1.6 3.1-3.1 3.3.2.2.4.6.4 1.2v1.7c0 .2.1.4.5.3 2.7-.9 4.6-3.4 4.6-6.4 0-3.7-3-6.7-6.7-6.7Z"/></svg>
          GitHubでソースを見る
        </a>
      </div>
      <div className="cta-meta">
        <span>macOS 13 Ventura+</span>
        <span className="cta-dot">·</span>
        <span>Apple Silicon / Intel</span>
        <span className="cta-dot">·</span>
        <span>MIT License</span>
      </div>
    </div>
  </section>
);

const Footer = ({ accent }) => (
  <footer className="footer">
    <div className="footer-inner">
      <div className="footer-brand">
        <div className="footer-logo" style={{ color: accent }}>
          <img src="hutch-icon.png" alt="" style={{ width: 22, height: 22 }} />
          <span>Hutch</span>
        </div>
        <p>いつものリマインダーが、ぐっと近くなる。</p>
      </div>
      <div className="footer-cols">
        <div>
          <h5>プロダクト</h5>
          <a href="#features">機能</a>
          <a href="#install">インストール</a>
          <a href="https://github.com/Riku4230/Hutch/releases/latest" target="_blank" rel="noopener">最新リリース</a>
          <a href="https://github.com/Riku4230/Hutch/blob/main/CHANGELOG.md" target="_blank" rel="noopener">変更履歴</a>
        </div>
        <div>
          <h5>リソース</h5>
          <a href="https://github.com/Riku4230/Hutch" target="_blank" rel="noopener">GitHub リポジトリ</a>
          <a href="https://github.com/Riku4230/Hutch#readme" target="_blank" rel="noopener">README (日本語)</a>
          <a href="https://github.com/Riku4230/Hutch/blob/main/README.en.md" target="_blank" rel="noopener">README (English)</a>
          <a href="https://github.com/Riku4230/Hutch/blob/main/SECURITY.md" target="_blank" rel="noopener">セキュリティポリシー</a>
        </div>
        <div>
          <h5>コミュニティ</h5>
          <a href="https://github.com/Riku4230/Hutch/issues" target="_blank" rel="noopener">Issues を見る</a>
          <a href="https://github.com/Riku4230/Hutch/issues/new" target="_blank" rel="noopener">バグ報告 / 機能要望</a>
          <a href="https://github.com/Riku4230/Hutch/blob/main/CONTRIBUTING.md" target="_blank" rel="noopener">Contributing</a>
          <a href="https://github.com/Riku4230/Hutch/blob/main/LICENSE" target="_blank" rel="noopener">MIT License</a>
        </div>
      </div>
    </div>
    <div className="footer-base">
      <span>© 2026 Hutch · MIT License</span>
      <span>Made for Apple Reminders, on macOS.</span>
    </div>
  </footer>
);

// ─── App ────────────────────────────────────────────────────────────────────

function App() {
  const [t, setTweak] = useTweaks(TWEAK_DEFAULTS);
  const accent = t.preset === 'custom' ? t.accent : (ACCENT_PRESETS[t.preset] || t.accent);

  return (
    <div className="page" style={{ '--accent': accent }}>
      <Hero accent={accent} glassStrength={t.glassStrength} />
      <Features accent={accent} />
      <AIDemo accent={accent} glassStrength={t.glassStrength} />
      <SubtaskDemo accent={accent} glassStrength={t.glassStrength} />
      <SyncSection accent={accent} />
      <CTA accent={accent} />
      <Footer accent={accent} />

      <TweaksPanel title="Tweaks">
        <TweakSection label="Theme" />
        <TweakRadio
          label="アクセント"
          value={t.preset}
          options={['indigo', 'emerald', 'rose', 'amber', 'graphite']}
          onChange={(v) => setTweak({ preset: v, accent: ACCENT_PRESETS[v] })}
        />
        <TweakSection label="Glass" />
        <TweakSlider
          label="ガラス強度"
          value={t.glassStrength}
          min={0.2}
          max={1}
          step={0.05}
          onChange={(v) => setTweak('glassStrength', v)}
        />
      </TweaksPanel>
    </div>
  );
}

const root = ReactDOM.createRoot(document.getElementById('root'));
root.render(<App />);
