package br.com.integralltech.archgate.orchestration.api;

import br.com.integralltech.archgate.orchestration.domain.OrchestrationResult;
import br.com.integralltech.archgate.orchestration.adapter.ArchGuardLiveAdapter;
import br.com.integralltech.archgate.orchestration.adapter.ArchGuardSessionContext;
import br.com.integralltech.archgate.orchestration.service.LifecycleService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

/**
 * Contracts: documentos/runbooks/orchestration-api-contracts.md
 */
@RestController
@RequestMapping("/orchestration/v1")
public class OrchestrationController {

  private final LifecycleService lifecycle;
  private final ArchGuardLiveAdapter archGuard;

  public OrchestrationController(LifecycleService lifecycle, ArchGuardLiveAdapter archGuard) {
    this.lifecycle = lifecycle;
    this.archGuard = archGuard;
  }

  public record ProvisionRequest(
      @NotBlank String tenant_slug,
      @NotBlank String username,
      String email,
      String profile,
      List<String> groups
  ) {}

  public record GrantRequest(
      @NotBlank String username,
      @NotBlank String target,
      String ttl
  ) {}

  public record RevokeRequest(
      @NotBlank String username,
      String reason
  ) {}

  @PostMapping("/users/provision")
  public OrchestrationResult provision(@Valid @RequestBody ProvisionRequest req) {
    return lifecycle.provision(
        req.tenant_slug(),
        req.username(),
        req.email(),
        req.profile(),
        req.groups()
    );
  }

  @PostMapping("/access/grant")
  public OrchestrationResult grant(@Valid @RequestBody GrantRequest req) {
    return lifecycle.grant(req.username(), req.target(), req.ttl());
  }

  @PostMapping("/users/revoke")
  public OrchestrationResult revoke(@Valid @RequestBody RevokeRequest req) {
    return lifecycle.revoke(req.username(), req.reason());
  }

  @PostMapping("/tenants/sync")
  public OrchestrationResult syncTenants() {
    return lifecycle.syncTenants();
  }

  @PostMapping("/identities/session-context")
  public ArchGuardSessionContext sessionContext(@Valid @RequestBody SessionContextRequest req) {
    return archGuard.resolveSessionContext(req.subject());
  }

  public record SessionContextRequest(@NotBlank String subject) {}

  @GetMapping("/status/last")
  public ResponseEntity<OrchestrationResult> lastGlobal() {
    OrchestrationResult r = lifecycle.lastGlobal();
    if (r == null) {
      return ResponseEntity.noContent().build();
    }
    return ResponseEntity.ok(r);
  }

  @GetMapping("/status/users/{username}")
  public ResponseEntity<OrchestrationResult> lastUser(@PathVariable String username) {
    OrchestrationResult r = lifecycle.lastFor(username);
    if (r == null) {
      return ResponseEntity.noContent().build();
    }
    return ResponseEntity.ok(r);
  }
}
