package br.com.integralltech.archgate.orchestration;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
class OrchestrationControllerTest {

  @Autowired
  MockMvc mvc;

  @Test
  void provisionGrantRevokeFlow() throws Exception {
    mvc.perform(post("/orchestration/v1/users/provision")
            .contentType(MediaType.APPLICATION_JSON)
            .content("""
                {
                  "tenant_slug": "rio_quality",
                  "username": "dev.silva",
                  "email": "dev.silva@integrall.tech",
                  "profile": "operator",
                  "groups": ["tenant_rio_quality"]
                }
                """))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.status").value("ok"))
        .andExpect(jsonPath("$.operation").value("users.provision"));

    mvc.perform(post("/orchestration/v1/access/grant")
            .contentType(MediaType.APPLICATION_JSON)
            .content("""
                {"username":"dev.silva","target":"rio-lab-ssh","ttl":"8h"}
                """))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.operation").value("access.grant"));

    mvc.perform(post("/orchestration/v1/users/revoke")
            .contentType(MediaType.APPLICATION_JSON)
            .content("""
                {"username":"dev.silva","reason":"offboarding"}
                """))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.operation").value("users.revoke"))
        .andExpect(jsonPath("$.steps").isArray());

    mvc.perform(get("/orchestration/v1/status/users/dev.silva"))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.operation").value("users.revoke"));
  }

  @Test
  void syncTenants() throws Exception {
    mvc.perform(post("/orchestration/v1/tenants/sync"))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.operation").value("tenants.sync"));
  }

  @Test
  void validationRejectsBlankUsername() throws Exception {
    mvc.perform(post("/orchestration/v1/users/revoke")
            .contentType(MediaType.APPLICATION_JSON)
            .content("""
                {"username":"","reason":"x"}
                """))
        .andExpect(status().isBadRequest());
  }
}
