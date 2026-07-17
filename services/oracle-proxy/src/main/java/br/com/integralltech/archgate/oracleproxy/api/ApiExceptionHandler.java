package br.com.integralltech.archgate.oracleproxy.api;

import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

@RestControllerAdvice
public class ApiExceptionHandler {

  @ExceptionHandler(IllegalArgumentException.class)
  public ResponseEntity<Map<String, String>> badRequest(IllegalArgumentException ex) {
    return ResponseEntity.status(HttpStatus.BAD_REQUEST)
        .body(Map.of("status", "error", "message", ex.getMessage()));
  }

  @ExceptionHandler(UnsupportedOperationException.class)
  public ResponseEntity<Map<String, String>> notImplemented(UnsupportedOperationException ex) {
    return ResponseEntity.status(HttpStatus.NOT_IMPLEMENTED)
        .body(Map.of("status", "error", "message", ex.getMessage()));
  }
}
