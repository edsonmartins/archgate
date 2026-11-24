package br.com.integralltech.archgate.orchestration.adapter;

import br.com.integralltech.archgate.orchestration.config.OrchestrationProperties;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.MediaType;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientResponseException;
import org.springframework.http.client.SimpleClientHttpRequestFactory;

import java.util.List;
import java.util.Map;
import java.util.function.Supplier;

/**
 * Base HTTP adapter for live platform components.
 * Credentials only from env/config (never SPA).
 * When dryRun=true or endpoint disabled → log only (safe default).
 * When live → HTTP; failures throw so LifecycleService can surface errors.
 */
public abstract class HttpLiveAdapter implements ComponentAdapter {

  private static final int MAX_ATTEMPTS = 3;
  private static final long RETRY_BACKOFF_MS = 100L;
  private static final int DEFAULT_HTTP_TIMEOUT_MS = 10_000;
  private static final int MIN_HTTP_TIMEOUT_MS = 100;
  private static final int MAX_HTTP_TIMEOUT_MS = 120_000;

  protected final Logger log = LoggerFactory.getLogger(getClass());
  protected final OrchestrationProperties.Endpoint endpoint;
  protected final boolean dryRun;
  protected final RestClient client;

  protected HttpLiveAdapter(OrchestrationProperties.Endpoint endpoint, boolean dryRun) {
    this.endpoint = endpoint;
    this.dryRun = dryRun;
    SimpleClientHttpRequestFactory requestFactory = new SimpleClientHttpRequestFactory();
    int timeoutMs = configuredTimeoutMs();
    requestFactory.setConnectTimeout(timeoutMs);
    requestFactory.setReadTimeout(timeoutMs);
    this.client = RestClient.builder()
        .requestFactory(requestFactory)
        .baseUrl(endpoint.baseUrl() != null ? endpoint.baseUrl().replaceAll("/$", "") : "http://localhost")
        .defaultHeader("Authorization",
            endpoint.token() != null && !endpoint.token().isBlank()
                ? "Bearer " + endpoint.token()
                : "")
        .build();
  }

  private static int configuredTimeoutMs() {
    String raw = System.getenv("ORCH_HTTP_TIMEOUT_MS");
    if (raw == null || raw.isBlank()) return DEFAULT_HTTP_TIMEOUT_MS;
    try {
      int value = Integer.parseInt(raw.trim());
      return Math.max(MIN_HTTP_TIMEOUT_MS, Math.min(MAX_HTTP_TIMEOUT_MS, value));
    } catch (NumberFormatException ignored) {
      return DEFAULT_HTTP_TIMEOUT_MS;
    }
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
      retry(() -> client.put().uri(path).contentType(MediaType.APPLICATION_JSON)
          .body(body).retrieve().toBodilessEntity());
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
      retry(() -> client.post().uri(path).contentType(MediaType.APPLICATION_JSON)
          .body(body).retrieve().toBodilessEntity());
      log.info("[{}] POST {} OK", name(), path);
    } catch (RestClientResponseException e) {
      throw new OrchestrationHttpException(name(), "POST", path, e.getStatusCode().value(), e.getResponseBodyAsString(), e);
    }
  }

  protected <T> T postJson(String path, Object body, Class<T> responseType) {
    if (!isLiveHttp()) {
      log.info("[{}] dry-run POST {} body={}", name(), path, body);
      return null;
    }
    try {
      return retry(() -> client.post().uri(path).contentType(MediaType.APPLICATION_JSON)
          .body(body).retrieve().body(responseType));
    } catch (RestClientResponseException e) {
      throw new OrchestrationHttpException(name(), "POST", path, e.getStatusCode().value(), e.getResponseBodyAsString(), e);
    }
  }

  /** Read-only calls remain available in dry-run; only mutating adapters are suppressed. */
  protected <T> T postJsonReadOnly(String path, Object body, Class<T> responseType) {
    if (endpoint == null || !endpoint.usable()) {
      log.info("[{}] unavailable POST {} body={}", name(), path, body);
      return null;
    }
    try {
      return client.post()
          .uri(path)
          .contentType(MediaType.APPLICATION_JSON)
          .body(body)
          .retrieve()
          .body(responseType);
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
      retry(() -> client.patch().uri(path).contentType(MediaType.APPLICATION_JSON)
          .body(body).retrieve().toBodilessEntity());
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
      retry(() -> client.delete().uri(path).retrieve().toBodilessEntity());
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

  private <T> T retry(Supplier<T> request) {
    RestClientResponseException last = null;
    for (int attempt = 1; attempt <= MAX_ATTEMPTS; attempt++) {
      try {
        return request.get();
      } catch (RestClientResponseException e) {
        last = e;
        if (!isRetryable(e) || attempt == MAX_ATTEMPTS) {
          throw e;
        }
        try {
          Thread.sleep(RETRY_BACKOFF_MS * attempt);
        } catch (InterruptedException interrupted) {
          Thread.currentThread().interrupt();
          throw e;
        }
      }
    }
    throw last;
  }

  private static boolean isRetryable(RestClientResponseException e) {
    int status = e.getStatusCode().value();
    return status == 429 || status >= 500;
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
