import React from 'react'
import ReactDOM from 'react-dom/client'
import { App } from './App'
import { TerminalPrefsProvider } from './prefs/TerminalPrefsContext'
import './styles.css'

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <TerminalPrefsProvider>
      <App />
    </TerminalPrefsProvider>
  </React.StrictMode>,
)
