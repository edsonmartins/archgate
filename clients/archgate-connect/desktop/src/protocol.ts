/** Presentation metadata for connections. Routing is owned by CLI `archgate go`. */

export type Connection = {
  id: string
  name: string
  site: string
  tenant: string
  protocol: string
  engine: string
  target: string
  description?: string
}

export type ProtocolKind = 'ssh' | 'postgres' | 'mysql' | 'oracle' | 'http' | 'other'

export type ProtocolMeta = {
  kind: ProtocolKind
  badge: string
  iconCls: string
  protoCls: string
  actionLabel: string
  actionBtn: string
  /** Always dispatch via CLI go (catalog decides ssh/db/open). */
  cliArgs: (c: Connection) => string[]
}

function base(
  kind: ProtocolKind,
  badge: string,
  iconCls: string,
  protoCls: string,
  actionLabel: string,
  actionBtn: string,
): ProtocolMeta {
  return {
    kind,
    badge,
    iconCls,
    protoCls,
    actionLabel,
    actionBtn,
    // Desktop always wants terminal for SSH; go ignores --terminal for non-ssh.
    cliArgs: (c) => ['go', c.target, '--terminal', '--clipboard'],
  }
}

const SSH = base('ssh', 'SSH', 'ssh', 'proto-ssh', 'SSH', 'btn-ssh')
const PG = base('postgres', 'PG', 'postgres', 'proto-postgres', 'DB', 'btn-db')
const MYSQL = base('mysql', 'SQL', 'mysql', 'proto-mysql', 'DB', 'btn-db')
const ORACLE = base('oracle', 'ORA', 'oracle', 'proto-oracle', 'Open', 'btn-open')
const HTTP = base('http', 'WEB', 'http', 'proto-http', 'Open', 'btn-open')
const OTHER = base('other', '?', 'other', 'proto-other', 'Open', 'btn-open')

export function protocolMeta(protocol: string): ProtocolMeta {
  const p = (protocol || '').toLowerCase()
  if (p === 'ssh') return SSH
  if (p === 'postgres' || p === 'postgresql') return PG
  if (p === 'mysql') return MYSQL
  if (p === 'oracle') return ORACLE
  if (p === 'http' || p === 'https') return HTTP
  return {
    ...OTHER,
    badge: (p || '???').slice(0, 3).toUpperCase(),
  }
}
