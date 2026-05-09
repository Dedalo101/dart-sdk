import "dart:async";
import "dart:convert";

import "package:http/http.dart" as http;
import "package:http/testing.dart";
import "package:pocketbase/pocketbase.dart";
import "package:test/test.dart";

void main() {
  group("RealtimeService async tests", () {
    test("connect and then immediatelly disconnect", () async {
      var totalCalls = 0;

      final mock = MockClient((request) async {
        totalCalls++;
        return http.Response("", 500);
      });

      final client = PocketBase("/base", httpClientFactory: () => mock);

      await (
        client.realtime.subscribe("example", (e) {}),
        client.realtime.unsubscribe("example"),
      ).wait;

      expect(totalCalls, 0);
    });

    test("multiple consequent subscribe/unsubscribe calls", () async {
      var totalCalls = 0;
      final subscrictionCalls = <String>[];

      final streamController = StreamController<List<int>>();

      final mock = MockClient.streaming((request, bodyStream) async {
        totalCalls++;

        // connect
        if (request.method == "GET") {
          streamController.add(
            utf8.encode(
              'id:test_id\nevent:PB_CONNECT\ndata:{"clientId":"abc"}\n\n',
            ),
          );

          return http.StreamedResponse(streamController.stream, 200);
        }

        final body = await bodyStream.bytesToString();
        subscrictionCalls.add(body);

        // subscribe
        return http.StreamedResponse(Stream.fromIterable([]), 204);
      });

      final client = PocketBase("/base", httpClientFactory: () => mock);

      await (
        client.realtime.subscribe("a", (e) {}),
        client.realtime.subscribe("a", (e) {}), // same topic
        client.realtime.subscribe("b", (e) {}),
        client.realtime.subscribe("c", (e) {}),
        client.realtime.unsubscribe("b"),
      ).wait;

      await streamController.close();

      expect(totalCalls, 2);
      expect(subscrictionCalls.length, 1);
      expect(subscrictionCalls[0], contains('"subscriptions":["a","c"]'));
    });

    test("queued subscription send", () async {
      var totalCalls = 0;
      final subscrictionCalls = <String>[];

      final streamController = StreamController<List<int>>();

      final mock = MockClient.streaming((request, bodyStream) async {
        totalCalls++;

        // connect
        if (request.method == "GET") {
          streamController.add(
            utf8.encode(
              'id:test_id\nevent:PB_CONNECT\ndata:{"clientId":"abc"}\n\n',
            ),
          );

          return http.StreamedResponse(streamController.stream, 200);
        }

        final body = await bodyStream.bytesToString();
        subscrictionCalls.add(body);

        // subscription "a" (simulate slow transfer)
        if (body.contains('"subscriptions":["a"]')) {
          return Future.delayed(
            const Duration(milliseconds: 300),
            () {
              return http.StreamedResponse(Stream.fromIterable([]), 204);
            },
          );
        }

        return http.StreamedResponse(Stream.fromIterable([]), 204);
      });

      final client = PocketBase("/base", httpClientFactory: () => mock);

      await (
        client.realtime.subscribe("a", (e) {}),
        Future.delayed(
          const Duration(milliseconds: 50),
          () {
            return (
              client.realtime.subscribe("b", (e) {}),
              client.realtime.unsubscribe(),
              client.realtime.subscribe("c", (e) {}),
            ).wait;
          },
        )
      ).wait;

      await streamController.close();

      expect(totalCalls, 3);
      expect(subscrictionCalls.length, 2);
      expect(subscrictionCalls[0], contains('"subscriptions":["a"]'));
      expect(subscrictionCalls[1], contains('"subscriptions":["c"]'));
    });
  });
}
