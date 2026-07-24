/** Terminal appearance: global defaults + optional per-target overrides. */

export type CursorStyle = 'block' | 'underline' | 'bar'

export type TerminalThemeColors = {
  background: string
  foreground: string
  cursor: string
  selectionBackground: string
  black: string
  red: string
  green: string
  yellow: string
  blue: string
  magenta: string
  cyan: string
  white: string
  brightBlack: string
  brightRed: string
  brightGreen: string
  brightYellow: string
  brightBlue: string
  brightMagenta: string
  brightCyan: string
  brightWhite: string
}

export type TerminalAppearance = {
  fontFamily: string
  fontSize: number
  lineHeight: number
  cursorBlink: boolean
  cursorStyle: CursorStyle
  /** Named palette; when not custom, theme is replaced from preset. */
  themePreset: string
  theme: TerminalThemeColors
}

export type TerminalPrefsStore = {
  version: 1
  global: TerminalAppearance
  /** Keyed by connection target name */
  byTarget: Record<string, Partial<TerminalAppearance>>
}

const STORAGE_KEY = 'archgate.connect.terminalPrefs.v1'

export const FONT_OPTIONS = [
  { id: 'jetbrains', label: 'JetBrains Mono', value: "'JetBrains Mono', ui-monospace, Menlo, monospace" },
  { id: 'sf-mono', label: 'SF Mono / Menlo', value: "ui-monospace, 'SF Mono', Menlo, Monaco, monospace" },
  { id: 'fira', label: 'Fira Code', value: "'Fira Code', 'JetBrains Mono', monospace" },
  { id: 'cascadia', label: 'Cascadia Code', value: "'Cascadia Code', 'Segoe UI Mono', monospace" },
  { id: 'source-code', label: 'Source Code Pro', value: "'Source Code Pro', Menlo, monospace" },
  { id: 'system', label: 'System mono', value: 'ui-monospace, SFMono-Regular, Menlo, Consolas, monospace' },
] as const

