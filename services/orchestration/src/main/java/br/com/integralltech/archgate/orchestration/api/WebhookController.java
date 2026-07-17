package br.com.integralltech.archgate.orchestration.api;

import br.com.integralltech.archgate.orchestration.domain.OrchestrationResult;
import br.com.integralltech.archgate.orchestration.service.IdempotencyStore;
import br.com.integralltech.archgate.orchestration.service.LifecycleService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Map;

/**
 * Axis → ArchGate webhooks with Idempotency-Key (W4-ORCH05).
 */
@RestController
@RequestMapping("/orchestration/v1/webhooks")
public class WebhookController {

  private final LifecycleService lifecycle;
  private final IdempotencyStore idempotency;

  public WebhookController(LifecycleService lifecycle, IdempotencyStore idempotency) {
    this.lifecycle = lifecycle;
    this.idempotency = idempotency;
  }

  public record AxisEvent(
      @NotBlank String event,
      String username,
      String tenant_slug,
      String email,
      String profile,
      String target,
      String ttl,
      String reason,
      List<String> groups,
      Map<String, Object> payload
  ) {}

  @PostMapping("/axis")
  public ResponseEntity<OrchestrationResult> axis(
      @RequestHeader(value = "Idempotency-Key", required = false) String idemKey,
      @Valid @RequestBody AxisEvent body
  ) {
    if (idemKey != null && !idemKey.isBlank()) {
      var cached = idempotency.get(idemKey);
      if (cached.isPresent()) {
        return ResponseEntity.ok(cached.get());
      }
    }

    OrchestrationResult result = dispatch(body);
    if (idemKey != null) {
      idempotency.put(idemKey, result);
    }
    return ResponseEntity.ok(result);
  }

  private OrchestrationResult dispatch(AxisEvent body) {
    String event = body.event().toLowerCase();
    return switch (event) {
      case "user.provision", "users.provision", "person.create" -> lifecycle.provision(
          body.tenant_slug() != null ? body.tenant_slug() : "default",
          requireUser(body),
          body.email(),
          body.profile(),
          body.groups()
      );
      case "access.grant", "user.grant" -> lifecycle.grant(
          requireUser(body),
          body.target() != null ? body.target() : "",
          body.ttl()
      );
      case "user.offboard", "user.revoke", "users.revoke", "person.delete" -> lifecycle.revoke(
          requireUser(body),
          body.reason() != null ? body.reason() : "axis-webhook"
      );
      case "tenants.sync" -> lifecycle.syncTenants();
      default -> throw new IllegalArgumentException("unknown event: " + body.event());
    };
  }

  private static String requireUser(AxisEvent body) {
    if (body.username() == null || body.username().isBlank()) {
      throw new IllegalArgumentException("username required for event " + body.event());
    }
    return body.username();
  }
}
