/**
 * F5 scaffold — version channel check (no silent auto-update until notarized).
 * Manifest lives in-repo; override with VITE_CONNECT_VERSION_URL.
 */

export const APP_VERSION = '0.2.0'

const DEFAULT_MANIFEST_URL =
  'https://raw.githubusercontent.com/edsonmartins/archgate/main/clients/archgate-connect/version-manifest.json'

export type VersionManifest = {
  schema?: number
  product?: string
  channel?: string
  latest?: {
    version?: string
    notes?: string
    released_at?: string
    macos?: { signed?: boolean; notarized?: boolean; dmg?: string | null }
  }
  download_page?: string
  notes?: string
}

export type UpdateCheckResult = {
  current: string
  latest: string
  updateAvailable: boolean
  signed: boolean
  notarized: boolean
  notes?: string
  downloadPage?: string
  channelNotes?: string
  source: string
  error?: string
}

function parseSemver(v: string): number[] {
  const core = v.replace(/^v/, '').split('-')[0]
  return core.split('.').map((x) => {
    const n = Number(x)
    return Number.isFinite(n) ? n : 0
  })
}

/** true if remote is newer than local */
export function isNewerVersion(remote: string, local: string): boolean {
  const a = parseSemver(remote)
  const b = parseSemver(local)
  const len = Math.max(a.length, b.length)
  for (let i = 0; i < len; i++) {
    const x = a[i] ?? 0
    const y = b[i] ?? 0
    if (x > y) return true
    if (x < y) return false
  }
  return false
}

export async function checkForUpdate(
  current = APP_VERSION,
): Promise<UpdateCheckResult> {
  const url =
    (import.meta as { env?: { VITE_CONNECT_VERSION_URL?: string } }).env
      ?.VITE_CONNECT_VERSION_URL || DEFAULT_MANIFEST_URL
  try {
    const res = await fetch(url, {
      headers: { Accept: 'application/json' },
      cache: 'no-store',
    })
    if (!res.ok) {
      return {
        current,
        latest: current,
        updateAvailable: false,
        signed: false,
        notarized: false,
        source: url,
        error: `manifest HTTP ${res.status}`,
      }
    }
    const m = (await res.json()) as VersionManifest
    const latest = m.latest?.version || current
    return {
      current,
      latest,
      updateAvailable: isNewerVersion(latest, current),
      signed: !!m.latest?.macos?.signed,
      notarized: !!m.latest?.macos?.notarized,
      notes: m.latest?.notes,
      downloadPage: m.download_page,
      channelNotes: m.notes,
      source: url,
    }
  } catch (e) {
    return {
      current,
      latest: current,
      updateAvailable: false,
      signed: false,
      notarized: false,
      source: url,
      error: e instanceof Error ? e.message : String(e),
    }
  }
}
