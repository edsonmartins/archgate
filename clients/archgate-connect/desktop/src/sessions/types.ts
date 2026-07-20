import type { Connection } from '../protocol'

export type SessionKind = 'ssh' | 'guac' | 'db' | 'web'

export type SessionState =
  | 'idle'
  | 'placeholder' // non-SSH kinds until Guac/DB embed
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
      return 'RDP/Guac'
    case 'db':
      return 'DB'
    case 'web':
      return 'Web'
  }
}

export function newSessionTab(c: Connection): SessionTab {
  const kind = sessionKindFor(c)
  return {
    id: `${c.target}-${Date.now()}`,
    connection: c,
    kind,
    state: kind === 'ssh' ? 'connecting' : 'placeholder',
    note:
      kind === 'ssh'
        ? 'Abrindo terminal SSH embutido via Warpgate…'
        : kind === 'guac'
          ? 'Sessão embutida Guac/RDP (S2b) — use “Externo” para o browser por enquanto.'
          : kind === 'db'
            ? 'DB embutido depois — use “Externo” para copiar/abrir psql.'
            : 'Abra no browser interno/externo (Oracle/HTTP).',
    createdAt: Date.now(),
  }
}
