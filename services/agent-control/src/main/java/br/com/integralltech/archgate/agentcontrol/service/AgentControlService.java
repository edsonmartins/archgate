package br.com.integralltech.archgate.agentcontrol.service;

import br.com.integralltech.archgate.agentcontrol.domain.Models.ActionResult;
import br.com.integralltech.archgate.agentcontrol.domain.Models.ApprovalRequest;
import br.com.integralltech.archgate.agentcontrol.domain.Models.ApprovalState;
import br.com.integralltech.archgate.agentcontrol.domain.Models.Decision;
import br.com.integralltech.archgate.agentcontrol.domain.Models.PolicyDecision;
import br.com.integralltech.archgate.agentcontrol.domain.Models.SessionTicket;
import br.com.integralltech.archgate.agentcontrol.policy.PolicyEngine;
import br.com.integralltech.archgate.agentcontrol.policy.PolicyLoader;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

@Service
public class AgentControlService {

  private static final Logger log = LoggerFactory.getLogger(AgentControlService.class);

  private final PolicyEngine policyEngine;
  private final PolicyLoader policyLoader;
  private final RateLimiter rateLimiter;
  private final AuditLog auditLog;
  private final KillSwitchRegistry killSwitch;
  private final String orchestrationUrl;
  private final boolean allowCloudLlm;

  private final Map<String, ApprovalRequest> approvals = new ConcurrentHashMap<>();
  private final Map<String, SessionTicket> sessions = new ConcurrentHashMap<>();

  public AgentControlService(
      PolicyEngine policyEngine,
      PolicyLoader policyLoader,
      RateLimiter rateLimiter,
      AuditLog auditLog,
      KillSwitchRegistry killSwitch,
      @Value("${archgate.agent.orchestration-url:http://127.0.0.1:8090}") String orchestrationUrl,
      @Value("${archgate.agent.allow-cloud-llm:false}") boolean allowCloudLlm
  ) {
    this.policyEngine = policyEngine;
    this.policyLoader = policyLoader;
    this.rateLimiter = rateLimiter;
    this.auditLog = auditLog;
    this.killSwitch = killSwitch;
    this.orchestrationUrl = orchestrationUrl;
    this.allowCloudLlm = allowCloudLlm;
  }

  public SessionTicket requestSession(
      String agentId,
      String action,
      String target,
      String incidentId,
      String mode
  ) {
    guardRate(agentId);
    PolicyDecision d = policyEngine.evaluate(
        agentId, action, target, incidentId, null, killSwitch.isKilled(agentId)
    );
    String id = UUID.randomUUID().toString();
    List<String> trail = new ArrayList<>();
    trail.add("policy:" + d.decision() + ":" + d.reason());

    if (d.decision() == Decision.DENY) {
      auditLog.record("session.deny", agentId, null, incidentId, target, action, d.reason(), Map.of());
      return new SessionTicket(
          id, Instant.now(), agentId, target, incidentId, mode, "denied",
          policyLoader.policy().maxTtl(), trail
      );
    }
    if (d.decision() == Decision.PENDING_HITL) {
      ApprovalRequest ar = new ApprovalRequest(
          UUID.randomUUID().toString(), Instant.now(), agentId, action, target, null,
          incidentId, ApprovalState.PENDING, null, null
      );
      approvals.put(ar.id(), ar);
      trail.add("hitl:" + ar.id());
      auditLog.record("session.pending_hitl", agentId, null, incidentId, target, action, ar.id(), Map.of());
      return new SessionTicket(
          id, Instant.now(), agentId, target, incidentId, mode, "pending_hitl",
          policyLoader.policy().maxTtl(), trail
      );
    }

    // ALLOW — mock JIT ticket (live: call OpenBao)
    trail.add("jit:mock-lease");
    SessionTicket t = new SessionTicket(
        id, Instant.now(), agentId, target, incidentId,
        mode != null ? mode : "read",
        "issued",
        policyLoader.policy().maxTtl(),
        trail
    );
    sessions.put(id, t);
    auditLog.record(
        "session.issued", agentId, null, incidentId, target, action, id,
        Map.of("ttl", t.ttl(), "mode", t.mode())
    );
    return t;
  }

