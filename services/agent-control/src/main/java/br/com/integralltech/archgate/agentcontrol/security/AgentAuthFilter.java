package br.com.integralltech.archgate.agentcontrol.security;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;

/**
 * Authenticates the agentic control plane and separates the agent credential
 * from the approver credential.
 *
 * <p>Before the 2026-07-28 audit (P1-2) every route was anonymous and the
 * caller declared its own {@code agent_id}, so anything that could reach the
 * port could submit actions, approve them and disable the kill-switch. That
 * defeats HITL entirely.
 *
 * <p>Rules:
 * <ul>
 *   <li>Health/info probes pass through.</li>
 *   <li>No credential configured at all → 503 (fail closed).</li>
 *   <li>Approve, deny and kill-switch require {@code AGENT_APPROVER_TOKEN};
 *       the agent token is rejected with 403 on those routes.</li>
 * </ul>
 */
public class AgentAuthFilter extends OncePerRequestFilter {

  private static final Logger log = LoggerFactory.getLogger(AgentAuthFilter.class);

  private final String agentToken;
  private final String approverToken;
  private final String agentId;

  public AgentAuthFilter(String agentToken, String approverToken, String agentId) {
    this.agentToken = agentToken;
    this.approverToken = approverToken;
    this.agentId = agentId;
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

    if (blank(agentToken) && blank(approverToken)) {
      log.error(
          "AGENT_API_TOKEN/AGENT_APPROVER_TOKEN unset — refusing {} {} (fail-closed)",
          request.getMethod(),
          request.getRequestURI());
      deny(response, 503, "agent control plane credentials not configured");
      return;
    }

    String presented = bearerOf(request);
    Caller caller;
    if (!blank(approverToken) && constantTimeEquals(presented, approverToken)) {
      caller = new Caller(Caller.Role.APPROVER, agentId);
    } else if (!blank(agentToken) && constantTimeEquals(presented, agentToken)) {
      caller = new Caller(Caller.Role.AGENT, agentId);
    } else {
      deny(response, 401, "invalid or missing credential");
      return;
    }

    if (requiresApprover(request) && !caller.isApprover()) {
      log.warn(
          "agent credential attempted an approver-only route: {} {}",
          request.getMethod(),
          request.getRequestURI());
      deny(response, 403, "approver credential required");
      return;
    }

    request.setAttribute(Caller.ATTRIBUTE, caller);
    chain.doFilter(request, response);
  }

  /** Approve / deny / kill-switch belong to the human plane only. */
  private static boolean requiresApprover(HttpServletRequest request) {
    if (!"POST".equalsIgnoreCase(request.getMethod())) {
      return false;
    }
    String path = request.getRequestURI();
    return path.startsWith("/agentic/v1/kill-switch")
        || path.endsWith("/approve")
        || path.endsWith("/deny");
  }

  private static boolean blank(String s) {
    return s == null || s.isBlank();
  }

  private static boolean constantTimeEquals(String a, String b) {
    if (blank(a) || blank(b)) {
      return false;
    }
    return MessageDigest.isEqual(
        a.getBytes(StandardCharsets.UTF_8), b.getBytes(StandardCharsets.UTF_8));
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
