package br.com.integralltech.archgate.orchestration;

import br.com.integralltech.archgate.orchestration.adapter.ArchGuardLiveAdapter;
import br.com.integralltech.archgate.orchestration.adapter.OpenBaoLiveAdapter;
import br.com.integralltech.archgate.orchestration.adapter.WarpgateLiveAdapter;
import br.com.integralltech.archgate.orchestration.config.OrchestrationProperties;
import br.com.integralltech.archgate.orchestration.domain.OrchestrationResult;
import br.com.integralltech.archgate.orchestration.service.LifecycleService;
import org.junit.jupiter.api.Test;

import com.sun.net.httpserver.HttpServer;
import java.io.IOException;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;

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
    assertEquals("partial", r.status());
    assertTrue(r.steps().contains("openbao:revokeAll:FAIL"));
    assertEquals(3, r.steps().size());
  }

  @Test
  void resolvesSessionContextThroughArchGuardServiceContract() throws IOException {
    HttpServer server = HttpServer.create(new InetSocketAddress(0), 0);
    server.createContext("/api/v1/service/session-context", exchange -> {
      assertEquals("Bearer secret", exchange.getRequestHeaders().getFirst("Authorization"));
      byte[] body = exchange.getRequestBody().readAllBytes();
      assertTrue(new String(body, StandardCharsets.UTF_8).contains("subject-1"));
      byte[] response = ("{\"subject\":\"subject-1\",\"identity_id\":\"00000000-0000-0000-0000-000000000001\","
          + "\"identity_status\":\"active\",\"memberships\":[{\"membership_id\":\"00000000-0000-0000-0000-000000000002\","
          + "\"organization_id\":\"00000000-0000-0000-0000-000000000003\",\"status\":\"active\"}]}" )
          .getBytes(StandardCharsets.UTF_8);
      exchange.getResponseHeaders().set("Content-Type", "application/json");
      exchange.sendResponseHeaders(200, response.length);
      exchange.getResponseBody().write(response);
      exchange.close();
    });
    server.start();
    try {
      var endpoint = new OrchestrationProperties.Endpoint(
          "http://127.0.0.1:" + server.getAddress().getPort(), "secret", true);
      var context = new ArchGuardLiveAdapter(endpoint, false).resolveSessionContext("subject-1");
      assertEquals("subject-1", context.subject());
      assertEquals("active", context.identityStatus());
      assertEquals(1, context.memberships().size());
      assertEquals("00000000-0000-0000-0000-000000000003", context.memberships().getFirst().organizationId().toString());
    } finally {
      server.stop(0);
    }
  }
}
