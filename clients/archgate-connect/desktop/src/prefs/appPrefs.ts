/** Desktop app preferences (not terminal themes). */

const KEY = 'archgate.connect.appPrefs.v1'

export type AppTheme = 'dark' | 'light'

export type AppPrefs = {
  version: 1
  /** Show lab login controls (homolog). Default false = SSO-first. */
  homologMode: boolean
  /** First-run wizard completed. */
  onboardingDone: boolean
  /** User dismissed the Warpgate password tip (global). */
  wgPasswordTipDismissed: boolean
  /** App chrome theme (V10). Terminal theme is separate. */
  theme: AppTheme
}

export function defaultAppPrefs(): AppPrefs {
  return {
    version: 1,
    homologMode: false,
    onboardingDone: false,
    wgPasswordTipDismissed: false,
    theme: 'dark',
  }
}

export function loadAppPrefs(): AppPrefs {
  try {
    const raw = localStorage.getItem(KEY)
    if (!raw) return defaultAppPrefs()
    const p = JSON.parse(raw) as Partial<AppPrefs>
    const theme: AppTheme = p.theme === 'light' ? 'light' : 'dark'
    return {
      ...defaultAppPrefs(),
      homologMode: !!p.homologMode,
      onboardingDone: !!p.onboardingDone,
      wgPasswordTipDismissed: !!p.wgPasswordTipDismissed,
      theme,
    }
  } catch {
    return defaultAppPrefs()
  }
}

export function saveAppPrefs(p: AppPrefs): void {
  try {
    localStorage.setItem(KEY, JSON.stringify(p))
  } catch {
    /* ignore */
  }
}

export function patchAppPrefs(patch: Partial<AppPrefs>): AppPrefs {
  const next = { ...loadAppPrefs(), ...patch, version: 1 as const }
  saveAppPrefs(next)
  return next
}
