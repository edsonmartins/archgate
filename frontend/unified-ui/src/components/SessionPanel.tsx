import { useCallback, useMemo, useState } from 'react'
import type { Connection, SessionState } from '../types'
import { requestTunnelSession, type TunnelSession } from '../api/sessionTunnel'
import { buildWarpgateLaunch } from '../launch/warpgate'
import { GuacamoleDisplay } from './GuacamoleDisplay'
import { LaunchSnippets } from './LaunchSnippets'

type Props = {
  connection: Connection | null
  /** Warpgate / IdP username for snippets */
  username?: string
}

/**
 * W4-UI04 chrome + W4-UI07 Warpgate launch + W4-UI11 guacamole-common-js.
 */
export function SessionPanel({ connection, username }: Props) {
  const [state, setState] = useState<SessionState>('idle')
  const [note, setNote] = useState('Nenhuma sessão ativa')
  const [tunnel, setTunnel] = useState<TunnelSession | null>(null)

  const launch = useMemo(() => {
    if (!connection || connection.engine !== 'warpgate') return null
    return buildWarpgateLaunch(connection, username ?? 'SEU_USUARIO')
  }, [connection, username])

  const connect = useCallback(async () => {
    if (!connection) return
    if (connection.engine === 'warpgate') {
      setTunnel(null)
      setState('connected')
      setNote(
        `Use o cliente nativo no bastion (snippets abaixo) — target «${connection.target}».`,
      )
      return
    }

    setState('connecting')
    setNote('Solicitando token de sessão ao BFF…')
    setTunnel(null)
    try {
      const s = await requestTunnelSession({
        connectionId: connection.id,
        target: connection.target,
        protocol: connection.protocol,
      })
      setTunnel(s)
      setNote(
        s.source === 'bff'
          ? `Túnel BFF · ${connection.target}`
          : `Demo local · ${connection.target} (sem guacd real)`,
      )
      setState('connecting')
    } catch (e) {
      setState('error')
      setNote(
        e instanceof Error
          ? e.message
          : 'Falha ao abrir sessão. Configure BFF /api/unified/v1/sessions.',
      )
    }
  }, [connection])

  const disconnect = useCallback(() => {
    setTunnel(null)
    setState('disconnected')
    setNote('Sessão encerrada')
  }, [])

  const onGuacState = useCallback(
    (s: 'connecting' | 'connected' | 'error' | 'disconnected', detail?: string) => {
      if (s === 'connected') {
        setState('connected')
        setNote('Sessão Guacamole ativa')
      } else if (s === 'connecting') {
        setState('connecting')
      } else if (s === 'error') {
        setState('error')
        if (detail) setNote(detail)
      } else if (s === 'disconnected') {
        setState('disconnected')
        setNote('Desconectado')
      }
    },
    [],
  )

  if (!connection) {
    return (
      <div className="card">
        <h2>Sessão</h2>
        <p className="muted">Selecione uma conexão no catálogo.</p>
      </div>
    )
  }

  const guacActive =
    connection.engine === 'guacamole' &&
    tunnel != null &&
    (state === 'connecting' || state === 'connected' || state === 'error')
  const embeddedClient = tunnel?.embedUrl

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
          <button type="button" className="btn" onClick={() => void connect()}>
            {connection.engine === 'warpgate' ? 'Mostrar launch' : 'Conectar'}
          </button>
        )}
        {(state === 'connected' || state === 'connecting' || state === 'error') && (
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
        ) : embeddedClient ? (
          <iframe
            title={`Sessão ${connection.name}`}
            src={embeddedClient}
            style={{ width: '100%', height: '100%', border: 0 }}
            allow="clipboard-read; clipboard-write"
          />
        ) : guacActive && tunnel ? (
          <GuacamoleDisplay session={tunnel} active onState={onGuacState} />
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
            {connection.engine === 'guacamole' && state === 'idle' && (
              <p className="muted" style={{ marginTop: '0.75rem', fontSize: '0.8rem' }}>
                guacamole-common-js → túnel BFF (W4-UI11). Token admin nunca no browser.
              </p>
            )}
          </div>
        )}
      </div>
    </div>
  )
}
