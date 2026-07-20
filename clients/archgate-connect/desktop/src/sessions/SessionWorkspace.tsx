import type { SessionTab } from './types'
import { kindLabel } from './types'

type Props = {
  tabs: SessionTab[]
  activeId: string | null
  onSelect: (id: string) => void
  onClose: (id: string) => void
  onExternal: (tab: SessionTab) => void
  busy?: boolean
}

export function SessionWorkspace({
  tabs,
  activeId,
  onSelect,
  onClose,
  onExternal,
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
            aba (estilo RDM). SSH e RDP/Guac embutidos entram nas próximas entregas;
            “Externo” usa o fluxo atual (Terminal / browser).
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

      {active ? (
        <div className="session-body" role="tabpanel">
          <div className="session-chrome">
            <div className="session-chrome-meta">
              <strong>{active.connection.target}</strong>
              <span className="dim">
                {active.connection.protocol} · {active.connection.engine} · {active.state}
              </span>
            </div>
            <div className="session-chrome-actions">
              <button
                type="button"
                className="btn btn-sm btn-ssh"
                disabled={busy}
                onClick={() => onExternal(active)}
              >
                Abrir externo
              </button>
              <button
                type="button"
                className="btn btn-sm btn-ghost"
                onClick={() => onClose(active.id)}
              >
                Fechar aba
              </button>
            </div>
          </div>
          <div className={`session-surface kind-${active.kind}`}>
            <div className="session-placeholder">
              <p className="session-placeholder-title">
                {kindLabel(active.kind)} · {active.connection.target}
              </p>
              <p>{active.note}</p>
              <p className="hint">
                Em breve: terminal xterm (SSH Warpgate) e canvas Guacamole (RDP) nesta
                área — sem sair do Connect.
              </p>
              <button
                type="button"
                className="btn btn-primary"
                disabled={busy}
                onClick={() => onExternal(active)}
              >
                Abrir externo agora
              </button>
            </div>
          </div>
        </div>
      ) : null}
    </div>
  )
}
