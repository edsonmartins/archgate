import { useEffect, useRef } from 'react'
import type { Terminal } from '@xterm/xterm'
import type { TerminalAppearance } from './terminalPrefs'
import { toXtermTheme } from './terminalPrefs'
import { useTerminalPrefs } from './TerminalPrefsContext'

/** Subscribe to resolved appearance for a target (or global). */
export function useTerminalAppearance(target?: string | null): TerminalAppearance {
  const { appearanceFor, store } = useTerminalPrefs()
  // re-render when store changes
  void store
  return appearanceFor(target)
}

/** Apply appearance to a live xterm instance when prefs change. */
export function useApplyTerminalOptions(
  termRef: React.RefObject<Terminal | null>,
  appearance: TerminalAppearance,
  fit?: () => void,
): void {
  const prev = useRef<string>('')
  useEffect(() => {
    const term = termRef.current
    if (!term) return
    const sig = JSON.stringify(appearance)
    if (sig === prev.current) return
    prev.current = sig
    term.options.fontFamily = appearance.fontFamily
    term.options.fontSize = appearance.fontSize
    term.options.lineHeight = appearance.lineHeight
    term.options.cursorBlink = appearance.cursorBlink
    term.options.cursorStyle = appearance.cursorStyle
    term.options.theme = toXtermTheme(appearance)
    try {
      fit?.()
    } catch {
      /* ignore */
    }
  }, [appearance, termRef, fit])
}
