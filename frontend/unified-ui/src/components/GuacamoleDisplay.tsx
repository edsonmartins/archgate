import { useEffect, useRef, useState } from 'react'
// Runtime is a single default export (Guacamole namespace). Named ESM exports do not exist.
import Guacamole from 'guacamole-common-js'
import type { TunnelSession } from '../api/sessionTunnel'

type GuacClient = {
  getDisplay: () => { getElement: () => HTMLElement }
  connect: (data?: string) => void
  disconnect: () => void
  sendMouseState: (state: unknown, applyDisplayScale?: boolean) => void
  sendKeyEvent: (pressed: number, keysym: number) => void
  onstatechange: ((state: number) => void) | null
  onerror: ((status: { code?: number; message?: string }) => void) | null
}

type Props = {
  session: TunnelSession
  onState?: (state: 'connecting' | 'connected' | 'error' | 'disconnected', detail?: string) => void
  active: boolean
}

/**
 * W4-UI11 — guacamole-common-js display host.
 * Tunnel URL + connect data come from BFF (never admin tokens).
 */
export function GuacamoleDisplay({ session, onState, active }: Props) {
  const hostRef = useRef<HTMLDivElement>(null)
  const clientRef = useRef<GuacClient | null>(null)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    if (!active || !hostRef.current) return

    let disposed = false
    const host = hostRef.current
    host.innerHTML = ''

    try {
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const G = Guacamole as any
      const tunnel = new G.WebSocketTunnel(session.tunnelUrl)
      const client = new G.Client(tunnel) as GuacClient
      clientRef.current = client

      const display = client.getDisplay()
      const el = display.getElement()
      el.style.maxWidth = '100%'
      el.style.maxHeight = '100%'
      host.appendChild(el)

      const mouse = new G.Mouse(el)
      mouse.onEach(['mousedown', 'mouseup', 'mousemove'], () => {
        client.sendMouseState(mouse.currentState, true)
      })

      const keyboard = new G.Keyboard(document)
      keyboard.onkeydown = (keysym: number) => {
        client.sendKeyEvent(1, keysym)
      }
      keyboard.onkeyup = (keysym: number) => {
        client.sendKeyEvent(0, keysym)
      }

      client.onstatechange = (state: number) => {
        if (disposed) return
        // Client.State: 0 idle, 1 connecting, 2 waiting, 3 connected, 4 disconnecting, 5 disconnected
        if (state === 1 || state === 2) onState?.('connecting')
        else if (state === 3) onState?.('connected')
        else if (state === 5) onState?.('disconnected')
      }

      client.onerror = (status) => {
        if (disposed) return
        const msg = status?.message || `Guacamole error code ${status?.code ?? '?'}`
        setError(msg)
        onState?.('error', msg)
      }

      onState?.('connecting')
      client.connect(session.connectData)
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e)
      setError(msg)
      onState?.('error', msg)
    }

    return () => {
      disposed = true
      try {
        clientRef.current?.disconnect()
      } catch {
        /* ignore */
      }
      clientRef.current = null
      host.innerHTML = ''
    }
  }, [session.tunnelUrl, session.connectData, active, onState, session])

  return (
    <div className="guac-host" ref={hostRef}>
      {error && (
        <div className="guac-error">
          <p>{error}</p>
          <p className="muted" style={{ fontSize: '0.8rem' }}>
            Fonte: {session.source} · target {session.target}. Token só via BFF (W4-UI05).
            {session.source === 'demo' && ' Modo demo — guacd real exige BFF + VITE_GUAC_DEMO=0.'}
          </p>
        </div>
      )}
    </div>
  )
}
