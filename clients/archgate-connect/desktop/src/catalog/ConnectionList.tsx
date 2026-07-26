import type { Connection } from '../protocol'
import { protocolMeta } from '../protocol'
import { isPendingApply } from './catalogPrefs'

export type ConnSection = {
  key: string
  label: string
  items: Connection[]
}

type Props = {
  sections: ConnSection[]
  activeTarget: string | null
  favorites: Set<string>
  pins: Set<string>
  selectedTarget: string | null
  busy: boolean
  pendingTarget: string | null
  onSelect: (c: Connection) => void
  onConnect: (c: Connection) => void
  onToggleFavorite: (target: string) => void
  onTogglePin: (target: string) => void
  onCopy: (c: Connection) => void
}

export function ConnectionList({
  sections,
  activeTarget,
  favorites,
  pins,
  selectedTarget,
  busy,
  pendingTarget,
  onSelect,
  onConnect,
  onToggleFavorite,
  onTogglePin,
  onCopy,
}: Props) {
  return (
    <div className="conn-sections">
      {sections.map((sec) => (
        <div key={sec.key} className="conn-section">
          <div className="conn-section-label">
            {sec.label}
            <span className="count-badge sm">{sec.items.length}</span>
          </div>
          <ul className="conn-list">
            {sec.items.map((c) => {
              const meta = protocolMeta(c.protocol)
              const pending = isPendingApply(c.description)
              const isActive = activeTarget === c.target
              const isSelected = selectedTarget === c.target
              const isConnecting = pendingTarget === c.target
              return (
                <li
                  key={c.id || c.target}
                  className={`conn-item ${meta.protoCls} ${isActive ? 'is-active' : ''} ${isSelected ? 'is-selected' : ''}`}
                  onClick={() => onSelect(c)}
                  onDoubleClick={() => onConnect(c)}
                >
                  <div className={`conn-icon ${meta.iconCls}`} aria-hidden>
                    {meta.badge}
                  </div>
                  <div className="conn-body">
                    <div className="conn-name" title={c.target}>
                      {pins.has(c.target) ? (
                        <span className="pin-mark" title="Fixado">
                          📌
                        </span>
                      ) : null}
                      {c.target}
                      {pending ? (
                        <span className="status-dot warn" title="Pending apply no gateway">
                          pending
                        </span>
                      ) : (
                        <span className="status-dot ok" title="No catálogo" />
                      )}
                    </div>
                    <div className="conn-meta">
                      <span className="chip">{c.protocol}</span>
                      <span className="chip">{c.engine}</span>
                      {c.site ? <span className="chip-site">{c.site}</span> : null}
                    </div>
                    {c.description ? (
                      <div className="conn-desc" title={c.description}>
                        {c.description}
                      </div>
                    ) : null}
                  </div>
                  <div className="conn-actions">
                    <button
                      type="button"
                      className={`icon-btn ${favorites.has(c.target) ? 'on' : ''}`}
                      title={favorites.has(c.target) ? 'Remover favorito' : 'Favoritar'}
                      aria-label="Favorito"
                      onClick={(e) => {
                        e.stopPropagation()
                        onToggleFavorite(c.target)
                      }}
                    >
                      {favorites.has(c.target) ? '★' : '☆'}
                    </button>
                    <button
                      type="button"
                      className="icon-btn"
                      title="Copiar comando SSH/psql"
                      aria-label="Copiar"
                      onClick={(e) => {
                        e.stopPropagation()
                        onCopy(c)
                      }}
                    >
                      ⎘
                    </button>
                    <button
                      type="button"
                      className={`btn btn-sm btn-action ${meta.actionBtn}`}
                      disabled={busy}
                      onClick={(e) => {
                        e.stopPropagation()
                        onConnect(c)
                      }}
                      aria-label={`Connect ${c.target}`}
                    >
                      {isConnecting ? '…' : 'Connect'}
                    </button>
                  </div>
                </li>
              )
            })}
          </ul>
        </div>
      ))}
    </div>
  )
}
