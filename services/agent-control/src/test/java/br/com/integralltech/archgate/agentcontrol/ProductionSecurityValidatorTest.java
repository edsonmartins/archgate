package br.com.integralltech.archgate.agentcontrol;

import br.com.integralltech.archgate.agentcontrol.security.ProductionSecurityValidator;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertThrows;

class ProductionSecurityValidatorTest {

  @Test
  void acceptsDistinctProductionCredentials() {
    assertDoesNotThrow(() -> new ProductionSecurityValidator("agent", "approver").validate());
  }

  @Test
  void rejectsMissingOrReusedCredential() {
    assertThrows(IllegalStateException.class,
        () -> new ProductionSecurityValidator("", "approver").validate());
    assertThrows(IllegalStateException.class,
        () -> new ProductionSecurityValidator("same", "same").validate());
  }
}