export const THEME_PRESETS: Record<string, { label: string; theme: TerminalThemeColors }> = {
  archgate: {
    label: 'ArchGate (default)',
    theme: {
      background: '#05080f',
      foreground: '#e2e8f0',
      cursor: '#38bdf8',
      selectionBackground: 'rgba(56, 189, 248, 0.28)',
      black: '#0f172a',
      red: '#fb7185',
      green: '#34d399',
      yellow: '#fbbf24',
      blue: '#38bdf8',
      magenta: '#a78bfa',
      cyan: '#22d3ee',
      white: '#e2e8f0',
      brightBlack: '#64748b',
      brightRed: '#fda4af',
      brightGreen: '#6ee7b7',
      brightYellow: '#fde68a',
      brightBlue: '#7dd3fc',
      brightMagenta: '#c4b5fd',
      brightCyan: '#67e8f9',
      brightWhite: '#f8fafc',
    },
  },
  dracula: {
    label: 'Dracula',
    theme: {
      background: '#282a36',
      foreground: '#f8f8f2',
      cursor: '#f8f8f2',
      selectionBackground: 'rgba(68, 71, 90, 0.9)',
      black: '#21222c',
      red: '#ff5555',
      green: '#50fa7b',
      yellow: '#f1fa8c',
      blue: '#bd93f9',
      magenta: '#ff79c6',
      cyan: '#8be9fd',
      white: '#f8f8f2',
      brightBlack: '#6272a4',
      brightRed: '#ff6e6e',
      brightGreen: '#69ff94',
      brightYellow: '#ffffa5',
      brightBlue: '#d6acff',
      brightMagenta: '#ff92df',
      brightCyan: '#a4ffff',
      brightWhite: '#ffffff',
    },
  },
  'solarized-dark': {
    label: 'Solarized Dark',
    theme: {
      background: '#002b36',
      foreground: '#839496',
      cursor: '#93a1a1',
      selectionBackground: 'rgba(7, 54, 66, 0.9)',
      black: '#073642',
      red: '#dc322f',
      green: '#859900',
      yellow: '#b58900',
      blue: '#268bd2',
      magenta: '#d33682',
      cyan: '#2aa198',
      white: '#eee8d5',
      brightBlack: '#002b36',
      brightRed: '#cb4b16',
      brightGreen: '#586e75',
      brightYellow: '#657b83',
      brightBlue: '#839496',
      brightMagenta: '#6c71c4',
      brightCyan: '#93a1a1',
      brightWhite: '#fdf6e3',
    },
  },
  monokai: {
    label: 'Monokai',
    theme: {
      background: '#272822',
      foreground: '#f8f8f2',
      cursor: '#f8f8f0',
      selectionBackground: 'rgba(73, 72, 62, 0.9)',
      black: '#272822',
      red: '#f92672',
      green: '#a6e22e',
      yellow: '#f4bf75',
      blue: '#66d9ef',
      magenta: '#ae81ff',
      cyan: '#a1efe4',
      white: '#f8f8f2',
      brightBlack: '#75715e',
      brightRed: '#f92672',
      brightGreen: '#a6e22e',
      brightYellow: '#f4bf75',
      brightBlue: '#66d9ef',
      brightMagenta: '#ae81ff',
      brightCyan: '#a1efe4',
      brightWhite: '#f9f8f5',
    },
  },
  nord: {
    label: 'Nord',
    theme: {
      background: '#2e3440',
      foreground: '#d8dee9',
      cursor: '#d8dee9',
      selectionBackground: 'rgba(67, 76, 94, 0.9)',
      black: '#3b4252',
      red: '#bf616a',
      green: '#a3be8c',
      yellow: '#ebcb8b',
      blue: '#81a1c1',
      magenta: '#b48ead',
      cyan: '#88c0d0',
      white: '#e5e9f0',
      brightBlack: '#4c566a',
      brightRed: '#bf616a',
      brightGreen: '#a3be8c',
      brightYellow: '#ebcb8b',
      brightBlue: '#81a1c1',
      brightMagenta: '#b48ead',
      brightCyan: '#8fbcbb',
      brightWhite: '#eceff4',
    },
  },
  light: {
    label: 'Light',
    theme: {
      background: '#f8fafc',
      foreground: '#0f172a',
      cursor: '#0284c7',
      selectionBackground: 'rgba(14, 165, 233, 0.25)',
      black: '#0f172a',
      red: '#dc2626',
      green: '#16a34a',
      yellow: '#ca8a04',
      blue: '#2563eb',
      magenta: '#9333ea',
      cyan: '#0891b2',
      white: '#f1f5f9',
      brightBlack: '#64748b',
      brightRed: '#ef4444',
      brightGreen: '#22c55e',
      brightYellow: '#eab308',
      brightBlue: '#3b82f6',
      brightMagenta: '#a855f7',
      brightCyan: '#06b6d4',
      brightWhite: '#ffffff',
    },
  },
}

export function defaultAppearance(): TerminalAppearance {
  return {
    fontFamily: FONT_OPTIONS[0].value,
    fontSize: 13,
    lineHeight: 1.2,
    cursorBlink: true,
    cursorStyle: 'block',
    themePreset: 'archgate',
    theme: { ...THEME_PRESETS.archgate.theme },
  }
}

export function defaultStore(): TerminalPrefsStore {
  return { version: 1, global: defaultAppearance(), byTarget: {} }
}

function clamp(n: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, n))
}

function sanitizeAppearance(raw: Partial<TerminalAppearance> | undefined): Partial<TerminalAppearance> {
  if (!raw || typeof raw !== 'object') return {}
  const out: Partial<TerminalAppearance> = {}
  if (typeof raw.fontFamily === 'string' && raw.fontFamily.trim()) {
    out.fontFamily = raw.fontFamily.trim().slice(0, 200)
  }
  if (typeof raw.fontSize === 'number' && Number.isFinite(raw.fontSize)) {
    out.fontSize = clamp(Math.round(raw.fontSize), 9, 28)
  }
  if (typeof raw.lineHeight === 'number' && Number.isFinite(raw.lineHeight)) {
    out.lineHeight = clamp(raw.lineHeight, 1, 2)
  }
  if (typeof raw.cursorBlink === 'boolean') out.cursorBlink = raw.cursorBlink
  if (raw.cursorStyle === 'block' || raw.cursorStyle === 'underline' || raw.cursorStyle === 'bar') {
    out.cursorStyle = raw.cursorStyle
  }
  if (typeof raw.themePreset === 'string') {
    out.themePreset = raw.themePreset.slice(0, 64)
  }
  if (raw.theme && typeof raw.theme === 'object') {
    const t = { ...defaultAppearance().theme }
    for (const k of Object.keys(t) as (keyof TerminalThemeColors)[]) {
      const v = raw.theme[k]
      if (typeof v === 'string' && v.trim()) t[k] = v.trim().slice(0, 64)
    }
    out.theme = t
  }
  return out
}

