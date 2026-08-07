package br.com.integralltech.archgate.orchestration.security;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;

/** Constant-time comparison and HMAC helpers for service authentication. */
public final class Tokens {

  private Tokens() {}

  /** Compares two secrets without leaking length or content through timing. */
  public static boolean constantTimeEquals(String a, String b) {
    if (a == null || b == null || a.isEmpty() || b.isEmpty()) {
      return false;
    }
    byte[] x = a.getBytes(StandardCharsets.UTF_8);
    byte[] y = b.getBytes(StandardCharsets.UTF_8);
    return MessageDigest.isEqual(x, y);
  }

  /** Lowercase hex HMAC-SHA256 of {@code body} keyed by {@code secret}. */
  public static String hmacSha256Hex(String secret, byte[] body) {
    try {
      Mac mac = Mac.getInstance("HmacSHA256");
      mac.init(new SecretKeySpec(secret.getBytes(StandardCharsets.UTF_8), "HmacSHA256"));
      return toHex(mac.doFinal(body));
    } catch (Exception e) {
      throw new IllegalStateException("HMAC-SHA256 unavailable", e);
    }
  }

  private static String toHex(byte[] bytes) {
    StringBuilder sb = new StringBuilder(bytes.length * 2);
    for (byte b : bytes) {
      sb.append(Character.forDigit((b >> 4) & 0xF, 16));
      sb.append(Character.forDigit(b & 0xF, 16));
    }
    return sb.toString();
  }
}
