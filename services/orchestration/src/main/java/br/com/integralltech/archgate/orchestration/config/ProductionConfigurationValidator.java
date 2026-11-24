package br.com.integralltech.archgate.orchestration.config;

import jakarta.annotation.PostConstruct;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Component;

import java.util.ArrayList;
import java.util.List;

@Component
@Profile("production")
public class ProductionConfigurationValidator {

  private final OrchestrationProperties properties;

  public ProductionConfigurationValidator(OrchestrationProperties properties) {
    this.properties = properties;
  }

  @PostConstruct
  void validate() {
    List<String> missing = new ArrayList<>();
    if (!properties.isLive()) missing.add("archgate.orchestration.mode=live");
    if (properties.dryRun()) missing.add("archgate.orchestration.dry-run=false");
    if (!properties.hasApiToken()) missing.add("ORCH_API_TOKEN");
    if (!properties.hasWebhookSecret()) missing.add("ORCH_WEBHOOK_SECRET");
    if (!properties.webhookReplayProtection()) {
      missing.add("ORCH_WEBHOOK_REPLAY_PROTECTION=true");
    }
    validateEndpoint("ARCHGUARD", properties.archguard(), missing);
    validateEndpoint("WARPGATE", properties.warpgate(), missing);
    validateEndpoint("GUACAMOLE", properties.guacamole(), missing);
    validateEndpoint("OPENBAO", properties.openbao(), missing);
    if (!missing.isEmpty()) {
      throw new IllegalStateException("Invalid production orchestration configuration; missing or unsafe: "
          + String.join(", ", missing));
    }
  }

  private static void validateEndpoint(String name, OrchestrationProperties.Endpoint endpoint,
                                       List<String> missing) {
    if (endpoint == null || !endpoint.enabled()) {
      missing.add("ORCH_" + name + "_ENABLED=true");
      return;
    }
    if (endpoint.baseUrl() == null || endpoint.baseUrl().isBlank()) {
      missing.add("ORCH_" + name + "_URL");
    }
    if (endpoint.token() == null || endpoint.token().isBlank()) {
      missing.add("ORCH_" + name + "_TOKEN");
    }
  }
}
