// popover.jsx — Hutch風のオリジナルポップオーバー
// Apple純正のリマインダーUIではなく、Hutch独自のGlass Float表現として実装

const HutchPopover = ({ accent = '#5B7CFA', glassStrength = 0.62, mode = 'list', aiTyping = '', subtaskState = 'idle', expandedTask = null, completedIds = [], onToggleComplete, onClickTask, hoverable = true, scale = 1 }) => {
  // mode: 'list' | 'ai' | 'subtask'
  const accentSoft = accent + '22';
  const accentMid = accent + '55';

  const tasks = [
    { id: 't1', list: '暮らし', listColor: '#3CC97A', title: '牛乳とパンを買う', meta: '今日 19:00', metaIcon: 'cal', highlight: true },
    { id: 't2', list: '暮らし', listColor: '#3CC97A', title: 'クリーニングを受け取る', meta: '土 11:00', metaIcon: 'cal' },
    { id: 't3', list: '仕事', listColor: '#4A8BFF', title: '週次レポートのまとめ', meta: '明日', metaIcon: 'cal' },
    { id: 't4', list: '仕事', listColor: '#4A8BFF', title: 'デザインレビューの準備', meta: '明日', metaIcon: 'cal', wip: true },
    { id: 't5', list: '仕事', listColor: '#4A8BFF', title: '提案書のドラフト作成', meta: '明日', metaIcon: 'cal' },
  ];

  const subtasks = [
    '参考資料を3つ集める',
    '構成のアウトラインを書く',
    '本文を書く',
    '図版を差し込む',
    '最終チェックして共有',
  ];

  const grouped = {};
  tasks.forEach(t => { (grouped[t.list] = grouped[t.list] || []).push(t); });

  return (
    <div className="hp-wrap" style={{ '--accent': accent, '--accent-soft': accentSoft, '--accent-mid': accentMid, '--glass': glassStrength, transform: `scale(${scale})`, transformOrigin: 'top center' }}>
      <div className="hp-shadow" />
      <div className="hp-pop">
        {/* Header */}
        <div className="hp-hd">
          <div className="hp-hd-l">
            <div className="hp-inbox">
              <svg width="14" height="14" viewBox="0 0 16 16" fill="none">
                <path d="M2 4.5 4 2.5h8l2 2v7a1.5 1.5 0 0 1-1.5 1.5h-9A1.5 1.5 0 0 1 2 11.5v-7Z" stroke="currentColor" strokeWidth="1.1"/>
                <path d="M2.5 8h3l1 1.5h3L10.5 8h3" stroke="currentColor" strokeWidth="1.1" strokeLinejoin="round"/>
              </svg>
            </div>
            <div className="hp-hd-text">
              <div className="hp-hd-title">すべて<span className="hp-chev">▾</span></div>
              <div className="hp-hd-sub">5件</div>
            </div>
          </div>
          <div className="hp-hd-r">
            <button className="hp-iconbtn"><svg width="13" height="13" viewBox="0 0 16 16"><rect x="2.5" y="3.5" width="11" height="10" rx="1.5" stroke="currentColor" strokeWidth="1.1" fill="none"/><path d="M2.5 6.5h11" stroke="currentColor" strokeWidth="1.1"/></svg></button>
            <button className="hp-iconbtn"><svg width="13" height="13" viewBox="0 0 16 16"><circle cx="8" cy="8" r="5" stroke="currentColor" strokeWidth="1.1" fill="none"/><path d="m6 8 1.5 1.5L10.5 6.5" stroke="currentColor" strokeWidth="1.1" fill="none"/></svg></button>
            <button className="hp-iconbtn"><svg width="13" height="13" viewBox="0 0 16 16"><circle cx="4" cy="8" r="1" fill="currentColor"/><circle cx="8" cy="8" r="1" fill="currentColor"/><circle cx="12" cy="8" r="1" fill="currentColor"/></svg></button>
          </div>
        </div>

        {/* Search */}
        <div className="hp-search">
          <svg width="11" height="11" viewBox="0 0 16 16"><circle cx="7" cy="7" r="4.5" stroke="currentColor" strokeWidth="1.1" fill="none"/><path d="m10.5 10.5 3 3" stroke="currentColor" strokeWidth="1.2" strokeLinecap="round"/></svg>
          <span>検索</span>
        </div>

        {/* List body */}
        <div className="hp-body">
          {Object.entries(grouped).map(([list, items]) => (
            <div key={list} className="hp-group">
              <div className="hp-group-hd">
                <span className="hp-diamond" style={{ background: items[0].listColor }} />
                <span className="hp-group-name">{list}</span>
              </div>
              {items.map(t => {
                const done = completedIds.includes(t.id);
                const isExpandedParent = expandedTask === t.id;
                return (
                  <React.Fragment key={t.id}>
                    <div className={`hp-task ${hoverable ? 'hp-hover' : ''} ${done ? 'hp-done' : ''}`} onClick={() => onClickTask && onClickTask(t.id)}>
                      <button
                        className={`hp-check ${done ? 'is-done' : ''} ${t.wip ? 'is-wip' : ''}`}
                        style={{ '--c': t.listColor }}
                        onClick={(e) => { e.stopPropagation(); onToggleComplete && onToggleComplete(t.id); }}
                      >
                        {done && <svg width="9" height="9" viewBox="0 0 12 12"><path d="m2.5 6.5 2.2 2.2L9.5 3.5" stroke="white" strokeWidth="1.6" fill="none" strokeLinecap="round" strokeLinejoin="round"/></svg>}
                        {t.wip && !done && <span className="hp-wip-arc" />}
                      </button>
                      <div className="hp-task-text">
                        <div className="hp-task-title">{t.title}</div>
                        <div className="hp-task-meta">
                          {t.wip && <span className="hp-wip-tag" style={{ color: accent }}>● 進行中</span>}
                          <span className="hp-meta-cal">
                            <svg width="10" height="10" viewBox="0 0 16 16"><rect x="2.5" y="3.5" width="11" height="10" rx="1.5" stroke="currentColor" strokeWidth="1.1" fill="none"/><path d="M2.5 6.5h11M5.5 2v3M10.5 2v3" stroke="currentColor" strokeWidth="1.1"/></svg>
                            {t.meta}
                          </span>
                        </div>
                      </div>
                    </div>
                    {isExpandedParent && subtaskState !== 'idle' && (
                      <div className="hp-subtasks">
                        {subtasks.slice(0, subtaskState === 'partial' ? 2 : 5).map((s, i) => (
                          <div className="hp-subtask" key={i} style={{ animationDelay: `${i * 80}ms` }}>
                            <div className="hp-sub-line" />
                            <button className="hp-check hp-check-sm" style={{ '--c': t.listColor }} />
                            <span>{s}</span>
                          </div>
                        ))}
                      </div>
                    )}
                  </React.Fragment>
                );
              })}
            </div>
          ))}
        </div>

        {/* Composer */}
        <div className={`hp-comp ${mode === 'ai' ? 'is-ai' : ''}`}>
          <button className={`hp-ai-btn ${mode === 'ai' ? 'is-on' : ''}`}>
            <svg width="13" height="13" viewBox="0 0 16 16">
              <path d="M8 2.5 9.2 6 12.7 7.2 9.2 8.4 8 12 6.8 8.4 3.3 7.2 6.8 6 8 2.5Z" fill={mode === 'ai' ? accent : 'currentColor'}/>
              <circle cx="13" cy="3" r="1" fill={mode === 'ai' ? accent : 'currentColor'}/>
              <circle cx="3" cy="13" r="1" fill={mode === 'ai' ? accent : 'currentColor'}/>
            </svg>
          </button>
          <div className="hp-input">
            {mode === 'ai' ? (
              <span className="hp-typing">
                {aiTyping || <span className="hp-ph">自然言語で追加…</span>}
                {aiTyping && <span className="hp-caret" />}
              </span>
            ) : (
              <span className="hp-ph">新規リマインダー…</span>
            )}
          </div>
          <button className="hp-iconbtn hp-chevbtn">
            <svg width="11" height="11" viewBox="0 0 16 16"><path d="m4 6 4 4 4-4" stroke="currentColor" strokeWidth="1.4" fill="none" strokeLinecap="round" strokeLinejoin="round"/></svg>
          </button>
          <button className="hp-send" style={{ background: accent }}>
            <svg width="11" height="11" viewBox="0 0 16 16"><path d="M8 12.5V3.5m0 0L4.5 7M8 3.5 11.5 7" stroke="white" strokeWidth="1.6" fill="none" strokeLinecap="round" strokeLinejoin="round"/></svg>
          </button>
        </div>
      </div>
    </div>
  );
};

window.HutchPopover = HutchPopover;
