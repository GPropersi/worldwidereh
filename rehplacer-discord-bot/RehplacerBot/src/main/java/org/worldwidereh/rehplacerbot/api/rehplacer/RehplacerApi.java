package org.worldwidereh.rehplacerbot.api.rehplacer;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.*;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestTemplate;
import org.springframework.web.client.UnknownContentTypeException;

import java.util.HashMap;
import java.util.Map;


@Component
public final class RehplacerApi {

    private final RestTemplate restTemplate;
    private final String REHPLACER_API_URL = "https://rehplacer.propersi.me";
    private final String CF_CLIENT_SECRET = "CF-Access-Client-Secret";
    private final String CF_CLIENT_ID = "CF-Access-Client-Id";
    private final String BODY_KEY = "rehgularText";
    private final String GENERAL_ERROR_MESSAGE  = "Unable to reh-ify. Please treh again.";
    private final String TOO_MANY_REH  = "Slow down your reh's.";

    @Value("${cf.client.secret}")
    private String cfClientSecret;
    @Value("${cf.client.id}")
    private String cfClientId;

    public RehplacerApi(RestTemplate restTemplate) {
        this.restTemplate = restTemplate;
    }

    public RehToDiscordDto rehquestRehplacement(String orehginal) {
        Map<String, String> body = Map.of(BODY_KEY, orehginal);
        HttpHeaders headers = buildHeaders();
        HttpEntity<Map<String, String>> httpEntity = buildEntity(headers, body);

        try {
            ResponseEntity<RehFromApiDto> response = restTemplate.exchange(
                    REHPLACER_API_URL,
                    HttpMethod.POST,
                    httpEntity,
                    RehFromApiDto.class);

            int statusCode = response.getStatusCode().value();

            switch (statusCode) {
                case 200:
                    if (response.getBody() != null) {
                        return new RehToDiscordDto(response.getBody().rehsponseKey(), true);
                    } break;

                case 429:
                    return new RehToDiscordDto(TOO_MANY_REH, false);
            }

            return new RehToDiscordDto (GENERAL_ERROR_MESSAGE, false);

        } catch (UnknownContentTypeException e) {
            // Handle an invalid body sent from microservice that doesn't conform to DTO
            return new RehToDiscordDto (GENERAL_ERROR_MESSAGE, false);
        }
    }

    private HttpHeaders buildHeaders() {
        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_JSON);
        headers.set(CF_CLIENT_SECRET, cfClientSecret);
        headers.set(CF_CLIENT_ID, cfClientId);

        return headers;
    }

    private HttpEntity<Map<String, String>> buildEntity(HttpHeaders headers, Map<String, String> body) {
        return new HttpEntity<>(body, headers);
    }
}
