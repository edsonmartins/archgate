package br.com.integralltech.archgate.orchestration.security;

import jakarta.servlet.ReadListener;
import jakarta.servlet.ServletInputStream;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletRequestWrapper;

import java.io.BufferedReader;
import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;

/**
 * Buffers the request body so the webhook signature can be computed over the
 * exact bytes received and the controller can still deserialize them.
 */
final class CachedBodyRequest extends HttpServletRequestWrapper {

  private final byte[] body;

  CachedBodyRequest(HttpServletRequest request) throws IOException {
    super(request);
    this.body = request.getInputStream().readAllBytes();
  }

  byte[] body() {
    return body;
  }

  @Override
  public ServletInputStream getInputStream() {
    ByteArrayInputStream buffer = new ByteArrayInputStream(body);
    return new ServletInputStream() {
      @Override
      public boolean isFinished() {
        return buffer.available() == 0;
      }

      @Override
      public boolean isReady() {
        return true;
      }

      @Override
      public void setReadListener(ReadListener listener) {
        throw new UnsupportedOperationException("async reads not supported");
      }

      @Override
      public int read() {
        return buffer.read();
      }
    };
  }

  @Override
  public BufferedReader getReader() {
    return new BufferedReader(
        new InputStreamReader(getInputStream(), StandardCharsets.UTF_8));
  }
}