  public ActionResult submitAction(
      String agentId,
      String action,
      String target,
      String command,
      String incidentId
  ) {
    guardRate(agentId);
    PolicyDecision d = policyEngine.evaluate(
        agentId, action, target, incidentId, command, killSwitch.isKilled(agentId)
    );
    String corr = UUID.randomUUID().toString();

    if (d.decision() == Decision.DENY) {
      auditLog.record("action.deny", agentId, null, incidentId, target, action, d.reason(),
          Map.of("command", command != null ? command : ""));
      return new ActionResult(corr, Decision.DENY, d.reason(), null, corr);
    }
    if (d.decision() == Decision.PENDING_HITL) {
      ApprovalRequest ar = new ApprovalRequest(
          UUID.randomUUID().toString(), Instant.now(), agentId, action, target, command,
          incidentId, ApprovalState.PENDING, null, null
      );
      approvals.put(ar.id(), ar);
      auditLog.record("action.pending_hitl", agentId, null, incidentId, target, action, ar.id(),
          Map.of("command", command != null ? command : ""));
      return new ActionResult(corr, Decision.PENDING_HITL, d.reason(), ar.id(), corr);
    }

    auditLog.record("action.allow", agentId, null, incidentId, target, action, "auto",
        Map.of("command", command != null ? command : ""));
    return new ActionResult(corr, Decision.ALLOW, "executed (mock)", null, corr);
  }

  public ApprovalRequest approve(String approvalId, String approver, String reason) {
    ApprovalRequest ar = requirePending(approvalId);
    ApprovalRequest done = ar.withState(ApprovalState.APPROVED, approver, reason);
    approvals.put(approvalId, done);
    auditLog.record(
        "hitl.approved", ar.agentId(), approver, ar.incidentId(), ar.target(), ar.action(),
        reason, Map.of("approval_id", approvalId, "command", ar.command() != null ? ar.command() : "")
    );
    return done;
  }

  public ApprovalRequest deny(String approvalId, String approver, String reason) {
    ApprovalRequest ar = requirePending(approvalId);
    ApprovalRequest done = ar.withState(ApprovalState.DENIED, approver, reason);
    approvals.put(approvalId, done);
    auditLog.record(
        "hitl.denied", ar.agentId(), approver, ar.incidentId(), ar.target(), ar.action(),
        reason, Map.of("approval_id", approvalId)
    );
    return done;
  }

  public Map<String, Object> killSwitch(String agentId, String reason, String actor) {
    killSwitch.kill(agentId, reason, actor);
    auditLog.record("kill_switch", agentId, actor, null, null, "kill", reason, Map.of());

    // Best-effort notify orchestration revoke (live offboarding of SA)
    String orchStatus = "skipped";
    try {
      RestClient.create(orchestrationUrl)
          .post()
          .uri("/orchestration/v1/users/revoke")
          .body(Map.of("username", agentId, "reason", "kill-switch:" + reason))
          .retrieve()
          .toBodilessEntity();
      orchStatus = "revoked";
    } catch (Exception e) {
      orchStatus = "orch_unreachable:" + e.getMessage();
      log.warn("kill-switch orchestration revoke failed: {}", e.getMessage());
    }

    return Map.of(
        "agent_id", agentId,
        "killed", true,
        "reason", reason != null ? reason : "",
        "actor", actor != null ? actor : "",
        "orchestration", orchStatus
    );
  }

  public Optional<ApprovalRequest> getApproval(String id) {
    return Optional.ofNullable(approvals.get(id));
  }

  public boolean isCloudLlmAllowed() {
    return allowCloudLlm;
  }

  private ApprovalRequest requirePending(String id) {
    ApprovalRequest ar = approvals.get(id);
    if (ar == null) {
      throw new IllegalArgumentException("approval not found: " + id);
    }
    if (ar.state() != ApprovalState.PENDING) {
      throw new IllegalStateException("approval not pending: " + ar.state());
    }
    return ar;
  }

  private void guardRate(String agentId) {
    if (!rateLimiter.tryAcquire(agentId)) {
      throw new IllegalStateException("rate limit exceeded for " + agentId);
    }
  }
}
