package br.com.integralltech.archgate.agentcontrol;

import br.com.integralltech.archgate.agentcontrol.domain.Models.ActionResult;
import br.com.integralltech.archgate.agentcontrol.domain.Models.ApprovalRequest;
import br.com.integralltech.archgate.agentcontrol.domain.Models.ApprovalState;
import br.com.integralltech.archgate.agentcontrol.domain.Models.Decision;
import br.com.integralltech.archgate.agentcontrol.domain.Models.SessionTicket;
import br.com.integralltech.archgate.agentcontrol.policy.PolicyEngine;
import br.com.integralltech.archgate.agentcontrol.policy.PolicyLoader;
import br.com.integralltech.archgate.agentcontrol.service.AgentControlService;
import br.com.integralltech.archgate.agentcontrol.service.AuditLog;
import br.com.integralltech.archgate.agentcontrol.service.KillSwitchRegistry;
import br.com.integralltech.archgate.agentcontrol.service.RateLimiter;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

class AgentControlServiceTest {

  private AgentControlService svc;
  private KillSwitchRegistry kill;
  private AuditLog audit;

  @BeforeEach
  void setUp() {
    PolicyLoader loader = new PolicyLoader();
    ReflectionTestUtils.setField(loader, "policyPath", "");
    loader.load();
    kill = new KillSwitchRegistry();
    audit = new AuditLog();
    svc = new AgentControlService(
        new PolicyEngine(loader),
        loader,
        new RateLimiter(100),
        audit,
        kill,
        "http://127.0.0.1:9",
        false
    );
  }

  @Test
  void readSessionAutoIssued() {
    SessionTicket t = svc.requestSession(
        "sa-opensre", "diag.read", "rio-lab-ssh", "INC-1", "read"
    );
    assertEquals("issued", t.status());
    assertFalse(audit.byIncident("INC-1").isEmpty());
  }

  @Test
  void mutantRequiresHitlThenApprove() {
    ActionResult r = svc.submitAction(
        "sa-opensre", "shell.write", "rio-lab-ssh", "systemctl restart nginx", "INC-2"
    );
    assertEquals(Decision.PENDING_HITL, r.decision());
    assertNotNull(r.approvalId());

    ApprovalRequest a = svc.approve(r.approvalId(), "ops.human", "ok");
    assertEquals(ApprovalState.APPROVED, a.state());
    assertEquals("ops.human", a.approver());
    assertTrue(audit.byIncident("INC-2").stream()
        .anyMatch(e -> "hitl.approved".equals(e.type()) && "ops.human".equals(e.humanApprover())));
  }

  @Test
  void dangerousCommandDenied() {
    ActionResult r = svc.submitAction(
        "sa-opensre", "shell.write", "rio-lab-ssh", "rm -rf /", "INC-3"
    );
    assertEquals(Decision.DENY, r.decision());
  }

  @Test
  void killSwitchBlocksFurtherActions() {
    svc.killSwitch("sa-opensre", "test", "secops");
    assertTrue(kill.isKilled("sa-opensre"));
    SessionTicket t = svc.requestSession(
        "sa-opensre", "diag.read", "rio-lab-ssh", "INC-4", "read"
    );
    assertEquals("denied", t.status());
  }

  @Test
  void unknownActionDenied() {
    ActionResult r = svc.submitAction(
        "sa-opensre", "drop.database", "rio-lab-ssh", null, "INC-5"
    );
    assertEquals(Decision.DENY, r.decision());
  }

  @Test
  void missingIncidentDenied() {
    SessionTicket t = svc.requestSession(
        "sa-opensre", "diag.read", "rio-lab-ssh", "", "read"
    );
    assertEquals("denied", t.status());
  }
}
