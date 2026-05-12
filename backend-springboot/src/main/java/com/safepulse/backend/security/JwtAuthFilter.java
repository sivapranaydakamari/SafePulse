package com.safepulse.backend.security;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.Arrays;
import java.util.Base64;
import java.util.Collections;

@Component
public class JwtAuthFilter extends OncePerRequestFilter {

    private final String jwtSecret;

    public JwtAuthFilter(@Value("${jwt.secret}") String jwtSecret) {
        this.jwtSecret = jwtSecret;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request,
                                    HttpServletResponse response,
                                    FilterChain filterChain)
            throws ServletException, IOException {

        // Skip if already authenticated (e.g., tests using @WithMockUser)
        if (SecurityContextHolder.getContext().getAuthentication() != null) {
            filterChain.doFilter(request, response);
            return;
        }

        String authHeader = request.getHeader("Authorization");
        if (authHeader != null && authHeader.startsWith("Bearer ")) {
            String token = authHeader.substring(7);
            if (isValidToken(token)) {
                String subject = extractSubject(token);
                UsernamePasswordAuthenticationToken auth =
                        new UsernamePasswordAuthenticationToken(
                                subject, null,
                                Collections.singletonList(new SimpleGrantedAuthority("ROLE_USER")));
                SecurityContextHolder.getContext().setAuthentication(auth);
            }
        }

        filterChain.doFilter(request, response);
    }

    private boolean isValidToken(String token) {
        try {
            String[] parts = token.split("\\.");
            if (parts.length != 3) return false;
            String signingInput = parts[0] + "." + parts[1];
            byte[] expectedSig = hmacSha256(signingInput, jwtSecret);
            byte[] actualSig = base64UrlDecode(parts[2]);
            return Arrays.equals(expectedSig, actualSig);
        } catch (Exception e) {
            return false;
        }
    }

    private String extractSubject(String token) {
        try {
            String[] parts = token.split("\\.");
            String payload = new String(base64UrlDecode(parts[1]), StandardCharsets.UTF_8);
            // Extract "userId" field from JSON payload
            int idx = payload.indexOf("\"userId\"");
            if (idx >= 0) {
                int start = idx + 8;
                while (start < payload.length() && (payload.charAt(start) == ':' || payload.charAt(start) == '"' || payload.charAt(start) == ' ')) start++;
                int end = start;
                while (end < payload.length() && payload.charAt(end) != '"' && payload.charAt(end) != ',' && payload.charAt(end) != '}') end++;
                return payload.substring(start, end);
            }
            return "unknown";
        } catch (Exception e) {
            return "unknown";
        }
    }

    private byte[] hmacSha256(String data, String secret) throws Exception {
        Mac mac = Mac.getInstance("HmacSHA256");
        mac.init(new SecretKeySpec(secret.getBytes(StandardCharsets.UTF_8), "HmacSHA256"));
        return mac.doFinal(data.getBytes(StandardCharsets.UTF_8));
    }

    private byte[] base64UrlDecode(String input) {
        String padded = input.replace('-', '+').replace('_', '/');
        switch (padded.length() % 4) {
            case 2: padded += "=="; break;
            case 3: padded += "="; break;
            default: break;
        }
        return Base64.getDecoder().decode(padded);
    }
}
