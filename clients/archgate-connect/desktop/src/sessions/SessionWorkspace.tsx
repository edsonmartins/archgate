import type { SessionTab, SessionState } from './types'
import { kindLabel } from './types'
import { SshTerminal } from './SshTerminal'

type Props = {
  tabs: SessionTab[]
  activeId: string | null
  onSelect: (id: string) => void
  onClose: (id: string) => void
  onExternal: (tab: SessionTab) => void
  onSessionState: (id: string, state: SessionState, note?: string) => void
  busy?: boolean
}

export function SessionWorkspace({
  tabs,
  activeId,
  onSelect,
  onClose,
  onExternal,
  onSessionState,
  busy,
}: Props) {
  const active = tabs.find((t) => t.id === activeId) || null

  if (tabs.length === 0) {
    return (
      <div className="session-workspace empty">
        <div className="session-empty">
          <h2>Sessões</h2>
          <p>
            Selecione uma conexão e clique <strong>Connect</strong> para abrir uma
            aba (estilo RDM). SSH abre terminal embutido via Warpgate; RDP/Guac
            embutido em seguida — “Externo” usa Terminal / browser.
          </p>
        </div>
      </div>
    )
  }

  return (
    <div className="session-workspace">
      <div className="session-tabs" role="tablist" aria-label="Sessões abertas">
        {tabs.map((t) => (
          <div
            key={t.id}
            className={`session-tab ${t.id === activeId ? 'active' : ''}`}
            role="tab"
            aria-selected={t.id === activeId}
          >
            <button type="button" className="session-tab-label" onClick={() => onSelect(t.id)}>
              <span className={`tab-badge kind-${t.kind}`}>{kindLabel(t.kind)}</span>
              <span className="tab-title" title={t.connection.target}>
                {t.connection.target}
              </span>
              {t.state === 'connected' ? <span className="tab-live" title="Conectado" /> : null}
            </button>
            <button
              type="button"
              className="session-tab-close"
              aria-label={`Fechar ${t.connection.target}`}
              onClick={() => onClose(t.id)}
            >
              ×
            </button>
          </div>
        ))}
      </div>

      {/* Keep all tab surfaces mounted so SSH PTYs stay alive when switching tabs */}
      {tabs.map((tab) => {
        const isActive = tab.id === activeId
        return (
          <div
            key={tab.id}
            className="session-body"
            role="tabpanel"
            hidden={!isActive}
            style={{ display: isActive ? 'flex' : 'none' }}
          >
            <div className="session-chrome">
              <div className="session-chrome-meta">
                <strong>{tab.connection.target}</strong>
                <span className="dim">
                  {tab.connection.protocol} · {tab.connection.engine} · {tab.state}
                </span>
              </div>
              <div className="session-chrome-actions">
                <button
                  type="button"
                  className="btn btn-sm btn-ssh"
                  disabled={busy}
                  onClick={() => onExternal(tab)}
                >
                  Abrir externo
                </button>
                <button
                  type="button"
                  className="btn btn-sm btn-ghost"
                  onClick={() => onClose(tab.id)}
                >
                  Fechar aba
                </button>
              </div>
            </div>
            <div className={`session-surface kind-${tab.kind} ${tab.kind === 'ssh' ? 'filled' : ''}`}>
              {tab.kind === 'ssh' ? (
                <SshTerminal
                  sessionId={tab.id}
                  target={tab.connection.target}
                  active={isActive}
                  onState={(state, note) => onSessionState(tab.id, state, note)}
                />
              ) : (
                <div className="session-placeholder">
                  <p className="session-placeholder-title">
                    {kindLabel(tab.kind)} · {tab.connection.target}
                  </p>
                  <p>{tab.note}</p>
                  <p className="hint">
                    {tab.kind === 'guac'
                      ? 'Canvas Guacamole (RDP) nesta área — S2b.'
                      : 'Painel embutido / externo conforme o protocolo.'}
                  </p>
                  <button
                    type="button"
                    className="btn btn-primary"
                    disabled={busy}
                    onClick={() => onExternal(tab)}
                  >
                    Abrir externo agora
                  </button>
                </div>
              )}
            </div>
          </div>
        )
      })}

      {!active ? null : null}
    </div>
  )
}
