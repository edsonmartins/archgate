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
 * A deploy that forgets ORCH_API_TOKEN must serve nothing rather than
 * everything. Fail-closed is the point of the control (audit 2026-07-28).
 */
@SpringBootTest(properties = "archgate.orchestration.api-token=")
@AutoConfigureMockMvc
class FailClosedTest {

  @Autowired
  MockMvc mvc;

  @Test
  void mutationIsUnavailableWithoutConfiguredToken() throws Exception {
    mvc.perform(post("/orchestration/v1/users/revoke")
            .contentType(MediaType.APPLICATION_JSON)
            .content("""
                {"username":"victim","reason":"no token configured"}
                """))
        .andExpect(status().isServiceUnavailable());
  }

  @Test
  void noBearerCanUnlockAnUnconfiguredService() throws Exception {
    mvc.perform(post("/orchestration/v1/tenants/sync")
            .header("Authorization", "Bearer anything"))
        .andExpect(status().isServiceUnavailable());
  }

  @Test
  void healthStillReports() throws Exception {
    mvc.perform(get("/actuator/health"))
        .andExpect(status().isOk());
  }
}
