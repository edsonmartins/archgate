import { useMemo, useState } from 'react'
import {
  FONT_OPTIONS,
  THEME_PRESETS,
  hasTargetOverride,
  type CursorStyle,
  type TerminalAppearance,
} from './terminalPrefs'
import { useTerminalPrefs } from './TerminalPrefsContext'

type Scope = 'global' | 'target'

type Props = {
  open: boolean
  onClose: () => void
  /** When set, panel can edit this connection's override. */
  initialTarget?: string | null
}

export function TerminalPrefsPanel({ open, onClose, initialTarget }: Props) {
  const { store, appearanceFor, updateGlobal, updateTarget, resetTarget, resetAll } =
    useTerminalPrefs()
  const [scope, setScope] = useState<Scope>(initialTarget ? 'target' : 'global')
  const [targetKey, setTargetKey] = useState(initialTarget || '')

  const targets = useMemo(() => {
    const keys = new Set(Object.keys(store.byTarget))
    if (initialTarget) keys.add(initialTarget)
    return Array.from(keys).sort()
  }, [store.byTarget, initialTarget])

  const effectiveTarget = scope === 'target' ? targetKey || initialTarget || '' : ''
  const appearance = appearanceFor(scope === 'target' ? effectiveTarget || null : null)
  const hasOverride = effectiveTarget ? hasTargetOverride(store, effectiveTarget) : false

  if (!open) return null

  const apply = (patch: Partial<TerminalAppearance>) => {
    if (scope === 'global') {
      updateGlobal(patch)
    } else if (effectiveTarget) {
      updateTarget(effectiveTarget, patch)
    }
  }

  return (
    <div className="prefs-overlay" role="dialog" aria-modal="true" aria-labelledby="prefs-title">
      <div className="prefs-modal">
        <header className="prefs-header">
          <div>
            <h2 id="prefs-title">Preferências do terminal</h2>
            <p className="prefs-sub">Fonte, cores e cursor — global ou por conexão</p>
          </div>
          <button type="button" className="btn btn-ghost btn-sm" onClick={onClose}>
            Fechar
          </button>
        </header>

        <div className="prefs-scope">
          <button
            type="button"
            className={`prefs-scope-btn ${scope === 'global' ? 'active' : ''}`}
            onClick={() => setScope('global')}
          >
            Global
          </button>
          <button
            type="button"
            className={`prefs-scope-btn ${scope === 'target' ? 'active' : ''}`}
            onClick={() => {
              setScope('target')
              if (!targetKey && initialTarget) setTargetKey(initialTarget)
            }}
          >
            Por conexão
          </button>
        </div>

        {scope === 'target' ? (
          <div className="prefs-field">
            <label htmlFor="prefs-target">Conexão (target)</label>
            <div className="prefs-row">
              <input
                id="prefs-target"
                className="field"
                list="prefs-target-list"
                value={targetKey}
                onChange={(e) => setTargetKey(e.target.value.trim())}
                placeholder="ex.: rio-aws-api-b"
                spellCheck={false}
              />
              <datalist id="prefs-target-list">
                {targets.map((t) => (
                  <option key={t} value={t} />
                ))}
              </datalist>
              {hasOverride ? (
                <button
                  type="button"
                  className="btn btn-ghost btn-sm"
                  disabled={!effectiveTarget}
                  onClick={() => effectiveTarget && resetTarget(effectiveTarget)}
                  title="Voltar a herdar o global"
                >
                  Limpar override
                </button>
              ) : null}
            </div>
            {effectiveTarget && !hasOverride ? (
              <p className="prefs-hint">
                Sem override — mostrando valores globais. Qualquer alteração cria preferência só
                para <code>{effectiveTarget}</code>.
              </p>
            ) : null}
            {!effectiveTarget ? (
              <p className="prefs-hint err">Informe o nome do target para editar por conexão.</p>
            ) : null}
          </div>
        ) : null}

        <div className="prefs-grid" style={{ opacity: scope === 'target' && !effectiveTarget ? 0.45 : 1 }}>
          <div className="prefs-field">
            <label htmlFor="prefs-font">Fonte</label>
            <select
              id="prefs-font"
              className="field"
              value={
                FONT_OPTIONS.find((f) => f.value === appearance.fontFamily)?.value ||
                appearance.fontFamily
              }
              onChange={(e) => apply({ fontFamily: e.target.value })}
              disabled={scope === 'target' && !effectiveTarget}
            >
              {FONT_OPTIONS.map((f) => (
                <option key={f.id} value={f.value}>
                  {f.label}
                </option>
              ))}
              {!FONT_OPTIONS.some((f) => f.value === appearance.fontFamily) ? (
                <option value={appearance.fontFamily}>Custom</option>
              ) : null}
            </select>
          </div>

          <div className="prefs-field">
            <label htmlFor="prefs-size">
              Tamanho <span className="dim">{appearance.fontSize}px</span>
            </label>
            <input
              id="prefs-size"
              type="range"
              min={9}
              max={28}
              value={appearance.fontSize}
              onChange={(e) => apply({ fontSize: Number(e.target.value) })}
              disabled={scope === 'target' && !effectiveTarget}
            />
          </div>

          <div className="prefs-field">
            <label htmlFor="prefs-lh">
              Altura da linha <span className="dim">{appearance.lineHeight.toFixed(2)}</span>
            </label>
            <input
              id="prefs-lh"
              type="range"
              min={100}
              max={180}
              value={Math.round(appearance.lineHeight * 100)}
              onChange={(e) => apply({ lineHeight: Number(e.target.value) / 100 })}
              disabled={scope === 'target' && !effectiveTarget}
            />
          </div>

          <div className="prefs-field">
            <label htmlFor="prefs-cursor">Cursor</label>
            <select
              id="prefs-cursor"
              className="field"
              value={appearance.cursorStyle}
              onChange={(e) => apply({ cursorStyle: e.target.value as CursorStyle })}
              disabled={scope === 'target' && !effectiveTarget}
            >
              <option value="block">Bloco</option>
              <option value="underline">Sublinhado</option>
              <option value="bar">Barra</option>
            </select>
          </div>

          <div className="prefs-field prefs-check">
            <label>
              <input
                type="checkbox"
                checked={appearance.cursorBlink}
                onChange={(e) => apply({ cursorBlink: e.target.checked })}
                disabled={scope === 'target' && !effectiveTarget}
              />
              Cursor piscante
            </label>
          </div>

          <div className="prefs-field">
            <label htmlFor="prefs-theme">Tema de cores</label>
            <select
              id="prefs-theme"
              className="field"
              value={appearance.themePreset}
              onChange={(e) => {
                const id = e.target.value
                if (id === 'custom') {
                  apply({ themePreset: 'custom' })
                } else {
                  apply({
                    themePreset: id,
                    theme: THEME_PRESETS[id]?.theme,
                  })
                }
              }}
              disabled={scope === 'target' && !effectiveTarget}
            >
              {Object.entries(THEME_PRESETS).map(([id, p]) => (
                <option key={id} value={id}>
                  {p.label}
                </option>
              ))}
              <option value="custom">Custom (manual)</option>
            </select>
          </div>
        </div>

        <div className="prefs-preview" aria-hidden>
          <div
            className="prefs-preview-term"
            style={{
              fontFamily: appearance.fontFamily,
              fontSize: appearance.fontSize,
              lineHeight: appearance.lineHeight,
              background: appearance.theme.background,
              color: appearance.theme.foreground,
            }}
          >
            <span style={{ color: appearance.theme.green }}>operador</span>
            <span style={{ color: appearance.theme.brightBlack }}>@</span>
            <span style={{ color: appearance.theme.cyan }}>bastion</span>
            <span style={{ color: appearance.theme.brightBlack }}>:~$</span>{' '}
            <span style={{ color: appearance.theme.yellow }}>ssh</span> target
            <span
              style={{
                display: 'inline-block',
                width: appearance.cursorStyle === 'bar' ? 2 : 8,
                height: appearance.cursorStyle === 'underline' ? 2 : '1em',
                marginLeft: 2,
                verticalAlign: appearance.cursorStyle === 'underline' ? 'bottom' : 'text-bottom',
                background: appearance.theme.cursor,
                opacity: 0.9,
              }}
            />
          </div>
        </div>

        {appearance.themePreset === 'custom' || scope === 'global' ? (
          <details className="prefs-advanced">
            <summary>Cores manuais (ANSI)</summary>
            <div className="prefs-colors">
              {(
                [
                  ['background', 'Fundo'],
                  ['foreground', 'Texto'],
                  ['cursor', 'Cursor'],
                  ['selectionBackground', 'Seleção'],
                  ['red', 'Red'],
                  ['green', 'Green'],
                  ['yellow', 'Yellow'],
                  ['blue', 'Blue'],
                  ['magenta', 'Magenta'],
                  ['cyan', 'Cyan'],
                ] as const
              ).map(([key, label]) => (
                <label key={key} className="prefs-color-item">
                  <span>{label}</span>
                  <input
                    type="color"
                    value={toColorInput(appearance.theme[key])}
                    onChange={(e) =>
                      apply({
                        themePreset: 'custom',
                        theme: { ...appearance.theme, [key]: e.target.value },
                      })
                    }
                    disabled={scope === 'target' && !effectiveTarget}
                  />
                </label>
              ))}
            </div>
          </details>
        ) : null}

        <footer className="prefs-footer">
          <button type="button" className="btn btn-ghost btn-sm" onClick={() => resetAll()}>
            Restaurar padrão global
          </button>
          <button type="button" className="btn btn-primary btn-sm" onClick={onClose}>
            Pronto
          </button>
        </footer>
      </div>
    </div>
  )
}

/** color input needs #rrggbb; coerce rgba/short hex best-effort */
function toColorInput(v: string): string {
  if (/^#[0-9a-fA-F]{6}$/.test(v)) return v
  if (/^#[0-9a-fA-F]{3}$/.test(v)) {
    const r = v[1]
    const g = v[2]
    const b = v[3]
    return `#${r}${r}${g}${g}${b}${b}`
  }
  // fallback sky
  return '#38bdf8'
}
