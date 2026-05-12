package com.safepulse.backend.repository;

import com.safepulse.backend.model.EmergencyEvent;
import java.util.List;
import java.util.Optional;
import org.springframework.data.mongodb.repository.MongoRepository;

public interface EmergencyEventRepository extends MongoRepository<EmergencyEvent, String> {
    Optional<EmergencyEvent> findByEventId(String eventId);

    List<EmergencyEvent> findByStatusOrderByCreatedAtDesc(String status);
}
