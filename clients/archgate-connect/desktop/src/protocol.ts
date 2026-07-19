/** Single protocol policy for the desktop UI (badge, accent, action, CLI args). */

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
  /** CLI args to run for this connection (no program name). */
  cliArgs: (c: Connection) => string[]
}

const SSH: ProtocolMeta = {
  kind: 'ssh',
  badge: 'SSH',
  iconCls: 'ssh',
  protoCls: 'proto-ssh',
  actionLabel: 'SSH',
  actionBtn: 'btn-ssh',
  cliArgs: (c) => {
    if (c.engine === 'guacamole') return ['open', c.target]
    return ['ssh', c.target, '--terminal']
  },
}

const PG: ProtocolMeta = {
  kind: 'postgres',
  badge: 'PG',
  iconCls: 'postgres',
  protoCls: 'proto-postgres',
  actionLabel: 'DB',
  actionBtn: 'btn-db',
  cliArgs: (c) => ['db', c.target],
}

const MYSQL: ProtocolMeta = {
  kind: 'mysql',
  badge: 'SQL',
  iconCls: 'mysql',
  protoCls: 'proto-mysql',
  actionLabel: 'DB',
  actionBtn: 'btn-db',
  cliArgs: (c) => ['db', c.target],
}

const ORACLE: ProtocolMeta = {
  kind: 'oracle',
  badge: 'ORA',
  iconCls: 'oracle',
  protoCls: 'proto-oracle',
  actionLabel: 'Open',
  actionBtn: 'btn-open',
  cliArgs: (c) => ['open', c.target],
}

const HTTP: ProtocolMeta = {
  kind: 'http',
  badge: 'WEB',
  iconCls: 'http',
  protoCls: 'proto-http',
  actionLabel: 'Open',
  actionBtn: 'btn-open',
  cliArgs: (c) => ['open', c.target],
}

const OTHER: ProtocolMeta = {
  kind: 'other',
  badge: '?',
  iconCls: 'other',
  protoCls: 'proto-other',
  actionLabel: 'Open',
  actionBtn: 'btn-open',
  cliArgs: (c) => ['open', c.target],
}

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
