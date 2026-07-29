package br.com.integralltech.archgate.orchestration;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * The orchestration API drives identity and access lifecycle. Before the
 * 2026-07-28 audit it accepted anonymous calls while published on the public
 * edge (P0-3). These tests pin the authenticated contract.
 */
@SpringBootTest(properties = "archgate.orchestration.api-token=test-token")
@AutoConfigureMockMvc
class ServiceTokenFilterTest {

  @Autowired
  MockMvc mvc;

  private static final String REVOKE = """
      {"username":"victim","reason":"unauthenticated"}
      """;

  @Test
  void anonymousMutationIsRejected() throws Exception {
    mvc.perform(post("/orchestration/v1/users/revoke")
            .contentType(MediaType.APPLICATION_JSON)
            .content(REVOKE))
        .andExpect(status().isUnauthorized());
  }

  @Test
  void wrongTokenIsRejected() throws Exception {
    mvc.perform(post("/orchestration/v1/users/revoke")
            .header("Authorization", "Bearer not-the-token")
            .contentType(MediaType.APPLICATION_JSON)
            .content(REVOKE))
        .andExpect(status().isUnauthorized());
  }

  @Test
  void nonBearerSchemeIsRejected() throws Exception {
    mvc.perform(post("/orchestration/v1/users/revoke")
            .header("Authorization", "Basic dGVzdC10b2tlbg==")
            .contentType(MediaType.APPLICATION_JSON)
            .content(REVOKE))
        .andExpect(status().isUnauthorized());
  }

  @Test
  void anonymousReadIsRejected() throws Exception {
    mvc.perform(get("/orchestration/v1/status/last"))
        .andExpect(status().isUnauthorized());
  }

  @Test
  void healthProbeStaysOpen() throws Exception {
    mvc.perform(get("/actuator/health"))
        .andExpect(status().isOk());
  }

  @Test
  void validTokenPassesThrough() throws Exception {
    mvc.perform(post("/orchestration/v1/tenants/sync")
            .header("Authorization", "Bearer test-token"))
        .andExpect(status().isOk());
  }
}
