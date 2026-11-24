package br.com.integralltech.archgate.orchestration;

import br.com.integralltech.archgate.orchestration.adapter.ArchGuardLiveAdapter;
import br.com.integralltech.archgate.orchestration.config.OrchestrationProperties;
import com.sun.net.httpserver.HttpServer;
import org.junit.jupiter.api.Test;

import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.atomic.AtomicReference;
import com.sun.net.httpserver.Headers;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

class ArchGuardLiveAdapterContractTest {

  @Test
  void resolvesSessionContextUsingServiceBearerAndOpaqueSubject() throws Exception {
    AtomicReference<String> authorization = new AtomicReference<>();
    AtomicReference<String> body = new AtomicReference<>();
    HttpServer server = HttpServer.create(new InetSocketAddress(0), 0);
    server.createContext("/api/v1/service/session-context", exchange -> {
      authorization.set(exchange.getRequestHeaders().getFirst("Authorization"));
      body.set(new String(exchange.getRequestBody().readAllBytes(), StandardCharsets.UTF_8));
      byte[] response = "{\"subject\":\"oidc-123\",\"identity_id\":\"11111111-1111-1111-1111-111111111111\",\"identity_status\":\"active\",\"memberships\":[]}".getBytes(StandardCharsets.UTF_8);
      Headers headers = exchange.getResponseHeaders();
      headers.set("Content-Type", "application/json");
      exchange.sendResponseHeaders(200, response.length);
      exchange.getResponseBody().write(response);
      exchange.close();
    });
    server.start();
    try {
      var endpoint = new OrchestrationProperties.Endpoint(
          "http://127.0.0.1:" + server.getAddress().getPort(), "service-token", true);
      var context = new ArchGuardLiveAdapter(endpoint, false).resolveSessionContext("oidc-123");

      assertEquals("Bearer service-token", authorization.get());
      assertTrue(body.get().contains("\"subject\":\"oidc-123\""));
      assertEquals("oidc-123", context.subject());
      assertEquals("active", context.identityStatus());
    } finally {
      server.stop(0);
    }
  }

  @Test
  void revokesManagerMembershipUsingMembershipId() throws Exception {
    AtomicReference<String> path = new AtomicReference<>();
    AtomicReference<String> body = new AtomicReference<>();
    HttpServer server = HttpServer.create(new InetSocketAddress(0), 0);
    server.createContext("/", exchange -> {
      path.set(exchange.getRequestURI().getPath());
      body.set(new String(exchange.getRequestBody().readAllBytes(), StandardCharsets.UTF_8));
      byte[] response = "{}".getBytes(StandardCharsets.UTF_8);
      exchange.getResponseHeaders().set("Content-Type", "application/json");
      exchange.sendResponseHeaders(200, response.length);
      exchange.getResponseBody().write(response);
      exchange.close();
    });
    server.start();
    try {
      var endpoint = new OrchestrationProperties.Endpoint(
          "http://127.0.0.1:" + server.getAddress().getPort(), "service-token", true);
      new ArchGuardLiveAdapter(endpoint, false).revokeMembership("membership-123");
      assertEquals("/api/v1/memberships/revoke", path.get());
      assertTrue(body.get().contains("\"membership_id\":\"membership-123\""));
    } finally {
      server.stop(0);
    }
  }
}
