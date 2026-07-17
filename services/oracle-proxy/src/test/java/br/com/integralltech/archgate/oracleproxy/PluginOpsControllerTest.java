package br.com.integralltech.archgate.oracleproxy;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

@SpringBootTest(properties = "oracle.proxy.mock=true")
@AutoConfigureMockMvc
class PluginOpsControllerTest {

  @Autowired MockMvc mvc;

  @Test
  void createUpdateDeleteUserMock() throws Exception {
    mvc.perform(
            post("/v1/oracle/users")
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    """
                    {"username":"v_test_user1","password":"Secret123!","expiration":"2026-12-31"}
                    """))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.status").value("ok"));

    mvc.perform(
            post("/v1/oracle/users/delete")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""
                    {"username":"v_test_user1"}
                    """))
        .andExpect(status().isOk());
  }

  @Test
  void rejectLongUsername() throws Exception {
    String longName = "u" + "x".repeat(40);
    mvc.perform(
            post("/v1/oracle/users")
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    "{\"username\":\"" + longName + "\",\"password\":\"Secret123!\"}"))
        .andExpect(status().is4xxClientError());
  }
}
