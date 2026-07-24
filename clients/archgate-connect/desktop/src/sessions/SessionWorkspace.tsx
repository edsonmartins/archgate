import type { SessionTab, SessionState } from './types'
import { kindLabel } from './types'
import { SshTerminal } from './SshTerminal'
import { GuacSession } from './GuacSession'
import { DbTerminal } from './DbTerminal'
import { WebSession } from './WebSession'

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
  if (tabs.length === 0) {
    return (
      <div className="session-workspace empty">
        <div className="session-empty">
          <h2>Sessões embutidas</h2>
          <p>
            <strong>Connect</strong> abre a sessão <em>dentro</em> do app (RDM-lite):
            SSH e Postgres em terminal embutido; RDP/VNC/Guac e HTTP/Oracle em painel
            embutido. “Abrir externo” é só fallback.
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

      {tabs.map((tab) => {
        const isActive = tab.id === activeId
        const filled =
          tab.kind === 'ssh' || tab.kind === 'guac' || tab.kind === 'db' || tab.kind === 'web'
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
                  {tab.note ? ` · ${tab.note}` : ''}
                </span>
              </div>
              <div className="session-chrome-actions">
                <button
                  type="button"
                  className="btn btn-sm btn-ssh"
                  disabled={busy}
                  onClick={() => onExternal(tab)}
                  title="Fallback: Terminal.app / browser do sistema"
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
            <div className={`session-surface ${filled ? 'filled' : ''} kind-${tab.kind}`}>
              {tab.kind === 'ssh' ? (
                <SshTerminal
                  sessionId={tab.id}
                  target={tab.connection.target}
                  active={isActive}
                  onState={(state, note) => onSessionState(tab.id, state, note)}
                />
              ) : tab.kind === 'guac' ? (
                <GuacSession
                  sessionId={tab.id}
                  connection={tab.connection}
                  active={isActive}
                  onState={(state, note) => onSessionState(tab.id, state, note)}
                />
              ) : tab.kind === 'db' ? (
                <DbTerminal
                  sessionId={tab.id}
                  target={tab.connection.target}
                  active={isActive}
                  onState={(state, note) => onSessionState(tab.id, state, note)}
                />
              ) : tab.kind === 'web' ? (
                <WebSession
                  connection={tab.connection}
                  active={isActive}
                  onState={(state, note) => onSessionState(tab.id, state, note)}
                />
              ) : (
                <div className="session-placeholder">
                  <p className="session-placeholder-title">{tab.connection.target}</p>
                  <p>{tab.note}</p>
                </div>
              )}
            </div>
          </div>
        )
      })}
    </div>
  )
}
