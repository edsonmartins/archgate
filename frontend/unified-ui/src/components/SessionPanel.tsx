import { useCallback, useMemo, useState } from 'react'
import type { Connection, SessionState } from '../types'
import { buildWarpgateLaunch } from '../launch/warpgate'
import { LaunchSnippets } from './LaunchSnippets'

type Props = {
  connection: Connection | null
  /** Warpgate / IdP username for snippets */
  username?: string
}

/**
 * W4-UI04 chrome + W4-UI07 Warpgate launch.
 * Next: guacamole-common-js Guacamole.Client + WebSocket tunnel (via BFF).
 */
export function SessionPanel({ connection, username }: Props) {
  const [state, setState] = useState<SessionState>('idle')
  const [note, setNote] = useState('Nenhuma sessão ativa')

  const launch = useMemo(() => {
    if (!connection || connection.engine !== 'warpgate') return null
    return buildWarpgateLaunch(connection, username ?? 'SEU_USUARIO')
  }, [connection, username])

  const connect = useCallback(() => {
    if (!connection) return
    if (connection.engine === 'warpgate') {
      setState('connected')
      setNote(
        `Use o cliente nativo no bastion (snippets abaixo) — target «${connection.target}».`,
      )
      return
    }
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
            {connection.engine === 'warpgate' ? 'Mostrar launch' : 'Conectar'}
          </button>
        )}
        {(state === 'connected' || state === 'connecting') && (
          <button type="button" className="btn" onClick={disconnect}>
            Fechar
          </button>
        )}
      </div>
      <div className="session-canvas-wrap">
        {connection.engine === 'warpgate' && launch && state === 'connected' ? (
          <div style={{ padding: '1rem', width: '100%', textAlign: 'left' }}>
            <p style={{ margin: '0 0 0.75rem', textAlign: 'center' }}>{note}</p>
            <LaunchSnippets bundle={launch} />
          </div>
        ) : (
          <div style={{ padding: '1.5rem', textAlign: 'center', maxWidth: 420 }}>
            <p style={{ margin: '0 0 0.5rem' }}>{note}</p>
            <p className="muted" style={{ margin: 0, fontSize: '0.8rem' }}>
              Estado: {state}
            </p>
            {connection.engine === 'warpgate' && state === 'idle' && (
              <p className="muted" style={{ marginTop: '0.75rem', fontSize: '0.8rem' }}>
                Clique em «Mostrar launch» para SSH/psql/DBeaver (W4-UI07).
              </p>
            )}
          </div>
        )}
      </div>
    </div>
  )
}
