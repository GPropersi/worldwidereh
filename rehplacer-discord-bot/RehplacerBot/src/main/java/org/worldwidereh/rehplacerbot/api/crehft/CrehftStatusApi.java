package org.worldwidereh.rehplacerbot.api.crehft;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.*;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestTemplate;
import org.springframework.web.client.UnknownContentTypeException;


@Component
public final class CrehftStatusApi {

    private final RestTemplate restTemplate;
    private final String REHPLACER_API_URL = "https://api.mcsrvstat.us/3/";

    @Value("${crehft.url}")
    private String crehftUrl;

    public CrehftStatusApi(RestTemplate restTemplate) {
        this.restTemplate = restTemplate;
    }

    public CrehftStatusFromApiDto getCrehftStatus() throws UnknownContentTypeException {
        try {
            ResponseEntity<CrehftStatusFromApiDto> responseEntity = restTemplate.exchange(
                    REHPLACER_API_URL + crehftUrl,
                    HttpMethod.GET,
                    null,
                    CrehftStatusFromApiDto.class);

            int statusCode = responseEntity.getStatusCode().value();

            if (statusCode == 200) {
                return responseEntity.getBody();
            }
            return new CrehftStatusFromApiDto(false, null, false);

        } catch (UnknownContentTypeException e) {
            // Handle an invalid body sent from microservice that doesn't conform to DTO
            return new CrehftStatusFromApiDto (false, null, false);
        }
    }
}
