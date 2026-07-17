package br.com.integralltech.archgate.orchestration.adapter;

import br.com.integralltech.archgate.orchestration.config.OrchestrationProperties;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.MediaType;
import org.springframework.web.client.RestClient;

import java.util.List;
import java.util.Map;

/**
 * Base HTTP adapter for live platform components.
 * Credentials only from env/config (never SPA).
 */
public abstract class HttpLiveAdapter implements ComponentAdapter {

  protected final Logger log = LoggerFactory.getLogger(getClass());
  protected final OrchestrationProperties.Endpoint endpoint;
  protected final boolean dryRun;
  protected final RestClient client;

  protected HttpLiveAdapter(OrchestrationProperties.Endpoint endpoint, boolean dryRun) {
    this.endpoint = endpoint;
    this.dryRun = dryRun;
    this.client = RestClient.builder()
        .baseUrl(endpoint.baseUrl() != null ? endpoint.baseUrl().replaceAll("/$", "") : "http://localhost")
        .defaultHeader("Authorization",
            endpoint.token() != null && !endpoint.token().isBlank()
                ? "Bearer " + endpoint.token()
                : "")
        .build();
  }

  protected void putJson(String path, Object body) {
    if (dryRun || !endpoint.usable()) {
      log.info("[{}] dry-run PUT {} body={}", name(), path, body);
      return;
    }
    client.put()
        .uri(path)
        .contentType(MediaType.APPLICATION_JSON)
        .body(body)
        .retrieve()
        .toBodilessEntity();
  }

  protected void postJson(String path, Object body) {
    if (dryRun || !endpoint.usable()) {
      log.info("[{}] dry-run POST {} body={}", name(), path, body);
      return;
    }
    client.post()
        .uri(path)
        .contentType(MediaType.APPLICATION_JSON)
        .body(body)
        .retrieve()
        .toBodilessEntity();
  }

  protected void patchJson(String path, Object body) {
    if (dryRun || !endpoint.usable()) {
      log.info("[{}] dry-run PATCH {} body={}", name(), path, body);
      return;
    }
    client.patch()
        .uri(path)
        .contentType(MediaType.APPLICATION_JSON)
        .body(body)
        .retrieve()
        .toBodilessEntity();
  }

  protected void delete(String path) {
    if (dryRun || !endpoint.usable()) {
      log.info("[{}] dry-run DELETE {}", name(), path);
      return;
    }
    client.delete()
        .uri(path)
        .retrieve()
        .toBodilessEntity();
  }

  @Override
  public void ensurePerson(String username, String email, List<String> groups) {
    // default no-op; override per component
  }

  @Override
  public void grantAccess(String username, String target, String ttl) {
    // default no-op
  }

  @Override
  public void expirePerson(String username) {
    revokeAll(username);
  }

  protected Map<String, Object> personBody(String username, String email, List<String> groups) {
    return Map.of(
        "username", username,
        "email", email != null ? email : "",
        "groups", groups != null ? groups : List.of()
    );
  }
}
