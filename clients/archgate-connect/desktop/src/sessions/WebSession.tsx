import { useEffect, useState } from 'react'
import { printOpenUrl } from './api'
import type { Connection } from '../protocol'

type Props = {
  connection: Connection
  active: boolean
  onState: (state: 'connecting' | 'connected' | 'error' | 'closed', note?: string) => void
}

/** Embedded browser surface for HTTP / Oracle UI (iframe — not system browser). */
export function WebSession({ connection, active: _active, onState }: Props) {
  const [url, setUrl] = useState<string | null>(null)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    let disposed = false
    onState('connecting', 'Resolvendo URL embutida…')
    void printOpenUrl(connection.target)
      .then((po) => {
        if (disposed) return
        const u = po.url
        if (!u) {
          setError('URL vazia')
          onState('error', 'URL vazia')
          return
        }
        setUrl(u)
        onState('connected', `Web · ${u}`)
      })
      .catch((e) => {
        if (disposed) return
        const msg = e instanceof Error ? e.message : String(e)
        setError(msg)
        onState('error', msg)
      })
    return () => {
      disposed = true
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [connection.target])

  if (error) {
    return (
      <div className="session-placeholder">
        <p className="session-placeholder-title">Web</p>
        <p>{error}</p>
      </div>
    )
  }
  if (!url) {
    return (
      <div className="session-placeholder">
        <p>Carregando painel embutido…</p>
      </div>
    )
  }

  return (
    <div className="guac-session-wrap">
      <div className="ssh-terminal-banner">
        Embutido no app · {url} · use SSO se o painel pedir
      </div>
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
