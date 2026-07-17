package br.com.integralltech.archgate.oracleproxy.api;

import br.com.integralltech.archgate.oracleproxy.service.OracleUserService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import java.util.Map;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * HTTP surface used by the thin Go OpenBao dbplugin (ADR-001).
 * mTLS termination expected at Traefik / sidecar in production.
 */
@RestController
@RequestMapping("/v1/oracle")
public class PluginOpsController {

  private final OracleUserService users;

  public PluginOpsController(OracleUserService users) {
    this.users = users;
  }

  public record CreateUserRequest(
      @NotBlank String username,
      @NotBlank String password,
      String expiration,
      Map<String, String> statements) {}

  public record UpdateUserRequest(
      @NotBlank String username, String password, String expiration, Map<String, String> statements) {}

  public record DeleteUserRequest(@NotBlank String username, Map<String, String> statements) {}

  public record RotateRootRequest(@NotBlank String password) {}

  @PostMapping("/users")
  public ResponseEntity<Map<String, Object>> createUser(@Valid @RequestBody CreateUserRequest req) {
    users.createUser(req.username(), req.password(), req.expiration(), req.statements());
    return ResponseEntity.ok(Map.of("status", "ok", "username", req.username()));
  }

  @PostMapping("/users/update")
  public ResponseEntity<Map<String, Object>> updateUser(@Valid @RequestBody UpdateUserRequest req) {
    users.updateUser(req.username(), req.password(), req.expiration(), req.statements());
    return ResponseEntity.ok(Map.of("status", "ok", "username", req.username()));
  }

  @PostMapping("/users/delete")
  public ResponseEntity<Map<String, Object>> deleteUser(@Valid @RequestBody DeleteUserRequest req) {
    users.deleteUser(req.username(), req.statements());
    return ResponseEntity.ok(Map.of("status", "ok", "username", req.username()));
  }

  @PostMapping("/root/rotate")
  public ResponseEntity<Map<String, Object>> rotateRoot(@Valid @RequestBody RotateRootRequest req) {
    users.rotateRoot(req.password());
    return ResponseEntity.ok(Map.of("status", "ok"));
  }
}
