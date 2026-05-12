package com.safepulse.backend.controller;

import java.util.LinkedHashMap;
import java.util.Map;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class TestController {

    @GetMapping("/")
    public String home() {
        return "SafePulse Backend Running";
    }

    @GetMapping("/health")
    public ResponseEntity<Map<String, Object>> health() {
        Map<String, Object> status = new LinkedHashMap<>();
        status.put("service", "emergency-service");
        status.put("status", "ok");
        status.put("db", "mongodb");
        return ResponseEntity.ok(status);
    }
}
