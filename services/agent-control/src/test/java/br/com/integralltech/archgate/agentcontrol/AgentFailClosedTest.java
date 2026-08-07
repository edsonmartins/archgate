package br.com.integralltech.archgate.agentcontrol;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** With no credentials configured the agentic plane serves nothing. */
@SpringBootTest(properties = {
    "archgate.agent.api-token=",
    "archgate.agent.approver-token=",
})
@AutoConfigureMockMvc
class AgentFailClosedTest {

  @Autowired
  MockMvc mvc;

  @Test
  void actionsAreUnavailable() throws Exception {
    mvc.perform(post("/agentic/v1/actions")
            .contentType(MediaType.APPLICATION_JSON)
            .content("""
                {"agent_id":"sa-opensre","action":"diag.read","target":"rio-lab-ssh",
                 "incident_id":"INC-X"}
                """))
        .andExpect(status().isServiceUnavailable());
  }

  @Test
  void killSwitchIsUnavailable() throws Exception {
    mvc.perform(post("/agentic/v1/kill-switch")
            .header("Authorization", "Bearer anything")
            .contentType(MediaType.APPLICATION_JSON)
            .content("""
                {"agent_id":"sa-opensre","reason":"x"}
                """))
        .andExpect(status().isServiceUnavailable());
  }

  @Test
  void healthStillReports() throws Exception {
    mvc.perform(get("/actuator/health"))
        .andExpect(status().isOk());
  }
}
