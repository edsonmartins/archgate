export type Protocol = 'ssh' | 'postgres' | 'rdp' | 'http'

export type Connection = {
  id: string
  name: string
  site: string
  tenant: string
  protocol: Protocol
  engine: 'warpgate' | 'guacamole'
  /** Launch target name on bastion (never internal host IP for operators). */
  target: string
  description?: string
}

export type SessionState = 'idle' | 'connecting' | 'connected' | 'error' | 'disconnected'
