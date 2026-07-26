import type { Connection } from '../protocol'

export type SessionKind = 'ssh' | 'guac' | 'db' | 'web'

export type SessionState =
  | 'idle'
  | 'connecting'
  | 'connected'
  | 'error'
  | 'closed'
  | 'external'

export type SessionTab = {
  id: string
  connection: Connection
  kind: SessionKind
  state: SessionState
  note: string
  createdAt: number
}

export function sessionKindFor(c: Connection): SessionKind {
  const p = (c.protocol || '').toLowerCase()
  const e = (c.engine || '').toLowerCase()
  const t = (c.target || '').toLowerCase()
  if (e === 'guacamole' || p === 'rdp' || p === 'vnc') return 'guac'
  if (p === 'postgres' || p === 'postgresql' || p === 'mysql') return 'db'
  if (p === 'http' || p === 'https' || p === 'oracle' || t.includes('oracle')) return 'web'
  return 'ssh'
}

export function kindLabel(k: SessionKind): string {
  switch (k) {
    case 'ssh':
      return 'SSH'
    case 'guac':
      return 'RDP/VNC'
    case 'db':
      return 'DB'
    case 'web':
      return 'Web'
  }
}

export function newSessionTab(c: Connection): SessionTab {
  const kind = sessionKindFor(c)
  const note =
    kind === 'ssh'
      ? 'Terminal SSH embutido (Warpgate)…'
      : kind === 'guac'
        ? 'Display RDP/VNC embutido (Guacamole)…'
        : kind === 'db'
          ? 'Terminal DB embutido (psql/mysql via Warpgate)…'
          : 'Painel web embutido…'
  return {
    id: `${c.target}-${Date.now()}`,
    connection: c,
    kind,
    state: 'connecting',
    note,
    createdAt: Date.now(),
  }
}
