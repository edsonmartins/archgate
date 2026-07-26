/** BFF helpers for embedded sessions (Bearer from CLI auth-header). */

import { runArchgate } from '../archgate'

export type AuthHeader = {
  mode: string
  api_base: string
  token: string
  authorization: string
  user?: string
}

export type TunnelSession = {
  tunnelUrl: string
  connectData: string
  embedUrl?: string
  embedMode?: 'websocket' | 'iframe'
  connectionId: string
  target: string
  expiresInSec?: number
  source: 'bff' | 'fallback'
}

export async function getAuthHeader(): Promise<AuthHeader> {
  const r = await runArchgate(['auth-header', '--json'])
  if (r.code !== 0) {
    throw new Error((r.stderr || r.stdout || 'auth-header failed').trim())
  }
  return JSON.parse(r.stdout) as AuthHeader
}

export async function requestTunnelSession(req: {
  connectionId: string
  target: string
  protocol: string
}): Promise<TunnelSession> {
  const auth = await getAuthHeader()
  const base = (auth.api_base || 'https://console.archgate.com.br/api').replace(/\/$/, '')
  const res = await fetch(`${base}/unified/v1/sessions`, {
    method: 'POST',
    headers: {
      Accept: 'application/json',
      'Content-Type': 'application/json',
      Authorization: auth.authorization,
    },
    body: JSON.stringify({
      connection_id: req.connectionId,
      target: req.target,
      protocol: req.protocol,
    }),
  })
  if (!res.ok) {
    const t = await res.text().catch(() => '')
    throw new Error(`BFF sessions ${res.status}: ${t.slice(0, 160)}`)
  }
  const data = (await res.json()) as {
    tunnel_url?: string
    connect_data?: string
    embed_url?: string
    embed_mode?: 'websocket' | 'iframe'
    expires_in?: number
    launch?: { engine?: string; target?: string; protocol?: string }
  }
  // Prefer websocket when BFF returned a real Guac token (token=…&GUAC_ID=…).
  const connectData = data.connect_data || ''
  const hasToken =
    connectData.includes('token=') &&
    (connectData.includes('GUAC_ID=') || connectData.includes('GUAC_DATA_SOURCE='))
  const embedMode =
    data.embed_mode ||
    (hasToken && data.tunnel_url ? 'websocket' : data.embed_url ? 'iframe' : undefined)
  return {
    tunnelUrl: data.tunnel_url || '',
    connectData,
    embedUrl: data.embed_url,
    embedMode,
    connectionId: req.connectionId,
    target: req.target,
    expiresInSec: data.expires_in,
    source: 'bff',
  }
}

export async function printOpenUrl(target: string): Promise<{
  url: string
  guac_base?: string
  protocol?: string
  engine?: string
}> {
  const r = await runArchgate(['print-open', target, '--json'])
  if (r.code !== 0) {
    throw new Error((r.stderr || r.stdout || 'print-open failed').trim())
  }
  return JSON.parse(r.stdout) as {
    url: string
    guac_base?: string
    protocol?: string
    engine?: string
  }
}
