package br.com.integralltech.archgate.orchestration.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "archgate.orchestration")
public record OrchestrationProperties(
    /** mock | live */
    String mode,
    /** When true, live adapters log intended HTTP without calling backends. */
    boolean dryRun,
    Endpoint kanidm,
    Endpoint warpgate,
    Endpoint guacamole,
    Endpoint openbao
) {
  public record Endpoint(
      String baseUrl,
      String token,
      boolean enabled
  ) {
    public boolean usable() {
      return enabled && baseUrl != null && !baseUrl.isBlank();
    }
  }

  public boolean isLive() {
    return "live".equalsIgnoreCase(mode);
  }
}
