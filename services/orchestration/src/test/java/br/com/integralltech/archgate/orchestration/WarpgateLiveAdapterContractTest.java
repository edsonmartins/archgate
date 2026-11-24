package br.com.integralltech.archgate.orchestration;

import br.com.integralltech.archgate.orchestration.adapter.WarpgateLiveAdapter;
import br.com.integralltech.archgate.orchestration.config.OrchestrationProperties;
import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpServer;
import org.junit.jupiter.api.Test;

import java.io.IOException;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.atomic.AtomicInteger;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

class WarpgateLiveAdapterContractTest {

  @Test
  void sendsUpsertGrantAndEncodedRevokeToWarpgateAdminApi() throws IOException {
    List<String> requests = new ArrayList<>();
    HttpServer server = HttpServer.create(new InetSocketAddress(0), 0);
    server.createContext("/", exchange -> {
      requests.add(exchange.getRequestMethod() + " " + exchange.getRequestURI().getRawPath());
      respond(exchange, 200);
    });
    server.start();
    try {
      var endpoint = new OrchestrationProperties.Endpoint(
          "http://127.0.0.1:" + server.getAddress().getPort(), "token", true);
      var adapter = new WarpgateLiveAdapter(endpoint, false);

      adapter.ensurePerson("ana.silva", "ana@example.com", List.of("tenant_rio"));
      adapter.grantAccess("ana.silva", "role/rio quality", "30m");
      adapter.revokeAll("ana.silva");

      assertTrue(requests.stream().anyMatch(r -> r.startsWith("POST /@warpgate/admin/api/users")));
      assertTrue(requests.stream().anyMatch(r -> r.contains("/roles/")
          && r.endsWith("/users") && !r.contains("rio quality")));
      assertTrue(requests.stream().anyMatch(r -> r.equals("DELETE /@warpgate/admin/api/users/ana.silva")));
    } finally {
      server.stop(0);
    }
  }

  @Test
  void fallsBackToCloseTicketsWhenUserDeleteIsUnsupported() throws IOException {
    List<String> requests = new ArrayList<>();
    HttpServer server = HttpServer.create(new InetSocketAddress(0), 0);
    server.createContext("/", exchange -> {
      String request = exchange.getRequestMethod() + " " + exchange.getRequestURI().getRawPath();
      requests.add(request);
      respond(exchange, request.startsWith("DELETE ") ? 405 : 200);
    });
    server.start();
    try {
      var endpoint = new OrchestrationProperties.Endpoint(
          "http://127.0.0.1:" + server.getAddress().getPort(), "token", true);
      new WarpgateLiveAdapter(endpoint, false).revokeAll("ana.silva");

      assertEquals(List.of(
          "DELETE /@warpgate/admin/api/users/ana.silva",
          "POST /@warpgate/admin/api/users/ana.silva/tickets/close-all"), requests);
    } finally {
      server.stop(0);
    }
  }

  @Test
  void retriesTransientServerFailureButDoesNotRetryPermanentClientFailure() throws IOException {
    AtomicInteger attempts = new AtomicInteger();
    HttpServer server = HttpServer.create(new InetSocketAddress(0), 0);
    server.createContext("/", exchange -> {
      int attempt = attempts.incrementAndGet();
      respond(exchange, attempt == 1 ? 503 : 200);
    });
    server.start();
    try {
      var endpoint = new OrchestrationProperties.Endpoint(
          "http://127.0.0.1:" + server.getAddress().getPort(), "token", true);
      new WarpgateLiveAdapter(endpoint, false).ensurePerson("ana.silva", "ana@example.com", List.of());
      assertEquals(2, attempts.get());
    } finally {
      server.stop(0);
    }
  }

  private static void respond(HttpExchange exchange, int status) throws IOException {
    byte[] body = "{}".getBytes(StandardCharsets.UTF_8);
    exchange.sendResponseHeaders(status, body.length);
    exchange.getResponseBody().write(body);
    exchange.close();
  }
}
