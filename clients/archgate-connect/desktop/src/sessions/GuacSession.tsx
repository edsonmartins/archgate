import { useEffect, useRef, useState } from 'react'
import Guacamole from 'guacamole-common-js'
import { printOpenUrl, requestTunnelSession, type TunnelSession } from './api'
import type { Connection } from '../protocol'

type Props = {
  sessionId: string
  connection: Connection
  active: boolean
  onState: (state: 'connecting' | 'connected' | 'error' | 'closed', note?: string) => void
  fullscreen?: boolean
  onToggleFullscreen?: () => void
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

function hasRealGuacToken(tunnel: TunnelSession | null | undefined): boolean {
  if (!tunnel?.connectData || !tunnel.tunnelUrl) return false
  const d = tunnel.connectData
  return (
    (/(?:^|&)token=/.test(d) || d.includes('token=')) &&
    (d.includes('GUAC_ID=') || d.includes('GUAC_DATA_SOURCE='))
  )
}

/**
 * Embedded RDP/VNC/SSH-browser via Guacamole inside Connect (not system browser).
 * Prefer websocket tunnel + real BFF token (F4); fall back to iframe SSO.
 */
export function GuacSession({
  sessionId: _sessionId,
  connection,
  active,
  onState,
  fullscreen,
  onToggleFullscreen,
}: Props) {
  const hostRef = useRef<HTMLDivElement>(null)
  const clientRef = useRef<GuacClient | null>(null)
  const [mode, setMode] = useState<'loading' | 'ws' | 'iframe' | 'error'>('loading')
  const [iframeUrl, setIframeUrl] = useState<string | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [banner, setBanner] = useState<string | null>(null)

  useEffect(() => {
    let disposed = false
    const start = async () => {
      onState('connecting', 'Pedindo token Guacamole ao BFF…')
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
        if (!disposed) {
          setBanner(
            e instanceof Error
              ? `BFF: ${e.message} — tentando Guac embutido (iframe).`
              : 'BFF indisponível — iframe Guac.',
          )
        }
      }

      if (disposed) return

      const realToken = hasRealGuacToken(tunnel)
      const preferWs =
        realToken ||
        (tunnel?.embedMode === 'websocket' && !!tunnel.tunnelUrl && !!tunnel.connectData)
      const preferIframe =
        !preferWs &&
        (tunnel?.embedMode === 'iframe' ||
          !tunnel?.tunnelUrl ||
          (tunnel?.embedUrl && !tunnel.connectData))

      if (preferIframe || !preferWs) {
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
        onState('connected', `Guac iframe · ${connection.target}`)
        setBanner(
          realToken
            ? null
            : 'Sessão no app (iframe SSO). Token WS indisponível — não é browser externo.',
        )
        return
      }

      // WebSocket tunnel + guacamole-common-js with real BFF token
      if (!hostRef.current || !tunnel) return
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
          void (async () => {
            try {
              let fallback = tunnel?.embedUrl || ''
              if (!fallback) {
                const po = await printOpenUrl(connection.target)
                fallback = po.url || po.guac_base || 'https://guac.archgate.com.br/'
              }
              if (disposed) return
              setIframeUrl(fallback)
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
        setBanner(realToken ? 'Túnel Guacamole (token BFF)' : null)
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
    <div className={`guac-session-wrap ${fullscreen ? 'guac-fullscreen' : ''}`}>
      <div className="guac-toolbar">
        <span className="guac-toolbar-mode dim">
          {mode === 'ws' ? 'WS' : mode === 'iframe' ? 'iframe' : mode}
          {fullscreen ? ' · fullscreen' : ''}
        </span>
        {onToggleFullscreen ? (
          <button
            type="button"
            className="icon-btn guac-fs-btn"
            onClick={onToggleFullscreen}
            title={fullscreen ? 'Sair da tela cheia (Esc)' : 'Tela cheia (Guac)'}
            aria-label={fullscreen ? 'Sair da tela cheia' : 'Tela cheia'}
          >
            {fullscreen ? '⊡' : '⛶'}
          </button>
        ) : null}
      </div>
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
