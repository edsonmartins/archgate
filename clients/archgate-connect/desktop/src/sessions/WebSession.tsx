import { useEffect, useState } from 'react'
import { printOpenUrl, requestTunnelSession } from './api'
import type { Connection } from '../protocol'

type Props = {
  connection: Connection
  active: boolean
  onState: (state: 'connecting' | 'connected' | 'error' | 'closed', note?: string) => void
}

function isOracle(c: Connection): boolean {
  const p = (c.protocol || '').toLowerCase()
  const t = (c.target || '').toLowerCase()
  return p === 'oracle' || t.includes('oracle')
}

/** Embedded browser surface for HTTP / Oracle UI (iframe — not system browser). */
export function WebSession({ connection, active: _active, onState }: Props) {
  const [url, setUrl] = useState<string | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [banner, setBanner] = useState<string | null>(null)
  const oracle = isOracle(connection)

  useEffect(() => {
    let disposed = false
    onState('connecting', oracle ? 'Resolvendo Oracle UI…' : 'Resolvendo URL embutida…')
    void (async () => {
      // Prefer BFF session embed (same path as Guac) when available.
      try {
        const tun = await requestTunnelSession({
          connectionId: connection.id,
          target: connection.target,
          protocol: connection.protocol || (oracle ? 'oracle' : 'http'),
        })
        if (disposed) return
        if (tun.embedUrl) {
          setUrl(tun.embedUrl)
          setBanner(
            oracle
              ? `Oracle UI embutido · ${tun.embedUrl} · SSO se pedido`
              : `Web embutido · ${tun.embedUrl}`,
          )
          onState('connected', `${oracle ? 'Oracle' : 'Web'} · ${tun.embedUrl}`)
          return
        }
      } catch {
        /* fall through to print-open */
      }
      try {
        const po = await printOpenUrl(connection.target)
        if (disposed) return
        const u = po.url
        if (!u) {
          setError('URL vazia')
          onState('error', 'URL vazia')
          return
        }
        setUrl(u)
        setBanner(
          oracle
            ? `Oracle UI · ${u} · proxy de credencial no console (não IP do banco)`
            : `Embutido · ${u}`,
        )
        onState('connected', `${oracle ? 'Oracle' : 'Web'} · ${u}`)
      } catch (e) {
        if (disposed) return
        const msg = e instanceof Error ? e.message : String(e)
        setError(msg)
        onState('error', msg)
      }
    })()
    return () => {
      disposed = true
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [connection.id, connection.target, connection.protocol])

  if (error) {
    return (
      <div className="session-placeholder">
        <p className="session-placeholder-title">{oracle ? 'Oracle' : 'Web'}</p>
        <p>{error}</p>
      </div>
    )
  }
  if (!url) {
    return (
      <div className="session-placeholder">
        <p>{oracle ? 'Abrindo Oracle UI embutida…' : 'Carregando painel embutido…'}</p>
      </div>
    )
  }

  return (
    <div className={`guac-session-wrap ${oracle ? 'web-oracle' : 'web-http'}`}>
      <div className="ssh-terminal-banner">{banner || url}</div>
      <iframe
        className="embed-frame"
        title={connection.target}
        src={url}
        allow="clipboard-read; clipboard-write; fullscreen"
        referrerPolicy="no-referrer-when-downgrade"
      />
    </div>
  )
}
