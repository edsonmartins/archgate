package br.com.integralltech.archgate.agentcontrol.security;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Component;

import jakarta.annotation.PostConstruct;

@Component
@Profile("production")
public class ProductionSecurityValidator {

  private final String agentToken;
  private final String approverToken;

  public ProductionSecurityValidator(
      @Value("${archgate.agent.api-token:}") String agentToken,
      @Value("${archgate.agent.approver-token:}") String approverToken) {
    this.agentToken = agentToken;
    this.approverToken = approverToken;
  }

  @PostConstruct
  public void validate() {
    if (agentToken == null || agentToken.isBlank()
        || approverToken == null || approverToken.isBlank()) {
      throw new IllegalStateException(
          "Production requires distinct AGENT_API_TOKEN and AGENT_APPROVER_TOKEN");
    }
    if (agentToken.equals(approverToken)) {
      throw new IllegalStateException(
          "Production requires AGENT_API_TOKEN and AGENT_APPROVER_TOKEN to be distinct");
    }
  }
}
