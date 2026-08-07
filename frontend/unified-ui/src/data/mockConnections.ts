import type { Connection } from '../types'

// Development-only catalog used when the local BFF is unavailable. Production
// authorization never derives from this list; the BFF remains authoritative.
export const MOCK_CONNECTIONS: Connection[] = [
  {
    id: 'lab:rio-lab-ssh',
    name: 'rio-lab-ssh',
    site: 'Rio Quality (lab)',
    tenant: 'tenant_rio_quality',
    protocol: 'ssh',
    engine: 'warpgate',
    target: 'rio-lab-ssh',
    description: 'Mock lab SSH',
  },
  {
    id: 'lab:rio-lab-postgres',
    name: 'rio-lab-postgres',
    site: 'Rio Quality (lab)',
    tenant: 'tenant_rio_quality',
    protocol: 'postgres',
    engine: 'warpgate',
    target: 'rio-lab-postgres',
    description: 'Mock lab PostgreSQL',
  },
  {
    id: 'lab:lab-ssh-browser',
    name: 'lab-ssh-browser',
    site: 'Lab',
    tenant: 'tenant_rio_quality',
    protocol: 'ssh',
    engine: 'guacamole',
    target: 'lab-ssh-browser',
    description: 'Mock browser SSH',
  },
]
