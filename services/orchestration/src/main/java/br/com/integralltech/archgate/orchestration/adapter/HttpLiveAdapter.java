package br.com.integralltech.archgate.orchestration.adapter;

import br.com.integralltech.archgate.orchestration.config.OrchestrationProperties;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.MediaType;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientResponseException;

import java.util.List;
import java.util.Map;

/**
 * Base HTTP adapter for live platform components.
 * Credentials only from env/config (never SPA).
 * When dryRun=true or endpoint disabled → log only (safe default).
 * When live → HTTP; failures throw so LifecycleService can surface errors.
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

  protected boolean isLiveHttp() {
    return !dryRun && endpoint.usable();
  }

  protected void putJson(String path, Object body) {
    if (!isLiveHttp()) {
      log.info("[{}] dry-run PUT {} body={}", name(), path, body);
      return;
    }
    try {
      client.put()
          .uri(path)
          .contentType(MediaType.APPLICATION_JSON)
          .body(body)
          .retrieve()
          .toBodilessEntity();
      log.info("[{}] PUT {} OK", name(), path);
    } catch (RestClientResponseException e) {
      throw new OrchestrationHttpException(name(), "PUT", path, e.getStatusCode().value(), e.getResponseBodyAsString(), e);
    }
  }

  protected void postJson(String path, Object body) {
    if (!isLiveHttp()) {
      log.info("[{}] dry-run POST {} body={}", name(), path, body);
      return;
    }
    try {
      client.post()
          .uri(path)
          .contentType(MediaType.APPLICATION_JSON)
          .body(body)
          .retrieve()
          .toBodilessEntity();
      log.info("[{}] POST {} OK", name(), path);
    } catch (RestClientResponseException e) {
      throw new OrchestrationHttpException(name(), "POST", path, e.getStatusCode().value(), e.getResponseBodyAsString(), e);
    }
  }

  protected void patchJson(String path, Object body) {
    if (!isLiveHttp()) {
      log.info("[{}] dry-run PATCH {} body={}", name(), path, body);
      return;
    }
    try {
      client.patch()
          .uri(path)
          .contentType(MediaType.APPLICATION_JSON)
          .body(body)
          .retrieve()
          .toBodilessEntity();
      log.info("[{}] PATCH {} OK", name(), path);
    } catch (RestClientResponseException e) {
      throw new OrchestrationHttpException(name(), "PATCH", path, e.getStatusCode().value(), e.getResponseBodyAsString(), e);
    }
  }

  protected void delete(String path) {
    if (!isLiveHttp()) {
      log.info("[{}] dry-run DELETE {}", name(), path);
      return;
    }
    try {
      client.delete()
          .uri(path)
          .retrieve()
          .toBodilessEntity();
      log.info("[{}] DELETE {} OK", name(), path);
    } catch (RestClientResponseException e) {
      // Idempotent revoke: 404 = already gone
      if (e.getStatusCode().value() == 404) {
        log.info("[{}] DELETE {} → 404 (ok)", name(), path);
        return;
      }
      throw new OrchestrationHttpException(name(), "DELETE", path, e.getStatusCode().value(), e.getResponseBodyAsString(), e);
    }
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

  /** Typed failure for live HTTP so orchestration can mark step failed. */
  public static class OrchestrationHttpException extends RuntimeException {
    public final String component;
    public final String method;
    public final String path;
    public final int status;

    public OrchestrationHttpException(
        String component, String method, String path, int status, String body, Throwable cause) {
      super(component + " " + method + " " + path + " → HTTP " + status + ": " + truncate(body), cause);
      this.component = component;
      this.method = method;
      this.path = path;
      this.status = status;
    }

    private static String truncate(String b) {
      if (b == null) return "";
      return b.length() > 300 ? b.substring(0, 300) + "…" : b;
    }
  }
}
