package br.com.integralltech.archgate.agentcontrol;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
class AgentControllerTest {

  @Autowired
  MockMvc mvc;

  @Test
  void e2eReadHitlKill() throws Exception {
    mvc.perform(post("/agentic/v1/sessions/request")
            .contentType(MediaType.APPLICATION_JSON)
            .content("""
                {
                  "agent_id":"sa-opensre",
                  "action":"diag.read",
                  "target":"rio-lab-ssh",
                  "incident_id":"INC-E2E",
                  "mode":"read"
                }
                """))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.status").value("issued"));

    MvcResult mut = mvc.perform(post("/agentic/v1/actions")
            .contentType(MediaType.APPLICATION_JSON)
            .content("""
                {
                  "agent_id":"sa-opensre",
                  "action":"service.restart",
                  "target":"rio-lab-ssh",
                  "incident_id":"INC-E2E"
                }
                """))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.decision").value("PENDING_HITL"))
        .andReturn();

    String body = mut.getResponse().getContentAsString();
    String approvalId = body.replaceAll("(?s).*\"approvalId\"\\s*:\\s*\"([^\"]+)\".*", "$1");

    mvc.perform(post("/agentic/v1/approvals/" + approvalId + "/approve")
            .contentType(MediaType.APPLICATION_JSON)
            .content("""
                {"approver":"ops.human","reason":"authorized"}
                """))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.state").value("APPROVED"));

    mvc.perform(get("/agentic/v1/audit").param("incident_id", "INC-E2E"))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$").isArray());

    mvc.perform(post("/agentic/v1/kill-switch")
            .contentType(MediaType.APPLICATION_JSON)
            .content("""
                {"agent_id":"sa-opensre","reason":"e2e","actor":"secops"}
                """))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.killed").value(true));

    mvc.perform(get("/agentic/v1/policy/cloud-llm"))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.allow_cloud_llm").value(false));
  }
}
