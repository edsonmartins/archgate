package br.com.integralltech.archgate.orchestration;

import br.com.integralltech.archgate.orchestration.adapter.MockComponentAdapter;
import br.com.integralltech.archgate.orchestration.domain.OrchestrationResult;
import br.com.integralltech.archgate.orchestration.service.LifecycleService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class LifecycleServiceTest {

  private MockComponentAdapter kanidm;
  private MockComponentAdapter warpgate;
  private MockComponentAdapter guacamole;
  private MockComponentAdapter openbao;
  private LifecycleService svc;

  @BeforeEach
  void setUp() {
    kanidm = new MockComponentAdapter("kanidm");
    warpgate = new MockComponentAdapter("warpgate");
    guacamole = new MockComponentAdapter("guacamole");
    openbao = new MockComponentAdapter("openbao");
    svc = new LifecycleService(List.of(kanidm, warpgate, guacamole, openbao));
  }

  @Test
  void provisionCreatesPersonOnAllAdapters() {
    OrchestrationResult r = svc.provision(
        "rio_quality",
        "dev.silva",
        "dev.silva@integrall.tech",
        "operator",
        List.of()
    );
    assertEquals("ok", r.status());
    assertEquals("users.provision", r.operation());
    assertTrue(kanidm.hasPerson("dev.silva"));
    assertTrue(warpgate.hasPerson("dev.silva"));
    assertTrue(guacamole.hasPerson("dev.silva"));
    assertTrue(r.details().get("groups").contains("tenant_rio_quality"));
    assertTrue(r.details().get("groups").contains("archguard_users"));
  }

  @Test
  void grantAndRevokeOneShot() {
    svc.provision("tenant_rio_quality", "uat-op-a", "a@x", "operator", List.of());
    OrchestrationResult g = svc.grant("uat-op-a", "rio-lab-ssh", "8h");
    assertEquals("ok", g.status());
    assertTrue(warpgate.hasGrant("uat-op-a", "rio-lab-ssh"));
    assertTrue(openbao.hasGrant("uat-op-a", "rio-lab-ssh"));
    // Guac does not receive grant in filter
    assertFalse(guacamole.hasGrant("uat-op-a", "rio-lab-ssh"));

    OrchestrationResult rev = svc.revoke("uat-op-a", "offboarding");
    assertEquals("ok", rev.status());
    assertEquals("users.revoke", rev.operation());
    assertFalse(kanidm.hasPerson("uat-op-a"));
    assertFalse(warpgate.hasPerson("uat-op-a"));
    assertFalse(guacamole.hasPerson("uat-op-a"));
    assertFalse(openbao.hasGrant("uat-op-a", "rio-lab-ssh"));
    assertEquals(4, rev.steps().size());
  }

  @Test
  void revokeIsIdempotent() {
    svc.revoke("ghost", "cleanup");
    OrchestrationResult r2 = svc.revoke("ghost", "cleanup");
    assertEquals("ok", r2.status());
    assertFalse(kanidm.hasPerson("ghost"));
  }

  @Test
  void lastStatusTracked() {
    svc.provision("t", "u1", "e@x", "operator", List.of());
    assertEquals("users.provision", svc.lastFor("u1").operation());
    assertEquals("users.provision", svc.lastGlobal().operation());
  }
}
