package br.com.integralltech.archgate.orchestration.adapter;

import java.util.List;
import java.util.UUID;
import com.fasterxml.jackson.annotation.JsonProperty;

/** Identity and tenant memberships resolved by ArchGuard's service API. */
public record ArchGuardSessionContext(
    String subject,
    @JsonProperty("identity_id")
    UUID identityId,
    @JsonProperty("identity_status")
    String identityStatus,
    List<Membership> memberships
) {
  public record Membership(
      @JsonProperty("membership_id") UUID membershipId,
      @JsonProperty("organization_id") UUID organizationId,
      String status
  ) {}
}
