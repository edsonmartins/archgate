package br.com.integralltech.archgate.orchestration.security;

import br.com.integralltech.archgate.orchestration.config.OrchestrationProperties;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.nio.charset.StandardCharsets;

/**
 * Authenticates every orchestration route.
 *
 * <p>The API drives identity, gateway and secret lifecycle across Kanidm,
 * Warpgate, Guacamole and OpenBao. It previously accepted anonymous calls,
 * which contradicts CONSTITUTION §2.2 and §2.4 (audit 2026-07-28, P0-3).
 *
 * <p>Rules:
 * <ul>
 *   <li>Health/info probes pass through unauthenticated.</li>
 *   <li>No {@code ORCH_API_TOKEN} configured → every other route answers 503.
 *       Fail closed: a misconfigured deploy serves nothing rather than
 *       everything.</li>
 *   <li>Webhook routes additionally require a valid HMAC-SHA256 body
 *       signature.</li>
 * </ul>
 */
public class ServiceTokenFilter extends OncePerRequestFilter {

  private static final Logger log = LoggerFactory.getLogger(ServiceTokenFilter.class);

  /** Header carrying the hex HMAC of the raw body, optionally "sha256=" prefixed. */
  public static final String SIGNATURE_HEADER = "X-ArchGate-Signature";

  private static final String WEBHOOK_PREFIX = "/orchestration/v1/webhooks";

  private final OrchestrationProperties props;

  public ServiceTokenFilter(OrchestrationProperties props) {
    this.props = props;
  }

  @Override
  protected boolean shouldNotFilter(HttpServletRequest request) {
    String path = request.getRequestURI();
    return path.startsWith("/actuator/health") || path.startsWith("/actuator/info");
  }

  @Override
  protected void doFilterInternal(
      HttpServletRequest request, HttpServletResponse response, FilterChain chain)
      throws ServletException, IOException {

    if (!props.hasApiToken()) {
      log.error(
          "ORCH_API_TOKEN is not configured — refusing {} {} (fail-closed)",
          request.getMethod(),
          request.getRequestURI());
      deny(response, 503, "orchestration API token not configured");
      return;
    }

    if (!Tokens.constantTimeEquals(bearerOf(request), props.apiToken())) {
      deny(response, 401, "invalid or missing service token");
      return;
    }

    if (request.getRequestURI().startsWith(WEBHOOK_PREFIX)) {
      CachedBodyRequest cached = new CachedBodyRequest(request);
      if (!webhookSignatureValid(cached)) {
        deny(response, 401, "invalid or missing webhook signature");
        return;
      }
      chain.doFilter(cached, response);
      return;
    }

    chain.doFilter(request, response);
  }

  private boolean webhookSignatureValid(CachedBodyRequest request) {
    if (!props.hasWebhookSecret()) {
      log.error("ORCH_WEBHOOK_SECRET is not configured — refusing webhook (fail-closed)");
      return false;
    }
    String provided = request.getHeader(SIGNATURE_HEADER);
    if (provided == null || provided.isBlank()) {
      return false;
    }
    String expected = Tokens.hmacSha256Hex(props.webhookSecret(), request.body());
    return Tokens.constantTimeEquals(stripPrefix(provided), expected);
  }

  private static String stripPrefix(String signature) {
    String s = signature.trim();
    int eq = s.indexOf('=');
    // Accept both "sha256=<hex>" and a bare hex digest.
    return eq >= 0 && s.regionMatches(true, 0, "sha256", 0, 6) ? s.substring(eq + 1) : s;
  }

  private static String bearerOf(HttpServletRequest request) {
    String auth = request.getHeader("Authorization");
    if (auth == null) {
      return "";
    }
    String trimmed = auth.trim();
    if (trimmed.regionMatches(true, 0, "Bearer ", 0, 7)) {
      return trimmed.substring(7).trim();
    }
    return "";
  }

  private static void deny(HttpServletResponse response, int status, String message)
      throws IOException {
    response.setStatus(status);
    response.setContentType("application/json");
    response.setCharacterEncoding(StandardCharsets.UTF_8.name());
    response.getWriter().write("{\"error\":\"" + message + "\"}");
  }
}
