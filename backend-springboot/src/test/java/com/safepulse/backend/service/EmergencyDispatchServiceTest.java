package com.safepulse.backend.service;

import com.safepulse.backend.model.EmergencyEvent;
import com.safepulse.backend.repository.EmergencyEventRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class EmergencyDispatchServiceTest {

    @Mock
    private EmergencyEventRepository repository;

    @InjectMocks
    private EmergencyDispatchService service;

    @BeforeEach
    void setUp() {
        when(repository.save(any(EmergencyEvent.class))).thenAnswer(inv -> inv.getArgument(0));
    }

    @Test
    void dispatchEmergency_persistsEventWithCorrectFields() {
        EmergencyEvent result = service.dispatchEmergency("sos-001", 17.385, 78.4867, 80);

        assertThat(result.getEventId()).isEqualTo("sos-001");
        assertThat(result.getLatitude()).isEqualTo(17.385);
        assertThat(result.getLongitude()).isEqualTo(78.4867);
        assertThat(result.getSeverity()).isEqualTo("CRITICAL");
        assertThat(result.getPriorityScore()).isEqualTo(80);
        assertThat(result.isDispatchRecommended()).isTrue();
        assertThat(result.getStatus()).isEqualTo("DISPATCHED");
        verify(repository).save(any(EmergencyEvent.class));
    }

    @Test
    void dispatchEmergency_lowSeverityNotRecommended() {
        EmergencyEvent result = service.dispatchEmergency("sos-002", 0, 0, 20);

        assertThat(result.getSeverity()).isEqualTo("LOW");
        assertThat(result.isDispatchRecommended()).isFalse();
    }

    @Test
    void dispatchEmergency_highSeverityMapsCorrectly() {
        EmergencyEvent result = service.dispatchEmergency("sos-003", 0, 0, 60);

        assertThat(result.getSeverity()).isEqualTo("HIGH");
        assertThat(result.isDispatchRecommended()).isTrue();
    }
}
