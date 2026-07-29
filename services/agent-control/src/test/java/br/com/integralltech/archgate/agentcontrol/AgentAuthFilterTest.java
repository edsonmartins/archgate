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

/**
 * HITL only means something if the agent cannot approve its own actions or turn
 * off the kill-switch. Before the 2026-07-28 audit (P1-2) every route was
 * anonymous and the caller declared its own identity.
 */
@SpringBootTest(properties = {
    "archgate.agent.api-token=filter-agent-token",
    "archgate.agent.approver-token=filter-approver-token",
})
@AutoConfigureMockMvc
class AgentAuthFilterTest {

  private static final String AGENT = "Bearer filter-agent-token";
  private static final String APPROVER = "Bearer filter-approver-token";

  @Autowired
  MockMvc mvc;

  private String pendingApprovalId() throws Exception {
    MvcResult mut = mvc.perform(post("/agentic/v1/actions")
            .header("Authorization", AGENT)
            .contentType(MediaType.APPLICATION_JSON)
            .content("""
                {
                  "agent_id":"sa-opensre",
                  "action":"service.restart",
                  "target":"rio-lab-ssh",
                  "incident_id":"INC-AUTH"
                }
                """))
        .andExpect(status().isOk())
        .andReturn();
    String body = mut.getResponse().getContentAsString();
    String id = body.replaceAll("(?s).*\"approvalId\"\\s*:\\s*\"([^\"]+)\".*", "$1");
    org.junit.jupiter.api.Assertions.assertNotEquals(
        body, id, "expected a pending approval, got: " + body);
    return id;
  }

  @Test
  void anonymousActionIsRejected() throws Exception {
    mvc.perform(post("/agentic/v1/actions")
            .contentType(MediaType.APPLICATION_JSON)
            .content("""
                {"agent_id":"sa-opensre","action":"diag.read","target":"rio-lab-ssh",
                 "incident_id":"INC-X"}
                """))
        .andExpect(status().isUnauthorized());
  }

  @Test
  void anonymousKillSwitchIsRejected() throws Exception {
    mvc.perform(post("/agentic/v1/kill-switch")
            .contentType(MediaType.APPLICATION_JSON)
            .content("""
                {"agent_id":"sa-opensre","reason":"anyone"}
                """))
        .andExpect(status().isUnauthorized());
  }

  @Test
  void agentCannotApproveItsOwnAction() throws Exception {
    String id = pendingApprovalId();

    mvc.perform(post("/agentic/v1/approvals/" + id + "/approve")
            .header("Authorization", AGENT)
            .header("X-ArchGate-Actor", "sa-opensre")
            .contentType(MediaType.APPLICATION_JSON)
            .content("""
                {"reason":"self-approval attempt"}
                """))
        .andExpect(status().isForbidden());

    // Still pending — the attempt changed nothing.
    mvc.perform(get("/agentic/v1/approvals/" + id)
            .header("Authorization", APPROVER))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.state").value("PENDING"));
  }

  @Test
  void agentCannotDeny() throws Exception {
    String id = pendingApprovalId();
    mvc.perform(post("/agentic/v1/approvals/" + id + "/deny")
            .header("Authorization", AGENT)
            .header("X-ArchGate-Actor", "sa-opensre")
            .contentType(MediaType.APPLICATION_JSON)
            .content("{}"))
        .andExpect(status().isForbidden());
  }

  @Test
  void agentCannotTripKillSwitch() throws Exception {
    mvc.perform(post("/agentic/v1/kill-switch")
            .header("Authorization", AGENT)
            .header("X-ArchGate-Actor", "sa-opensre")
            .contentType(MediaType.APPLICATION_JSON)
            .content("""
                {"agent_id":"sa-opensre","reason":"agent tries"}
                """))
        .andExpect(status().isForbidden());
  }

  @Test
  void spoofedAgentIdIsRejected() throws Exception {
    mvc.perform(post("/agentic/v1/actions")
            .header("Authorization", AGENT)
            .contentType(MediaType.APPLICATION_JSON)
            .content("""
                {"agent_id":"sa-someone-else","action":"diag.read",
                 "target":"rio-lab-ssh","incident_id":"INC-SPOOF"}
                """))
        .andExpect(status().isForbidden());
  }

  @Test
  void approverMustDeclareAnActor() throws Exception {
    String id = pendingApprovalId();
    mvc.perform(post("/agentic/v1/approvals/" + id + "/approve")
            .header("Authorization", APPROVER)
            .contentType(MediaType.APPLICATION_JSON)
            .content("{}"))
        .andExpect(status().isBadRequest());
  }

  @Test
  void healthProbeStaysOpen() throws Exception {
    mvc.perform(get("/actuator/health"))
        .andExpect(status().isOk());
  }
}
