/**
 * Bridge to the bundled archgate CLI via Tauri run_cli.
 * Identity/bastion are resolved only by the CLI — never hard-coded here.
 */

export type RunResult = {
  code: number
  stdout: string
  stderr: string
}

function isTauri(): boolean {
  const w = window as unknown as {
    __TAURI_INTERNALS__?: unknown
    __TAURI__?: unknown
  }
  return !!(w.__TAURI_INTERNALS__ || w.__TAURI__)
}

export async function runArchgate(args: string[]): Promise<RunResult> {
  if (!isTauri()) {
    return mockArchgate(args)
  }

  const { invoke } = await import('@tauri-apps/api/core')
  try {
    const r = await invoke<RunResult>('run_cli', { args })
    return {
      code: typeof r.code === 'number' ? r.code : 1,
      stdout: r.stdout ?? '',
      stderr: r.stderr ?? '',
    }
  } catch (e) {
    return { code: 1, stdout: '', stderr: String(e) }
  }
}

/** Dev-browser mock aligned with CLI mock catalog (no hard-coded WG identity beyond defaults the CLI would store on lab login). */
function mockArchgate(args: string[]): RunResult {
  const cmd = args[0]
  const json = args.includes('--json') || args.includes('-j')
  const target = args[1] || 'rio-lab-ssh'

  if (cmd === 'print-ssh') {
    const line = `ssh -p 2222 -o StrictHostKeyChecking=accept-new 'uat-op-a:${target}@217.196.60.108'`
    if (json) {
      return {
        code: 0,
        stdout:
          JSON.stringify(
            {
              command: line,
              host: '217.196.60.108',
              port: 2222,
              user: `uat-op-a:${target}`,
              target,
              operator: 'uat-op-a',
            },
            null,
            2,
          ) + '\n',
        stderr: '',
      }
    }
    return { code: 0, stdout: line + '\n', stderr: '' }
  }

  if (cmd === 'ssh') {
    const line = `ssh -p 2222 -o StrictHostKeyChecking=accept-new 'uat-op-a:${target}@217.196.60.108'`
    return {
      code: 0,
      stdout: `→ ${line}\nWarpgate password: use operator password for uat-op-a (not lab catalog nickname).\n`,
      stderr: '',
    }
  }

  if (cmd === 'login') {
    return {
      code: 0,
      stdout: 'Logged in (mock). Warpgate SSH user: uat-op-a\n',
      stderr: '',
    }
  }

  if (cmd === 'ls' && json) {
    return {
      code: 0,
      stdout:
        JSON.stringify({
          connections: [
            {
              id: 'lab:rio-lab-ssh',
              name: 'rio-lab-ssh',
              site: 'Rio Quality (lab)',
              tenant: 'tenant_rio_quality',
              protocol: 'ssh',
              engine: 'warpgate',
              target: 'rio-lab-ssh',
            },
            {
              id: 'lab:rio-lab-postgres',
              name: 'rio-lab-postgres',
              site: 'Rio Quality (lab)',
              tenant: 'tenant_rio_quality',
              protocol: 'postgres',
              engine: 'warpgate',
              target: 'rio-lab-postgres',
            },
            {
              id: 'lab:rio-aws-api-b',
              name: 'rio-aws-api-b',
              site: 'Rio Quality',
              tenant: 'tenant_rio_quality',
              protocol: 'ssh',
              engine: 'warpgate',
              target: 'rio-aws-api-b',
            },
          ],
        }) + '\n',
      stderr: '',
    }
  }

  if (cmd === 'status' && json) {
    return {
      code: 0,
      stdout:
        JSON.stringify({
          user: 'edson',
          warpgate_user: 'uat-op-a',
          session: true,
          auth: 'lab',
          connections: 3,
          bastion: { ssh_host: '217.196.60.108', ssh_port: 2222 },
        }) + '\n',
      stderr: '',
    }
  }

  if (cmd === 'db') {
    return {
      code: 0,
      stdout: `Postgres via Warpgate bastion\n  Username: uat-op-a:${target}\n`,
      stderr: '',
    }
  }

  if (cmd === 'open') {
    return { code: 0, stdout: `→ open https://console.archgate.com.br/sites\n`, stderr: '' }
  }

  if (cmd === 'logout') {
    return { code: 0, stdout: 'Logged out.\n', stderr: '' }
  }

  return { code: 0, stdout: `${cmd} ok\n`, stderr: '' }
}
