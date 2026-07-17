package br.com.integralltech.archgate.agentcontrol.api;

import br.com.integralltech.archgate.agentcontrol.domain.Models.ActionResult;
import br.com.integralltech.archgate.agentcontrol.domain.Models.ApprovalRequest;
import br.com.integralltech.archgate.agentcontrol.domain.Models.AuditEvent;
import br.com.integralltech.archgate.agentcontrol.domain.Models.SessionTicket;
import br.com.integralltech.archgate.agentcontrol.service.AgentControlService;
import br.com.integralltech.archgate.agentcontrol.service.AuditLog;
import br.com.integralltech.archgate.agentcontrol.service.KillSwitchRegistry;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/agentic/v1")
public class AgentController {

  private final AgentControlService service;
  private final AuditLog auditLog;
  private final KillSwitchRegistry killSwitch;

  public AgentController(
      AgentControlService service,
      AuditLog auditLog,
      KillSwitchRegistry killSwitch
  ) {
    this.service = service;
    this.auditLog = auditLog;
    this.killSwitch = killSwitch;
  }

  public record SessionRequest(
      @NotBlank String agent_id,
      @NotBlank String action,
      String target,
      String incident_id,
      String mode
  ) {}

  public record ActionRequest(
      @NotBlank String agent_id,
      @NotBlank String action,
      String target,
      String command,
      String incident_id
  ) {}

  public record ApprovalBody(String approver, String reason) {}

  public record KillBody(
      @NotBlank String agent_id,
      String reason,
      String actor
  ) {}

  @PostMapping("/sessions/request")
  public SessionTicket requestSession(@Valid @RequestBody SessionRequest req) {
    return service.requestSession(
        req.agent_id(), req.action(), req.target(), req.incident_id(), req.mode()
    );
  }

  @PostMapping("/actions")
  public ActionResult action(@Valid @RequestBody ActionRequest req) {
    return service.submitAction(
        req.agent_id(), req.action(), req.target(), req.command(), req.incident_id()
    );
  }

  @PostMapping("/approvals/{id}/approve")
  public ApprovalRequest approve(
      @PathVariable String id,
      @RequestBody(required = false) ApprovalBody body
  ) {
    String approver = body != null && body.approver() != null ? body.approver() : "unknown";
    String reason = body != null ? body.reason() : null;
    return service.approve(id, approver, reason);
  }

  @PostMapping("/approvals/{id}/deny")
  public ApprovalRequest deny(
      @PathVariable String id,
      @RequestBody(required = false) ApprovalBody body
  ) {
    String approver = body != null && body.approver() != null ? body.approver() : "unknown";
    String reason = body != null ? body.reason() : null;
    return service.deny(id, approver, reason);
  }

  @GetMapping("/approvals/{id}")
  public ResponseEntity<ApprovalRequest> getApproval(@PathVariable String id) {
    return service.getApproval(id)
        .map(ResponseEntity::ok)
        .orElse(ResponseEntity.notFound().build());
  }

  @PostMapping("/kill-switch")
  public Map<String, Object> kill(@Valid @RequestBody KillBody body) {
    return service.killSwitch(body.agent_id(), body.reason(), body.actor());
  }

  @GetMapping("/kill-switch/{agentId}")
  public Map<String, Object> killStatus(@PathVariable String agentId) {
    return Map.of(
        "agent_id", agentId,
        "killed", killSwitch.isKilled(agentId),
        "record", killSwitch.get(agentId).orElse(null)
    );
  }

  @GetMapping("/audit")
  public List<AuditEvent> audit(
      @RequestParam(required = false) String incident_id,
      @RequestParam(required = false) String agent_id
  ) {
    if (incident_id != null && !incident_id.isBlank()) {
      return auditLog.byIncident(incident_id);
    }
    if (agent_id != null && !agent_id.isBlank()) {
      return auditLog.byAgent(agent_id);
    }
    return auditLog.all();
  }

  @GetMapping("/policy/cloud-llm")
  public Map<String, Object> cloudLlm() {
    return Map.of(
        "allow_cloud_llm", service.isCloudLlmAllowed(),
        "note", "W5-AG08: default false — local inference for client data"
    );
  }
}
