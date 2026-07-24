import { useEffect, useRef, useState } from 'react'
import Guacamole from 'guacamole-common-js'
import { printOpenUrl, requestTunnelSession, type TunnelSession } from './api'
import type { Connection } from '../protocol'

type Props = {
  sessionId: string
  connection: Connection
  active: boolean
  onState: (state: 'connecting' | 'connected' | 'error' | 'closed', note?: string) => void
}

type GuacClient = {
  getDisplay: () => { getElement: () => HTMLElement }
  connect: (data?: string) => void
  disconnect: () => void
  sendMouseState: (state: unknown, applyDisplayScale?: boolean) => void
  sendKeyEvent: (pressed: number, keysym: number) => void
  onstatechange: ((state: number) => void) | null
  onerror: ((status: { code?: number; message?: string }) => void) | null
}

/**
 * Embedded RDP/VNC/SSH-browser via Guacamole inside Connect (not system browser).
 * Prefer websocket tunnel from BFF; fall back to in-app iframe SSO to Guac UI.
 */
export function GuacSession({ sessionId: _sessionId, connection, active, onState }: Props) {
  const hostRef = useRef<HTMLDivElement>(null)
  const clientRef = useRef<GuacClient | null>(null)
  const [mode, setMode] = useState<'loading' | 'ws' | 'iframe' | 'error'>('loading')
  const [iframeUrl, setIframeUrl] = useState<string | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [banner, setBanner] = useState<string | null>(null)

  useEffect(() => {
    let disposed = false
    const start = async () => {
      onState('connecting', 'Pedindo túnel Guacamole ao BFF…')
      setMode('loading')
      setError(null)

      let tunnel: TunnelSession | null = null
      try {
        tunnel = await requestTunnelSession({
          connectionId: connection.id,
          target: connection.target,
          protocol: connection.protocol || 'rdp',
        })
      } catch (e) {
        // Fall through to print-open / iframe
        if (!disposed) {
          setBanner(
            e instanceof Error
              ? `BFF: ${e.message} — usando Guac embutido (iframe SSO).`
              : 'BFF indisponível — iframe Guac.',
          )
        }
      }

      if (disposed) return

      // Prefer iframe when BFF says so, or when websocket URL empty.
      const preferIframe =
        tunnel?.embedMode === 'iframe' ||
        !tunnel?.tunnelUrl ||
        (tunnel?.embedUrl && !tunnel.connectData)

      if (preferIframe || !tunnel?.tunnelUrl) {
        let url = tunnel?.embedUrl || ''
        if (!url) {
          try {
            const po = await printOpenUrl(connection.target)
            url = po.url || po.guac_base || 'https://guac.archgate.com.br/'
          } catch {
            url = 'https://guac.archgate.com.br/'
          }
        }
        if (disposed) return
        setIframeUrl(url)
        setMode('iframe')
        onState('connected', `Guac embutido · ${url}`)
        setBanner('Sessão no app (iframe). Faça SSO se pedido — não é browser externo.')
        return
      }

      // WebSocket tunnel + guacamole-common-js
      if (!hostRef.current) return
      hostRef.current.innerHTML = ''
      try {
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        const G = Guacamole as any
        const wsTunnel = new G.WebSocketTunnel(tunnel.tunnelUrl)
        const client = new G.Client(wsTunnel) as GuacClient
        clientRef.current = client

        const display = client.getDisplay()
        const el = display.getElement()
        el.style.maxWidth = '100%'
        el.style.maxHeight = '100%'
        hostRef.current.appendChild(el)

        const mouse = new G.Mouse(el)
        mouse.onEach(['mousedown', 'mouseup', 'mousemove'], () => {
          client.sendMouseState(mouse.currentState, true)
        })

        const keyboard = new G.Keyboard(document)
        keyboard.onkeydown = (keysym: number) => client.sendKeyEvent(1, keysym)
        keyboard.onkeyup = (keysym: number) => client.sendKeyEvent(0, keysym)

        client.onstatechange = (state: number) => {
          if (disposed) return
          if (state === 1 || state === 2) onState('connecting')
          else if (state === 3) {
            onState('connected', `Guac WS · ${connection.target}`)
            setBanner(null)
          } else if (state === 5) onState('closed', 'Guacamole desconectado')
        }
        client.onerror = (status) => {
          if (disposed) return
          const msg = status?.message || `Guacamole error ${status?.code ?? '?'}`
          // Fallback iframe if WS fails
          void (async () => {
            try {
              const po = await printOpenUrl(connection.target)
              if (disposed) return
              setIframeUrl(po.url || 'https://guac.archgate.com.br/')
              setMode('iframe')
              setBanner(`WS falhou (${msg}) — iframe embutido.`)
              onState('connected', 'Guac iframe (fallback)')
            } catch {
              setError(msg)
              setMode('error')
              onState('error', msg)
            }
          })()
        }

        setMode('ws')
        client.connect(tunnel.connectData)
      } catch (e) {
        const msg = e instanceof Error ? e.message : String(e)
        setError(msg)
        setMode('error')
        onState('error', msg)
      }
    }

    void start()
    return () => {
      disposed = true
      try {
        clientRef.current?.disconnect()
      } catch {
        /* ignore */
      }
      clientRef.current = null
      if (hostRef.current) hostRef.current.innerHTML = ''
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [connection.id, connection.target, connection.protocol])

  useEffect(() => {
    if (!active) return
  }, [active])

  return (
    <div className="guac-session-wrap">
      {banner ? <div className="ssh-terminal-banner">{banner}</div> : null}
      {error ? (
        <div className="session-placeholder">
          <p className="session-placeholder-title">Guacamole</p>
          <p>{error}</p>
        </div>
      ) : null}
      {mode === 'iframe' && iframeUrl ? (
        <iframe
          className="embed-frame"
          title={`Guac ${connection.target}`}
          src={iframeUrl}
          allow="clipboard-read; clipboard-write; fullscreen"
          referrerPolicy="no-referrer-when-downgrade"
        />
      ) : (
        <div ref={hostRef} className="guac-host" hidden={mode === 'iframe'} />
      )}
      {mode === 'loading' ? (
        <div className="session-placeholder">
          <p>Abrindo sessão embutida RDP/VNC/Guac…</p>
        </div>
      ) : null}
    </div>
  )
}
