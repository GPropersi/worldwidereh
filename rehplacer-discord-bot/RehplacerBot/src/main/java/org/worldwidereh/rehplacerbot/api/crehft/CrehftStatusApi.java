package org.worldwidereh.rehplacerbot.api.crehft;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.*;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestTemplate;
import org.springframework.web.client.UnknownContentTypeException;


@Component
public final class CrehftStatusApi {

    private static final Logger log = LoggerFactory.getLogger(CrehftStatusApi.class);

    private final RestTemplate restTemplate;
    private final String REHPLACER_API_URL = "https://api.mcsrvstat.us/3/";

    @Value("${crehft.url}")
    private String crehftUrl;

    public CrehftStatusApi(RestTemplate restTemplate) {
        this.restTemplate = restTemplate;
    }

    public CrehftStatusFromApiDto getCrehftStatus() throws UnknownContentTypeException {
        try {
            log.info("Trying for a crehft status...");
            ResponseEntity<CrehftStatusFromApiDto> responseEntity = restTemplate.exchange(
                    REHPLACER_API_URL + crehftUrl,
                    HttpMethod.GET,
                    null,
                    CrehftStatusFromApiDto.class);

            int statusCode = responseEntity.getStatusCode().value();

            if (statusCode == 200) {
                log.debug("Crehft status succeeded!");
                return responseEntity.getBody();
            }
            log.debug("Crehft status failed, status code: " + statusCode);
            return new CrehftStatusFromApiDto(false, null, false);

        } catch (UnknownContentTypeException e) {
            // Handle an invalid body sent from microservice that doesn't conform to DTO
            log.debug("Crehft status failed with unknown content type exception!");
            return new CrehftStatusFromApiDto (false, null, false);
        }
    }
}
