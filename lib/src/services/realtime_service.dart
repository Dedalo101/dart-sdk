import "dart:async";
import "dart:convert";

import "../client.dart";
import "../sse/sse_client.dart";
import "../sse/sse_message.dart";
import "base_service.dart";

/// The definition of a realtime subscription callback function.
typedef SubscriptionFunc = void Function(SseMessage e);
typedef UnsubscribeFunc = Future<void> Function();

/// The service that handles the **Realtime APIs**.
///
/// Usually shouldn't be initialized manually and instead
/// [PocketBase.realtime] should be used.
class RealtimeService extends BaseService {
  RealtimeService(super.client);

  SseClient? _sse;
  String _clientId = "";
  final _subscriptions = <String, List<SubscriptionFunc>>{};
  List<String> _lastSentTopics = [];

  /// Returns the established SSE connection client id (if any).
  String get clientId => _clientId;

  /// An optional hook that is invoked when the realtime client disconnects
  /// either when unsubscribing from all subscriptions or when the
  /// connection was interrupted or closed by the server.
  ///
  /// It receives the subscriptions map before the disconnect
  /// (could be used to determine whether the disconnect was caused by
  /// unsubscribing or network/server error).
  ///
  /// If you want to listen for the opposite, aka. when the client
  /// connection is established, subscribe to the `PB_CONNECT` event.
  void Function(Map<String, List<SubscriptionFunc>>)? onDisconnect;

  /// Register the subscription listener.
  ///
  /// You can subscribe multiple times to the same topic.
  ///
  /// If the SSE connection is not started yet,
  /// this method will also initialize it.
  ///
  /// Here is an example listening to the connect/reconnect events:
  ///
  /// ```dart
  /// pb.realtime.subscribe("PB_CONNECT", (e) {
  ///   print("Connected: $e");
  /// });
  /// ```
  Future<UnsubscribeFunc> subscribe(
    String topic,
    SubscriptionFunc listener, {
    String? expand,
    String? filter,
    String? fields,
    Map<String, dynamic> query = const {},
    Map<String, String> headers = const {},
  }) async {
    var key = topic;

    // merge query parameters
    final enrichedQuery = Map<String, dynamic>.of(query);
    if (expand?.isNotEmpty ?? false) {
      enrichedQuery["expand"] ??= expand;
    }
    if (filter?.isNotEmpty ?? false) {
      enrichedQuery["filter"] ??= filter;
    }
    if (fields?.isNotEmpty ?? false) {
      enrichedQuery["fields"] ??= fields;
    }

    // serialize and append the topic options (if any)
    final options = <String, dynamic>{};
    if (enrichedQuery.isNotEmpty) {
      options["query"] = enrichedQuery;
    }
    if (headers.isNotEmpty) {
      options["headers"] = headers;
    }
    if (options.isNotEmpty) {
      final encoded =
          "options=${Uri.encodeQueryComponent(jsonEncode(options))}";
      key += (key.contains("?") ? "&" : "?") + encoded;
    }

    if (!_subscriptions.containsKey(key)) {
      _subscriptions[key] = [];
    }
    _subscriptions[key]?.add(listener);

    // start a new SSE connection
    if (_sse == null) {
      await _connect();
    } else if (_clientId.isNotEmpty && _subscriptions[key]?.length == 1) {
      // otherwise - just persist the updated subscriptions
      // (if it is the first for the topic)
      await _submitSubscriptions();
    }

    return () async {
      return unsubscribeByTopicAndListener(topic, listener);
    };
  }

  /// Unsubscribe from all subscription listeners with the specified topic.
  ///
  /// If [topic] is not set, then this method will unsubscribe
  /// from all active subscriptions.
  ///
  /// This method is no-op if there are no active subscriptions.
  ///
  /// The related SSE connection will be autoclosed if after the
  /// unsubscribe operation there are no active subscriptions left.
  Future<void> unsubscribe([String topic = ""]) async {
    if (topic.isEmpty) {
      // remove all subscriptions
      _subscriptions.clear();
    } else {
      final subs = _getSubscriptionsByTopic(topic);

      for (final key in subs.keys) {
        _subscriptions.remove(key);
      }
    }

    return _submitSubscriptions();
  }

  /// Unsubscribe from all subscription listeners starting with
  /// the specified topic prefix.
  ///
  /// This method is no-op if there are no active subscriptions
  /// with the specified topic prefix.
  ///
  /// The related SSE connection will be autoclosed if after the
  /// unsubscribe operation there are no active subscriptions left.
  Future<void> unsubscribeByPrefix(String topicPrefix) async {
    // remove matching subscriptions
    _subscriptions.removeWhere((key, func) {
      // "?" so that it can be used as end delimiter for the prefix
      return "$key?".startsWith(topicPrefix);
    });

    return _submitSubscriptions();
  }

  /// Unsubscribe from all subscriptions matching the specified topic
  /// and listener function.
  ///
  /// This method is no-op if there are no active subscription with
  /// the specified topic and listener.
  ///
  /// The related SSE connection will be autoclosed if after the
  /// unsubscribe operation there are no active subscriptions left.
  Future<void> unsubscribeByTopicAndListener(
    String topic,
    SubscriptionFunc listener,
  ) async {
    final subs = _getSubscriptionsByTopic(topic);

    for (final key in subs.keys) {
      if (_subscriptions[key]?.isEmpty ?? true) {
        continue; // nothing to unsubscribe from
      }

      _subscriptions[key]?.removeWhere((fn) => fn == listener);
    }

    return _submitSubscriptions();
  }

