package br.com.integralltech.archgate.agentcontrol.domain;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

public final class Models {
  private Models() {}

  public enum Decision {
    ALLOW,
    DENY,
    PENDING_HITL
  }

  public enum ApprovalState {
    PENDING,
    APPROVED,
    DENIED,
    EXPIRED
  }

  public record PolicyDecision(
      Decision decision,
      String reason,
      boolean mutant,
      String actionId
  ) {}

  public record AuditEvent(
      String id,
      Instant at,
      String type,
      String agentId,
      String humanApprover,
      String incidentId,
      String target,
      String action,
      String detail,
      Map<String, String> meta
  ) {}

  public record ApprovalRequest(
      String id,
      Instant createdAt,
      String agentId,
      String action,
      String target,
      String command,
      String incidentId,
      ApprovalState state,
      String approver,
      String decisionReason
  ) {
    public ApprovalRequest withState(ApprovalState s, String approver, String reason) {
      return new ApprovalRequest(
          id, createdAt, agentId, action, target, command, incidentId, s, approver, reason
      );
    }
  }

  public record SessionTicket(
      String id,
      Instant at,
      String agentId,
      String target,
      String incidentId,
      String mode,
      String status,
      String ttl,
      List<String> auditTrail
  ) {
    public SessionTicket withStatus(String status, String note) {
      List<String> trail = new ArrayList<>(auditTrail);
      trail.add(note);
      return new SessionTicket(id, at, agentId, target, incidentId, mode, status, ttl, trail);
    }
  }

  public record ActionResult(
      String id,
      Decision decision,
      String message,
      String approvalId,
      String correlationId
  ) {}
}