export function loadPrefs(): TerminalPrefsStore {
  try {
    const raw = localStorage.getItem(STORAGE_KEY)
    if (!raw) return defaultStore()
    const parsed = JSON.parse(raw) as Partial<TerminalPrefsStore>
    const base = defaultStore()
    const global = {
      ...base.global,
      ...sanitizeAppearance(parsed.global),
    }
    // Apply preset colors if not custom
    if (global.themePreset && global.themePreset !== 'custom' && THEME_PRESETS[global.themePreset]) {
      global.theme = { ...THEME_PRESETS[global.themePreset].theme }
    }
    const byTarget: Record<string, Partial<TerminalAppearance>> = {}
    if (parsed.byTarget && typeof parsed.byTarget === 'object') {
      for (const [k, v] of Object.entries(parsed.byTarget)) {
        if (!k || k.length > 128) continue
        byTarget[k] = sanitizeAppearance(v)
      }
    }
    return { version: 1, global, byTarget }
  } catch {
    return defaultStore()
  }
}

export function savePrefs(store: TerminalPrefsStore): void {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(store))
  } catch {
    /* quota / private mode */
  }
}

/** Merge global + optional per-target overrides (resolved for a connection). */
export function resolveAppearance(
  store: TerminalPrefsStore,
  target?: string | null,
): TerminalAppearance {
  const g = store.global
  const o = target ? store.byTarget[target] : undefined
  if (!o || Object.keys(o).length === 0) {
    let theme = g.theme
    if (g.themePreset !== 'custom' && THEME_PRESETS[g.themePreset]) {
      theme = THEME_PRESETS[g.themePreset].theme
    }
    return { ...g, theme: { ...theme } }
  }
  const merged: TerminalAppearance = {
    fontFamily: o.fontFamily ?? g.fontFamily,
    fontSize: o.fontSize ?? g.fontSize,
    lineHeight: o.lineHeight ?? g.lineHeight,
    cursorBlink: o.cursorBlink ?? g.cursorBlink,
    cursorStyle: o.cursorStyle ?? g.cursorStyle,
    themePreset: o.themePreset ?? g.themePreset,
    theme: { ...g.theme, ...(o.theme || {}) },
  }
  if (merged.themePreset !== 'custom' && THEME_PRESETS[merged.themePreset]) {
    merged.theme = { ...THEME_PRESETS[merged.themePreset].theme }
  }
  return merged
}

export function hasTargetOverride(store: TerminalPrefsStore, target: string): boolean {
  const o = store.byTarget[target]
  return !!(o && Object.keys(o).length > 0)
}

export function clearTargetOverride(
  store: TerminalPrefsStore,
  target: string,
): TerminalPrefsStore {
  const byTarget = { ...store.byTarget }
  delete byTarget[target]
  return { ...store, byTarget }
}

export function setTargetOverride(
  store: TerminalPrefsStore,
  target: string,
  patch: Partial<TerminalAppearance>,
): TerminalPrefsStore {
  const prev = store.byTarget[target] || {}
  const next = sanitizeAppearance({ ...prev, ...patch })
  // Drop empty
  if (Object.keys(next).length === 0) {
    return clearTargetOverride(store, target)
  }
  return {
    ...store,
    byTarget: { ...store.byTarget, [target]: next },
  }
}

export function setGlobal(
  store: TerminalPrefsStore,
  patch: Partial<TerminalAppearance>,
): TerminalPrefsStore {
  const global = { ...store.global, ...sanitizeAppearance(patch) }
  if (patch.themePreset && patch.themePreset !== 'custom' && THEME_PRESETS[patch.themePreset]) {
    global.themePreset = patch.themePreset
    global.theme = { ...THEME_PRESETS[patch.themePreset].theme }
  }
  if (patch.theme && (!patch.themePreset || patch.themePreset === 'custom')) {
    global.themePreset = 'custom'
    global.theme = { ...global.theme, ...sanitizeAppearance({ theme: patch.theme }).theme! }
  }
  return { ...store, global }
}

/** xterm ITheme-compatible object */
export function toXtermTheme(a: TerminalAppearance): TerminalThemeColors {
  return { ...a.theme }
}
