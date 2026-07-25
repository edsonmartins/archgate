type Props = {
  kind: 'ssh' | 'db'
  warpgateUser: string
  onDismiss: () => void
}

/** V12 — tip overlay: Warpgate operator password, not target OS password. */
export function WgPasswordTip({ kind, warpgateUser, onDismiss }: Props) {
  return (
    <div className="wg-tip" role="status">
      <div className="wg-tip-body">
        <strong>Senha do Warpgate</strong>
        <p>
          No prompt do {kind === 'ssh' ? 'SSH' : 'psql'}, use a senha do operador{' '}
          <code>{warpgateUser || '…'}</code> no bastion ArchGate —{' '}
          <em>não</em> a senha do Linux/Postgres do cliente.
        </p>
      </div>
      <button type="button" className="btn btn-sm btn-primary" onClick={onDismiss}>
        Entendi
      </button>
    </div>
  )
}
