/**
 * W4-UI07 — Deep link / copyable launch snippets for Warpgate desktop (SSH / Postgres).
 * Aligns with documentos/runbooks/snippets/* and ADR-008 (bastion-first, no target IPs).
 */

import { config } from '../config'
import type { Connection, Protocol } from '../types'

export type LaunchSnippet = {
  id: string
  label: string
  /** Text to copy / show */
  body: string
  /** Optional URI for OS handler (best-effort) */
  uri?: string
}

export type LaunchBundle = {
  protocol: Protocol
  target: string
  username: string
  snippets: LaunchSnippet[]
}

export function buildWarpgateLaunch(
  connection: Connection,
  username: string,
): LaunchBundle | null {
  if (connection.engine !== 'warpgate') return null
  const user = username || 'SEU_USUARIO'
  const target = connection.target
  const proxyUser = `${user}:${target}`

  if (connection.protocol === 'ssh') {
    const host = config.warpgate.sshHost
    const port = config.warpgate.sshPort
    const cmd = `ssh -p ${port} '${proxyUser}@${host}'`
    const sshConfig = [
      `Host archgate-${target}`,
      `  HostName ${host}`,
      `  Port ${port}`,
      `  User ${proxyUser}`,
      `  StrictHostKeyChecking accept-new`,
    ].join('\n')
    return {
      protocol: 'ssh',
      target,
      username: user,
      snippets: [
        {
          id: 'ssh-cli',
          label: 'OpenSSH (Linux / macOS / Windows)',
          body: cmd,
          uri: `ssh://${encodeURIComponent(proxyUser)}@${host}:${port}`,
        },
        {
          id: 'ssh-config',
          label: '~/.ssh/config',
          body: sshConfig,
        },
      ],
    }
  }

  if (connection.protocol === 'postgres') {
    const host = config.warpgate.pgHost
    const port = config.warpgate.pgPort
    const db = config.warpgate.pgDb
    const psql = `psql "host=${host} port=${port} user=${proxyUser} dbname=${db} sslmode=require"`
    const dbeaver = [
      `Host:     ${host}`,
      `Port:     ${port}`,
      `Database: ${db}`,
      `Username: ${proxyUser}`,
      `Password: <credencial do operador no Warpgate — não a do Postgres alvo>`,
      `SSL:      require`,
    ].join('\n')
    const jdbc = `jdbc:postgresql://${host}:${port}/${db}?sslmode=require`
    return {
      protocol: 'postgres',
      target,
      username: user,
      snippets: [
        { id: 'psql', label: 'psql', body: psql },
        { id: 'dbeaver', label: 'DBeaver / UI', body: dbeaver },
        { id: 'jdbc', label: 'JDBC URL', body: `${jdbc}\nuser: ${proxyUser}` },
      ],
    }
  }

  if (connection.protocol === 'http') {
    // Warpgate HTTPS proxy: public bastion URL + target name (no internal IP).
    const base = (config.warpgate.httpBase || `https://${config.warpgate.sshHost}`).replace(
      /\/$/,
      '',
    )
    const url = `${base}/?warpgate-target=${encodeURIComponent(target)}`
    const alt = `${base}/@warpgate#/login?target=${encodeURIComponent(target)}`
    return {
      protocol: 'http',
      target,
      username: user,
      snippets: [
        {
          id: 'http-browser',
          label: 'Browser (Warpgate HTTPS)',
          body: url,
          uri: url,
        },
        {
          id: 'http-login',
          label: 'Warpgate login + target',
          body: alt,
          uri: alt,
        },
        {
          id: 'http-note',
          label: 'Nota',
          body: `Target HTTP «${target}» via bastion. Autentique como ${user} no Warpgate (SSO). Sem IP interno.`,
        },
      ],
    }
  }

  // Other protocols via Warpgate: generic note
  return {
    protocol: connection.protocol,
    target,
    username: user,
    snippets: [
      {
        id: 'generic',
        label: 'Bastion',
        body: `Conecte via Warpgate target «${target}» como ${user} (sem IP de alvo).`,
      },
    ],
  }
}

/** Best-effort open OS handler; falls back to clipboard. */
export async function tryOpenUri(uri: string): Promise<'opened' | 'clipboard' | 'failed'> {
  try {
    // Custom protocol may be blocked; still attempt for ssh://
    window.location.href = uri
    return 'opened'
  } catch {
    try {
      await navigator.clipboard.writeText(uri)
      return 'clipboard'
    } catch {
      return 'failed'
    }
  }
}

export async function copyText(text: string): Promise<boolean> {
  try {
    await navigator.clipboard.writeText(text)
    return true
  } catch {
    return false
  }
}
