import { useEffect, useMemo, useRef, useState } from 'react'
import type { Connection } from '../protocol'
import { protocolMeta } from '../protocol'

type Props = {
  open: boolean
  connections: Connection[]
  onClose: () => void
  onConnect: (c: Connection) => void
}

export function CommandPalette({ open, connections, onClose, onConnect }: Props) {
  const [q, setQ] = useState('')
  const [idx, setIdx] = useState(0)
  const inputRef = useRef<HTMLInputElement>(null)

  const filtered = useMemo(() => {
    const needle = q.trim().toLowerCase()
    if (!needle) return connections.slice(0, 40)
    return connections
      .filter(
        (c) =>
          c.target.toLowerCase().includes(needle) ||
          c.site.toLowerCase().includes(needle) ||
          c.protocol.toLowerCase().includes(needle) ||
          (c.description || '').toLowerCase().includes(needle),
      )
      .slice(0, 40)
  }, [connections, q])

  useEffect(() => {
    if (!open) return
    setQ('')
    setIdx(0)
    const t = window.setTimeout(() => inputRef.current?.focus(), 30)
    return () => window.clearTimeout(t)
  }, [open])

  useEffect(() => {
    setIdx(0)
  }, [q])

  if (!open) return null

  return (
    <div
      className="palette-overlay"
      role="dialog"
      aria-modal="true"
      aria-label="Buscar conexão"
      onMouseDown={(e) => {
        if (e.target === e.currentTarget) onClose()
      }}
    >
      <div className="palette">
        <input
          ref={inputRef}
          className="field palette-input"
          placeholder="Buscar e conectar… (↑↓ Enter Esc)"
          value={q}
          onChange={(e) => setQ(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === 'Escape') {
              e.preventDefault()
              onClose()
            } else if (e.key === 'ArrowDown') {
              e.preventDefault()
              setIdx((i) => Math.min(filtered.length - 1, i + 1))
            } else if (e.key === 'ArrowUp') {
              e.preventDefault()
              setIdx((i) => Math.max(0, i - 1))
            } else if (e.key === 'Enter') {
              e.preventDefault()
              const c = filtered[idx]
              if (c) {
                onConnect(c)
                onClose()
              }
            }
          }}
        />
        <ul className="palette-list">
          {filtered.length === 0 ? (
            <li className="palette-empty">Nenhuma conexão</li>
          ) : (
            filtered.map((c, i) => {
              const meta = protocolMeta(c.protocol)
              return (
                <li key={c.id || c.target}>
                  <button
                    type="button"
                    className={`palette-item ${i === idx ? 'active' : ''}`}
                    onMouseEnter={() => setIdx(i)}
                    onClick={() => {
                      onConnect(c)
                      onClose()
                    }}
                  >
                    <span className={`chip ${meta.protoCls}`}>{meta.badge}</span>
                    <span className="palette-target">{c.target}</span>
                    <span className="palette-site dim">{c.site}</span>
                  </button>
                </li>
              )
            })
          )}
        </ul>
        <div className="palette-footer dim">
          <kbd>⌘K</kbd> abrir · <kbd>Enter</kbd> conectar · <kbd>Esc</kbd> fechar
        </div>
      </div>
    </div>
  )
}