  Map<String, List<SubscriptionFunc>> _getSubscriptionsByTopic(String topic) {
    final result = <String, List<SubscriptionFunc>>{};

    // "?" so that it can be used as end delimiter for the topic
    topic = topic.contains("?") ? topic : "$topic?";

    _subscriptions.forEach((key, value) {
      if ("$key?".startsWith(topic)) {
        result[key] = value;
      }
    });

    return result;
  }

  bool _allTopicsAreEmpty() {
    for (final key in _subscriptions.keys) {
      if (_subscriptions[key]?.isNotEmpty ?? false) {
        return false; // has at least one listener
      }
    }

    return true;
  }

  bool _hasUnsentTopics() {
    final currentTopics = _subscriptions.keys.toList();

    if (currentTopics.length != _lastSentTopics.length) {
      return true;
    }

    for (final topic in currentTopics) {
      if (!_lastSentTopics.contains(topic)) {
        return true;
      }
    }

    return false;
  }

  void _drainCompleters(List<Completer<void>> completers, [Object? err]) {
    for (final completer in completers) {
      if (completer.isCompleted) {
        continue;
      }

      if (err != null) {
        completer.completeError(err);
      } else {
        completer.complete();
      }
    }

    completers.clear();
  }

  // Disconnect/Connect
  // -----------------------------------------------------------------

  void _disconnect() {
    _sse?.close();
    _sse = null;
    _clientId = "";
    _lastSentTopics.clear();
  }

  final _connectCompleters = <Completer<void>>[];

  Future<void> _connect() {
    _disconnect();

    final completer = Completer<void>();

    _connectCompleters.add(completer);

    if (_connectCompleters.length == 1) {
      Future(_finishConnectCompleters);
    }

    return completer.future;
  }

  void _finishConnectCompleters() {
    if (_connectCompleters.isEmpty) {
      return;
    }

    // subscribed and then immediately unsubscribed
    if (_allTopicsAreEmpty()) {
      _drainCompleters(_connectCompleters);
      return;
    }

    final url = client.buildURL("/api/realtime").toString();

    _sse = SseClient(
      url,
      httpClientFactory: client.httpClientFactory,
      onClose: () {
        if (_clientId.isNotEmpty && onDisconnect != null) {
          onDisconnect?.call(_subscriptions);
        }

        _disconnect();

        _drainCompleters(
          _connectCompleters,
          StateError("failed to establish SSE connection"),
        );
      },
      onError: (err) {
        if (_clientId.isNotEmpty && onDisconnect != null) {
          _clientId = "";
          onDisconnect?.call(_subscriptions);
        }
      },
    );

    // bind subscriptions listener
    _sse?.onMessage.listen((msg) {
      if (!_subscriptions.containsKey(msg.event)) {
        return;
      }

      _subscriptions[msg.event]?.forEach((fn) {
        fn.call(msg);
      });
    });

    // resubmit local subscriptions on first reconnect
    _sse?.onMessage.where((msg) => msg.event == "PB_CONNECT").listen((
      msg,
    ) async {
      _lastSentTopics.clear();

      _clientId = msg.id;

      await _submitSubscriptions();

      _drainCompleters(_connectCompleters);
    }, onError: (dynamic err) {
      _disconnect();

      _drainCompleters(
        _connectCompleters,
        err is Object ? err : StateError("failed to establish SSE connection"),
      );
    });
  }

  // Subscriptions send
  // -----------------------------------------------------------------

  final _subscriptionCompleters = <Completer<void>>[];
  bool _isProcessingSubscriptionCompleters = false;

  Future<void> _submitSubscriptions() {
    final completer = Completer<void>();

    _subscriptionCompleters.add(completer);

    if (_subscriptionCompleters.length == 1) {
      Future(_finishSubscriptionCompleters);
    }

    return completer.future;
  }

  Future<void> _finishSubscriptionCompleters() async {
    if (_isProcessingSubscriptionCompleters ||
        _subscriptionCompleters.isEmpty) {
      return;
    }

    // clone and reset the list to allow next items to queue
    final completers = List<Completer<void>>.from(_subscriptionCompleters);
    _subscriptionCompleters.clear();

    _isProcessingSubscriptionCompleters = true;

    try {
      await _sendSubscriptions();

      _drainCompleters(completers);
    } catch (err) {
      _drainCompleters(completers, err);
    } finally {
      _isProcessingSubscriptionCompleters = false;

      // another request came in while awaiting above
      if (_subscriptionCompleters.isNotEmpty) {
        await _finishSubscriptionCompleters();
      }
    }
  }

  Future<void> _sendSubscriptions() async {
    // not initialized yet or connection closed
    if (_clientId.isEmpty) {
      return;
    }

    // no subscriptions -> close the SSE connection
    if (_allTopicsAreEmpty()) {
      return _disconnect();
    }

    // no change
    if (!_hasUnsentTopics()) {
      return;
    }

    _lastSentTopics = _subscriptions.keys.toList();

    return client.send(
      "/api/realtime",
      method: "POST",
      body: {
        "clientId": _clientId,
        "subscriptions": _lastSentTopics,
      },
    );
  }
}
