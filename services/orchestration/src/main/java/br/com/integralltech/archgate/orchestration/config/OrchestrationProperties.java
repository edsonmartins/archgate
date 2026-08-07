package br.com.integralltech.archgate.orchestration.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "archgate.orchestration")
public record OrchestrationProperties(
    /** mode: mock | live */
    String mode,
    /** When true, live adapters log intended HTTP without calling backends. */
    boolean dryRun,
    /**
     * Shared service token required on every mutating route. No default: an
     * unset token makes the API answer 503 instead of running open to the
     * network (audit 2026-07-28, P0-3).
     */
    String apiToken,
    /** HMAC-SHA256 secret for Axis webhook bodies. Unset = webhooks refused. */
    String webhookSecret,
    Endpoint archguard,
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

  public boolean hasApiToken() {
    return apiToken != null && !apiToken.isBlank();
  }

  public boolean hasWebhookSecret() {
    return webhookSecret != null && !webhookSecret.isBlank();
  }
}
