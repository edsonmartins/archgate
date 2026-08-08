package br.com.integralltech.archgate.orchestration.api;

import br.com.integralltech.archgate.orchestration.adapter.HttpLiveAdapter.OrchestrationHttpException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import java.util.Map;

@RestControllerAdvice
public class ApiExceptionHandler {

  @ExceptionHandler(MethodArgumentNotValidException.class)
  public ResponseEntity<Map<String, String>> validation(MethodArgumentNotValidException ex) {
    String msg = ex.getBindingResult().getFieldErrors().stream()
        .findFirst()
        .map(f -> f.getField() + ": " + f.getDefaultMessage())
        .orElse("validation failed");
    return ResponseEntity.badRequest().body(Map.of("error", msg));
  }

  @ExceptionHandler(IllegalArgumentException.class)
  public ResponseEntity<Map<String, String>> illegal(IllegalArgumentException ex) {
    return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(Map.of("error", ex.getMessage()));
  }

  @ExceptionHandler(IllegalStateException.class)
  public ResponseEntity<Map<String, String>> unavailable(IllegalStateException ex) {
    return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE).body(Map.of("error", ex.getMessage()));
  }

  @ExceptionHandler(OrchestrationHttpException.class)
  public ResponseEntity<Map<String, String>> upstream(OrchestrationHttpException ex) {
    HttpStatus status = HttpStatus.resolve(ex.status);
    if (status == null || status.is5xxServerError()) {
      status = HttpStatus.BAD_GATEWAY;
    }
    return ResponseEntity.status(status).body(Map.of("error", "ArchGuard session-context request failed"));
  }
}
