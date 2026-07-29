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

@SpringBootTest(properties = {
    "archgate.agent.api-token=agent-token",
    "archgate.agent.approver-token=approver-token",
})
@AutoConfigureMockMvc
class AgentControllerTest {

  private static final String AGENT = "Bearer agent-token";
  private static final String APPROVER = "Bearer approver-token";

  @Autowired
  MockMvc mvc;

  @Test
  void e2eReadHitlKill() throws Exception {
    mvc.perform(post("/agentic/v1/sessions/request")
            .header("Authorization", AGENT)
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
            .header("Authorization", AGENT)
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
            .header("Authorization", APPROVER)
            .header("X-ArchGate-Actor", "ops.human")
            .contentType(MediaType.APPLICATION_JSON)
            .content("""
                {"reason":"authorized"}
                """))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.state").value("APPROVED"))
        .andExpect(jsonPath("$.approver").value("ops.human"));

    mvc.perform(get("/agentic/v1/audit")
            .header("Authorization", APPROVER)
            .param("incident_id", "INC-E2E"))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$").isArray());

    mvc.perform(post("/agentic/v1/kill-switch")
            .header("Authorization", APPROVER)
            .header("X-ArchGate-Actor", "secops")
            .contentType(MediaType.APPLICATION_JSON)
            .content("""
                {"agent_id":"sa-opensre","reason":"e2e"}
                """))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.killed").value(true));

    mvc.perform(get("/agentic/v1/policy/cloud-llm")
            .header("Authorization", AGENT))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.allow_cloud_llm").value(false));
  }
}
