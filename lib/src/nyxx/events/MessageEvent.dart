part of nyxx;

/// Sent when a new message is received.
class MessageEvent {
  /// The new message.
  Message message;

  MessageEvent._new(Client client, Map<String, dynamic> json) {
    if (client.ready) {
      this.message = Message._new(client, json['d'] as Map<String, dynamic>);
      client._events.onMessage.add(this);
      message.channel._onMessage.add(this);
    }
  }
}
