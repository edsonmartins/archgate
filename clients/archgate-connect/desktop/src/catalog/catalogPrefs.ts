/** Favorites, pins, recents for connection catalog (Onda 2). */

const KEY = 'archgate.connect.catalogPrefs.v1'
const MAX_RECENTS = 12

export type CatalogPrefs = {
  version: 1
  favorites: string[]
  pins: string[]
  recents: string[]
}

export function defaultCatalogPrefs(): CatalogPrefs {
  return { version: 1, favorites: [], pins: [], recents: [] }
}

export function loadCatalogPrefs(): CatalogPrefs {
  try {
    const raw = localStorage.getItem(KEY)
    if (!raw) return defaultCatalogPrefs()
    const p = JSON.parse(raw) as Partial<CatalogPrefs>
    return {
      version: 1,
      favorites: Array.isArray(p.favorites) ? p.favorites.map(String) : [],
      pins: Array.isArray(p.pins) ? p.pins.map(String) : [],
      recents: Array.isArray(p.recents) ? p.recents.map(String) : [],
    }
  } catch {
    return defaultCatalogPrefs()
  }
}

export function saveCatalogPrefs(p: CatalogPrefs): void {
  try {
    localStorage.setItem(KEY, JSON.stringify(p))
  } catch {
    /* ignore */
  }
}

function uniq(xs: string[]): string[] {
  const seen = new Set<string>()
  const out: string[] = []
  for (const x of xs) {
    if (!x || seen.has(x)) continue
    seen.add(x)
    out.push(x)
  }
  return out
}

export function toggleFavorite(p: CatalogPrefs, target: string): CatalogPrefs {
  const has = p.favorites.includes(target)
  const favorites = has
    ? p.favorites.filter((t) => t !== target)
    : uniq([target, ...p.favorites])
  const next = { ...p, favorites }
  saveCatalogPrefs(next)
  return next
}

export function togglePin(p: CatalogPrefs, target: string): CatalogPrefs {
  const has = p.pins.includes(target)
  const pins = has ? p.pins.filter((t) => t !== target) : uniq([target, ...p.pins])
  const next = { ...p, pins }
  saveCatalogPrefs(next)
  return next
}

export function pushRecent(p: CatalogPrefs, target: string): CatalogPrefs {
  const recents = uniq([target, ...p.recents]).slice(0, MAX_RECENTS)
  const next = { ...p, recents }
  saveCatalogPrefs(next)
  return next
}

export function isPendingApply(description?: string): boolean {
  return (description || '').toLowerCase().includes('pending apply')
}
