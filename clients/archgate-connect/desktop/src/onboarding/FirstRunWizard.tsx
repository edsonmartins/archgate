import { IconGate, IconPlug, IconShield } from '../icons'

type Props = {
  sessionOn: boolean
  connCount: number
  doctorOk: boolean | null
  busy: boolean
  onSso: () => void
  onDoctor: () => void
  onSkip: () => void
  onFinish: () => void
}

/**
 * V8 — first-run: SSO → doctor → open a connection.
 */
export function FirstRunWizard({
  sessionOn,
  connCount,
  doctorOk,
  busy,
  onSso,
  onDoctor,
  onSkip,
  onFinish,
}: Props) {
  const step = !sessionOn ? 1 : doctorOk !== true ? 2 : 3

  return (
    <div className="onboard-overlay" role="dialog" aria-modal="true" aria-labelledby="onboard-title">
      <div className="onboard-card">
        <div className="onboard-brand">
          <div className="brand-mark" aria-hidden>
            <IconGate />
          </div>
          <div>
            <h2 id="onboard-title">Bem-vindo ao ArchGate Connect</h2>
            <p className="onboard-sub">
              Acesso privilegiado via bastion — sem VPN do cliente no notebook.
            </p>
          </div>
        </div>

        <ol className="onboard-steps">
          <li className={step === 1 ? 'active' : sessionOn ? 'done' : ''}>
            <span className="onboard-n">1</span>
            <div>
              <strong>Entrar com SSO</strong>
              <p>ArchGuard no browser (identidade corporativa).</p>
            </div>
          </li>
          <li className={step === 2 ? 'active' : doctorOk === true ? 'done' : ''}>
            <span className="onboard-n">2</span>
            <div>
              <strong>Verificar bastion</strong>
              <p>Doctor confere TCP SSH/Postgres e catálogo.</p>
            </div>
          </li>
          <li className={step === 3 ? 'active' : ''}>
            <span className="onboard-n">3</span>
            <div>
              <strong>Primeira conexão</strong>
              <p>Abra um target SSH/DB — sessão embutida no app.</p>
            </div>
          </li>
        </ol>

        <div className="onboard-actions">
          {step === 1 ? (
            <button type="button" className="btn btn-primary" disabled={busy} onClick={onSso}>
              {busy ? 'Aguardando SSO…' : 'Login SSO (ArchGuard)'}
            </button>
          ) : null}
          {step === 2 ? (
            <button type="button" className="btn btn-primary" disabled={busy} onClick={onDoctor}>
              {busy ? 'Verificando…' : doctorOk === false ? 'Doctor falhou — tentar de novo' : 'Rodar doctor'}
            </button>
          ) : null}
          {step === 3 ? (
            <button
              type="button"
              className="btn btn-primary"
              onClick={onFinish}
              disabled={connCount === 0}
            >
              {connCount > 0
                ? `Pronto — ${connCount} conexões no catálogo`
                : 'Catálogo vazio — atualize após o login'}
            </button>
          ) : null}
          <button type="button" className="btn btn-ghost btn-sm" onClick={onSkip}>
            Pular introdução
          </button>
        </div>

        <div className="onboard-tips">
          <div className="onboard-tip">
            <IconShield />
            <span>Forti/OpenVPN do cliente ficam no VPS ArchGate.</span>
          </div>
          <div className="onboard-tip">
            <IconPlug />
            <span>SSH/DB pedem a senha do operador no Warpgate (não a do host).</span>
          </div>
        </div>
      </div>
    </div>
  )
}
