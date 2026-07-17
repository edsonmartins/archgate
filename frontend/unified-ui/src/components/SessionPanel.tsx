import { useCallback, useState } from 'react'
import type { Connection, SessionState } from '../types'

/**
 * W4-UI04 scaffold — chrome only.
 * Next: guacamole-common-js Guacamole.Client + WebSocket tunnel to guacd (via BFF).
 */
export function SessionPanel({ connection }: { connection: Connection | null }) {
  const [state, setState] = useState<SessionState>('idle')
  const [note, setNote] = useState('Nenhuma sessão ativa')

  const connect = useCallback(() => {
    if (!connection) return
    if (connection.engine === 'warpgate') {
      setState('connected')
      setNote(
        `Desktop: use o cliente nativo no bastion — target «${connection.target}». ` +
          `Deep-link / snippet virá em W4-UI07.`,
      )
      return
    }
    // guacamole path — stub until common-js wired
    setState('connecting')
    setNote('Conectando (stub)…')
    window.setTimeout(() => {
      setState('connected')
      setNote(
        `Stub canvas — integrar guacamole-common-js → guacd para «${connection.target}». ` +
          `Token de túnel só via BFF server-side (W4-UI05).`,
      )
    }, 400)
  }, [connection])

  const disconnect = useCallback(() => {
    setState('disconnected')
    setNote('Sessão encerrada')
  }, [])

  if (!connection) {
    return (
      <div className="card">
        <h2>Sessão</h2>
        <p className="muted">Selecione uma conexão no catálogo.</p>
      </div>
    )
  }

  return (
    <div className="card" style={{ padding: 0, overflow: 'hidden' }}>
      <div className="session-chrome">
        <span className={`dot ${state === 'connected' ? '' : 'off'}`} />
        <strong>{connection.name}</strong>
        <span className="muted">
          {connection.engine} · {connection.target}
        </span>
        <span style={{ flex: 1 }} />
        {state !== 'connected' && state !== 'connecting' && (
          <button type="button" className="btn" onClick={connect}>
            Conectar
          </button>
        )}
        {(state === 'connected' || state === 'connecting') && (
          <button type="button" className="btn" onClick={disconnect}>
            Desconectar
          </button>
        )}
      </div>
      <div className="session-canvas-wrap">
        {/* Future: <canvas ref={displayRef} /> for guacamole-common-js */}
        <div style={{ padding: '1.5rem', textAlign: 'center', maxWidth: 420 }}>
          <p style={{ margin: '0 0 0.5rem' }}>{note}</p>
          <p className="muted" style={{ margin: 0, fontSize: '0.8rem' }}>
            Estado: {state}
          </p>
        </div>
      </div>
    </div>
  )
}
