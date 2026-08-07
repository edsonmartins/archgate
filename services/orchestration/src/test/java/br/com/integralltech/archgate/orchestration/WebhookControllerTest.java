package br.com.integralltech.archgate.orchestration;

import br.com.integralltech.archgate.orchestration.security.Tokens;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import java.nio.charset.StandardCharsets;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest(properties = {
    "archgate.orchestration.api-token=test-token",
    "archgate.orchestration.webhook-secret=test-webhook-secret",
})
@AutoConfigureMockMvc
class WebhookControllerTest {

  private static final String AUTH = "Bearer test-token";
  private static final String SECRET = "test-webhook-secret";

  @Autowired
  MockMvc mvc;

  private static String sign(String body) {
    return "sha256=" + Tokens.hmacSha256Hex(SECRET, body.getBytes(StandardCharsets.UTF_8));
  }

  @Test
  void idempotentOffboard() throws Exception {
    String body = """
        {"event":"user.offboard","username":"axis-user","reason":"left"}
        """;

    mvc.perform(post("/orchestration/v1/webhooks/axis")
            .header("Authorization", AUTH)
            .header("X-ArchGate-Signature", sign(body))
            .header("Idempotency-Key", "evt-001")
            .contentType(MediaType.APPLICATION_JSON)
            .content(body))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.operation").value("users.revoke"))
        .andExpect(jsonPath("$.operationId").exists());

    // Same key → cached result, no re-execution.
    String opId = mvc.perform(post("/orchestration/v1/webhooks/axis")
            .header("Authorization", AUTH)
            .header("X-ArchGate-Signature", sign(body))
            .header("Idempotency-Key", "evt-001")
            .contentType(MediaType.APPLICATION_JSON)
            .content(body))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.operation").value("users.revoke"))
        .andReturn()
        .getResponse()
        .getContentAsString();

    org.junit.jupiter.api.Assertions.assertTrue(opId.contains("users.revoke"));
  }

  @Test
  void provisionEvent() throws Exception {
    String body = """
        {
          "event":"user.provision",
          "username":"new.dev",
          "tenant_slug":"rio_quality",
          "email":"n@x.c",
          "groups":["tenant_rio_quality"]
        }
        """;
    mvc.perform(post("/orchestration/v1/webhooks/axis")
            .header("Authorization", AUTH)
            .header("X-ArchGate-Signature", sign(body))
            .contentType(MediaType.APPLICATION_JSON)
            .content(body))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.operation").value("users.provision"));
  }

  @Test
  void bareHexDigestIsAccepted() throws Exception {
    String body = """
        {"event":"tenants.sync"}
        """;
    mvc.perform(post("/orchestration/v1/webhooks/axis")
            .header("Authorization", AUTH)
            .header("X-ArchGate-Signature",
                Tokens.hmacSha256Hex(SECRET, body.getBytes(StandardCharsets.UTF_8)))
            .contentType(MediaType.APPLICATION_JSON)
            .content(body))
        .andExpect(status().isOk());
  }

  @Test
  void unsignedWebhookIsRejected() throws Exception {
    mvc.perform(post("/orchestration/v1/webhooks/axis")
            .header("Authorization", AUTH)
            .contentType(MediaType.APPLICATION_JSON)
            .content("""
                {"event":"user.offboard","username":"victim"}
                """))
        .andExpect(status().isUnauthorized());
  }

  @Test
  void tamperedBodyIsRejected() throws Exception {
    String signed = """
        {"event":"user.offboard","username":"axis-user"}
        """;
    String tampered = """
        {"event":"user.offboard","username":"someone-else"}
        """;
    mvc.perform(post("/orchestration/v1/webhooks/axis")
            .header("Authorization", AUTH)
            .header("X-ArchGate-Signature", sign(signed))
            .contentType(MediaType.APPLICATION_JSON)
            .content(tampered))
        .andExpect(status().isUnauthorized());
  }

  @Test
  void serviceTokenAloneIsNotEnough() throws Exception {
    mvc.perform(post("/orchestration/v1/webhooks/axis")
            .header("Authorization", AUTH)
            .header("X-ArchGate-Signature", "sha256=deadbeef")
            .contentType(MediaType.APPLICATION_JSON)
            .content("""
                {"event":"tenants.sync"}
                """))
        .andExpect(status().isUnauthorized());
  }

  @Test
  void anonymousWebhookIsRejected() throws Exception {
    String body = """
        {"event":"tenants.sync"}
        """;
    mvc.perform(post("/orchestration/v1/webhooks/axis")
            .header("X-ArchGate-Signature", sign(body))
            .contentType(MediaType.APPLICATION_JSON)
            .content(body))
        .andExpect(status().isUnauthorized());
  }
}
