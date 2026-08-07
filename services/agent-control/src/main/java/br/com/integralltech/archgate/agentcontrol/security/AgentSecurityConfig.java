package br.com.integralltech.archgate.agentcontrol.security;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.web.servlet.FilterRegistrationBean;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.Ordered;

@Configuration
public class AgentSecurityConfig {

  private static final Logger log = LoggerFactory.getLogger(AgentSecurityConfig.class);

  @Bean
  public FilterRegistrationBean<AgentAuthFilter> agentAuthFilter(
      @Value("${archgate.agent.api-token:}") String agentToken,
      @Value("${archgate.agent.approver-token:}") String approverToken,
      @Value("${archgate.agent.default-agent-id:sa-opensre}") String agentId) {

    if (agentToken.isBlank() && approverToken.isBlank()) {
      log.error(
          "archgate.agent.api-token / approver-token are unset — "
              + "the agentic API will answer 503 until they are configured");
    } else if (approverToken.isBlank()) {
      log.warn(
          "archgate.agent.approver-token is unset — HITL approval and kill-switch "
              + "are unavailable (they never accept the agent credential)");
    } else if (agentToken.equals(approverToken)) {
      log.error(
          "agent and approver tokens are identical — HITL separation is void; "
              + "configure distinct secrets");
    }

    FilterRegistrationBean<AgentAuthFilter> reg = new FilterRegistrationBean<>();
    reg.setFilter(new AgentAuthFilter(agentToken, approverToken, agentId));
    reg.addUrlPatterns("/*");
    reg.setOrder(Ordered.HIGHEST_PRECEDENCE);
    return reg;
  }
}
