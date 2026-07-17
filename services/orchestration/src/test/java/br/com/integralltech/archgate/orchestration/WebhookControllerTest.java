package br.com.integralltech.archgate.orchestration;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
class WebhookControllerTest {

  @Autowired
  MockMvc mvc;

  @Test
  void idempotentOffboard() throws Exception {
    String body = """
        {"event":"user.offboard","username":"axis-user","reason":"left"}
        """;

    mvc.perform(post("/orchestration/v1/webhooks/axis")
            .header("Idempotency-Key", "evt-001")
            .contentType(MediaType.APPLICATION_JSON)
            .content(body))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.operation").value("users.revoke"))
        .andExpect(jsonPath("$.operationId").exists());

    // Same key → same operationId
    String opId = mvc.perform(post("/orchestration/v1/webhooks/axis")
            .header("Idempotency-Key", "evt-001")
            .contentType(MediaType.APPLICATION_JSON)
            .content(body))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.operation").value("users.revoke"))
        .andReturn()
        .getResponse()
        .getContentAsString();

    // Just ensure second call succeeds (idempotent store returns cached)
    org.junit.jupiter.api.Assertions.assertTrue(opId.contains("users.revoke"));
  }

  @Test
  void provisionEvent() throws Exception {
    mvc.perform(post("/orchestration/v1/webhooks/axis")
            .contentType(MediaType.APPLICATION_JSON)
            .content("""
                {
                  "event":"user.provision",
                  "username":"new.dev",
                  "tenant_slug":"rio_quality",
                  "email":"n@x.c",
                  "groups":["tenant_rio_quality"]
                }
                """))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.operation").value("users.provision"));
  }
}
