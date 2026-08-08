/**
 * BFF short-lived Guacamole tunnel credentials (W4-UI05 / W4-UI11).
 * Admin tokens never leave the server — only opaque connect string for guacd path.
 */

import { config } from '../config'

export type TunnelSession = {
  /** WebSocket URL for Guacamole.WebSocketTunnel */
  tunnelUrl: string
  /** Opaque data passed to Guacamole.Client.connect() */
  connectData: string
  connectionId: string
  target: string
  expiresInSec?: number
  source: 'bff' | 'demo'
  /** Optional RustGuac built-in client URL with a one-shot ticket. */
  embedUrl?: string
}

export type TunnelRequest = {
  connectionId: string
  target: string
  protocol: string
}

/**
 * Request tunnel session from BFF.
 * Demo fallback only when VITE_GUAC_DEMO=1 (local chrome test without guacd).
 */
export async function requestTunnelSession(req: TunnelRequest): Promise<TunnelSession> {
  try {
    const res = await fetch(`${config.apiBase}/unified/v1/sessions`, {
      method: 'POST',
      credentials: 'include',
      headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
      body: JSON.stringify({
        connection_id: req.connectionId,
        target: req.target,
        protocol: req.protocol,
      }),
    })
    if (!res.ok) {
      throw new Error(`BFF sessions ${res.status}`)
    }
    const data = (await res.json()) as {
      tunnel_url: string
      connect_data: string
      expires_in?: number
      embed_url?: string
    }
    return {
      tunnelUrl: data.tunnel_url,
      connectData: data.connect_data,
      connectionId: req.connectionId,
      target: req.target,
      expiresInSec: data.expires_in,
      source: 'bff',
      embedUrl: data.embed_url,
    }
  } catch (e) {
    if (config.guac.demo) {
      // Local demo: no real guacd — GuacamoleDisplay will surface connection error
      const base = config.guac.tunnelWs || 'ws://127.0.0.1:4822/'
      return {
        tunnelUrl: base,
        connectData: `demo;target=${req.target}`,
        connectionId: req.connectionId,
        target: req.target,
        source: 'demo',
      }
    }
    throw e instanceof Error
      ? e
      : new Error('Falha ao obter token de sessão (BFF indisponível)')
  }
}
