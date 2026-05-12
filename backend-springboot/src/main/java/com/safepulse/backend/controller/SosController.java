package com.safepulse.backend.controller;

import com.safepulse.backend.dto.EmergencyEventResponse;
import com.safepulse.backend.dto.SosRequest;
import com.safepulse.backend.service.EmergencyResponseService;
import java.util.List;
import java.util.NoSuchElementException;
import java.util.stream.Collectors;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/sos")
public class SosController {

    private final EmergencyResponseService emergencyResponseService;

    public SosController(EmergencyResponseService emergencyResponseService) {
        this.emergencyResponseService = emergencyResponseService;
    }

    /**
     * Receives an SOS event and persists it as an {@link com.safepulse.backend.model.EmergencyEvent}.
     *
     * <p><strong>Routing note:</strong> This endpoint is reached <em>server-to-server only</em>.
     * The Flutter mobile app calls {@code POST /api/sos} on the Node.js backend (port 3001),
     * which forwards the event here internally after its own processing.
     * The API gateway routes {@code /api/emergency} to Spring Boot and all {@code /api/sos/*}
     * traffic to Node.js, so mobile clients never hit this controller directly.
     *
     * TODO (future scope): inject EmergencyDispatchService and call dispatchEmergency()
     * when SOS severity >= 4 or user has opted into government emergency notification.
     *
     * @param request   the SOS payload forwarded by the Node.js backend.
     * @param requestId the X-Request-ID header for end-to-end distributed tracing.
     * @return 201 Created with the persisted emergency event.
     */
    @PostMapping
    public ResponseEntity<EmergencyEventResponse> receiveSOS(
            @RequestBody SosRequest request,
            @RequestHeader(value = "X-Request-ID", required = false) String requestId) {
        System.out.println("[SosController] receiveSOS requestId=" + requestId);
        return ResponseEntity.status(201)
                .body(EmergencyEventResponse.from(emergencyResponseService.createEvent(request)));
    }

    @GetMapping("/{eventId}")
    public ResponseEntity<EmergencyEventResponse> getSOS(@PathVariable String eventId) {
        return ResponseEntity.ok(EmergencyEventResponse.from(emergencyResponseService.getEvent(eventId)));
    }

    @GetMapping("/active")
    public ResponseEntity<List<EmergencyEventResponse>> activeSOS() {
        List<EmergencyEventResponse> activeEvents = emergencyResponseService.getActiveEvents()
                .stream()
                .map(EmergencyEventResponse::from)
                .collect(Collectors.toList());
        return ResponseEntity.ok(activeEvents);
    }

    @PatchMapping("/{eventId}/resolve")
    public ResponseEntity<EmergencyEventResponse> resolveSOS(@PathVariable String eventId) {
        return ResponseEntity.ok(EmergencyEventResponse.from(emergencyResponseService.resolveEvent(eventId)));
    }

    @ExceptionHandler(IllegalArgumentException.class)
    public ResponseEntity<String> handleBadRequest(IllegalArgumentException error) {
        return ResponseEntity.badRequest().body(error.getMessage());
    }

    @ExceptionHandler(NoSuchElementException.class)
    public ResponseEntity<String> handleNotFound(NoSuchElementException error) {
        return ResponseEntity.status(404).body(error.getMessage());
    }
}
