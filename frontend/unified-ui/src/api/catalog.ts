/**
 * Catalog API client — BFF filtered by RBAC (W4-UI03).
 * Falls back to lab mock when BFF is unreachable (dev without API).
 */

import { config } from '../config'
import { MOCK_CONNECTIONS } from '../data/mockConnections'
import type { Connection } from '../types'
import type { UserSession } from '../auth/session'

export type CatalogResult = {
  connections: Connection[]
  source: 'bff' | 'mock'
}

export async function fetchMyConnections(session: UserSession): Promise<CatalogResult> {
  try {
    const res = await fetch(`${config.apiBase}/unified/v1/connections`, {
      credentials: 'include',
      headers: {
        Accept: 'application/json',
        // Lab: identity hint only — real auth = session cookie / Bearer from BFF
        'X-ArchGate-User': session.username ?? session.email,
        'X-ArchGate-Tenants': session.tenants.join(','),
      },
    })
    if (!res.ok) throw new Error(`catalog ${res.status}`)
    const data = (await res.json()) as { connections?: Connection[] } | Connection[]
    const list = Array.isArray(data) ? data : (data.connections ?? [])
    return { connections: list.map(normalizeConnection), source: 'bff' }
  } catch {
    const filtered = MOCK_CONNECTIONS.filter((c) => session.tenants.includes(c.tenant))
    return { connections: filtered, source: 'mock' }
  }
}

function normalizeConnection(raw: Connection): Connection {
  return {
    id: String(raw.id),
    name: raw.name,
    site: raw.site,
    tenant: raw.tenant,
    protocol: raw.protocol,
    engine: raw.engine,
    target: raw.target,
    description: raw.description,
  }
}
