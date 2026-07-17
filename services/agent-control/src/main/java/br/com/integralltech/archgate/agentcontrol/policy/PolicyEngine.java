package br.com.integralltech.archgate.agentcontrol.policy;

import br.com.integralltech.archgate.agentcontrol.domain.Models.Decision;
import br.com.integralltech.archgate.agentcontrol.domain.Models.PolicyDecision;
import org.springframework.stereotype.Component;

@Component
public class PolicyEngine {

  private final PolicyLoader loader;

  public PolicyEngine(PolicyLoader loader) {
    this.loader = loader;
  }

  public PolicyDecision evaluate(
      String agentId,
      String action,
      String target,
      String incidentId,
      String command,
      boolean agentKilled
  ) {
    if (agentKilled) {
      return new PolicyDecision(Decision.DENY, "agent kill-switch active", false, action);
    }
    AgentPolicy p = loader.policy();
    if (p.requireIncidentId() && (incidentId == null || incidentId.isBlank())) {
      return new PolicyDecision(Decision.DENY, "incident_id required", false, action);
    }
    if (!p.isKnownAction(action)) {
      return new PolicyDecision(Decision.DENY, "action not in allow-list: " + action, false, action);
    }
    if (target != null && !target.isBlank() && !p.isTargetAllowed(target)) {
      return new PolicyDecision(Decision.DENY, "target not allowed: " + target, false, action);
    }
    if (p.isMutant(action)) {
      if (command != null && p.isCommandDenied(command)) {
        return new PolicyDecision(Decision.DENY, "command denied by denylist/allowlist", true, action);
      }
      return new PolicyDecision(Decision.PENDING_HITL, "mutant action requires human approval", true, action);
    }
    return new PolicyDecision(Decision.ALLOW, "read action auto-allowed", false, action);
  }
}
