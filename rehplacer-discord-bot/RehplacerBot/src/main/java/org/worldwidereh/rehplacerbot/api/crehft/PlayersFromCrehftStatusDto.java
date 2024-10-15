package org.worldwidereh.rehplacerbot.api.crehft;

import com.fasterxml.jackson.annotation.JsonInclude;

import java.util.List;

public final class PlayersFromCrehftStatusDto {
    private final int online;
    private final int max;

    @JsonInclude(JsonInclude.Include.NON_NULL)
    private final List<PlayerDto> list;

    public PlayersFromCrehftStatusDto(
            int online,
            int max,
            List<PlayerDto> list
    ) {
        this.online = online;
        this.max = max;
        this.list = list;
    }

    public int online() {
        return online;
    }

    public int max() {
        return max;
    }

    public List<PlayerDto> list() {
        return list;
    }
}
