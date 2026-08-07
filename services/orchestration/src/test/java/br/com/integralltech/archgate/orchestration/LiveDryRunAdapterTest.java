package br.com.integralltech.archgate.orchestration;

import br.com.integralltech.archgate.orchestration.adapter.ArchGuardLiveAdapter;
import br.com.integralltech.archgate.orchestration.adapter.OpenBaoLiveAdapter;
import br.com.integralltech.archgate.orchestration.adapter.WarpgateLiveAdapter;
import br.com.integralltech.archgate.orchestration.config.OrchestrationProperties;
import br.com.integralltech.archgate.orchestration.domain.OrchestrationResult;
import br.com.integralltech.archgate.orchestration.service.LifecycleService;
import org.junit.jupiter.api.Test;

import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

class LiveDryRunAdapterTest {

  @Test
  void liveDryRunProvisionRevokeDoesNotThrow() {
    var disabled = new OrchestrationProperties.Endpoint("https://example.invalid", "tok", false);
    var svc = new LifecycleService(List.of(
        new ArchGuardLiveAdapter(disabled, true),
        new WarpgateLiveAdapter(disabled, true),
        new OpenBaoLiveAdapter(disabled, true)
    ));

    OrchestrationResult p = svc.provision("rio_quality", "live.user", "l@x.c", "operator", List.of());
    assertEquals("ok", p.status());
    assertTrue(p.steps().stream().anyMatch(s -> s.startsWith("archguard:")));

    OrchestrationResult g = svc.grant("live.user", "rio-lab-ssh", "4h");
    assertEquals("ok", g.status());

    OrchestrationResult r = svc.revoke("live.user", "test");
    assertEquals("ok", r.status());
    assertEquals(3, r.steps().size());
  }
}
