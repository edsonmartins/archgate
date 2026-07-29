package br.com.integralltech.archgate.agentcontrol.security;

import jakarta.servlet.http.HttpServletRequest;

/**
 * The authenticated caller of an agentic control-plane request.
 *
 * <p>Identity comes from the presented credential, never from the request body
 * (CONSTITUTION §2.2 — policy is never delegated to the principal's own claim).
 */
public record Caller(Role role, String agentId) {

  public enum Role {
    /** The agent service account (OpenSRE). May request sessions and actions. */
    AGENT,
    /** The human/ops plane. May approve, deny and trip the kill-switch. */
    APPROVER
  }

  /** Request attribute under which the filter publishes the caller. */
  public static final String ATTRIBUTE = "archgate.caller";

  public boolean isApprover() {
    return role == Role.APPROVER;
  }

  /** Reads the caller published by {@code AgentAuthFilter}. Never null post-filter. */
  public static Caller of(HttpServletRequest request) {
    Object attr = request.getAttribute(ATTRIBUTE);
    if (attr instanceof Caller c) {
      return c;
    }
    throw new IllegalStateException("no authenticated caller on request");
  }
}
