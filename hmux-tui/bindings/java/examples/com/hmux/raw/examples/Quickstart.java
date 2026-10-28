package com.hmux.raw.examples;

import com.hmux.raw.HmuxClient;
import com.hmux.raw.UInt64;
import com.hmux.raw.IdentifyResult;
import com.hmux.raw.ReadScreenRequest;
import com.hmux.raw.SendRequest;

public final class Quickstart {
    private Quickstart() {}

    public static void main(String[] args) throws Exception {
        try (HmuxClient client = HmuxClient.builder().build()) {
            IdentifyResult server = client.identify();
            System.out.println("hmux protocol " + server.protocol());

            UInt64 surface = UInt64.parse(args[0]);
            client.send(
                SendRequest.builder()
                    .surface(surface)
                    .text("printf 'hello from Java\\r'")
                    .build()
            );
            System.out.println(
                client.readScreen(ReadScreenRequest.builder().surface(surface).build()).text()
            );
        }
    }
}
