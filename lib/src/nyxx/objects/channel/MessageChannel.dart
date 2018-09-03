part of nyxx;

/// Provides abstraction of messages for [TextChannel], [DMChannel] and [GroupDMChannel].
/// Implements iterator which allows to use message object in for loops to access
/// messages sequentially.
///
/// ```
/// var chan = client.channels.firstWhere((ch) => ch is TextChannel);
///
/// for (var message in chan) {
///   print(message.author.id);
/// }
/// ```
class MessageChannel extends Channel with IterableMixin<Message>, ISend {
  Timer _typing;

  /// Sent when a new message is received.
  Stream<MessageEvent> onMessage;

  /// Emitted when user starts typing.
  Stream<TypingEvent> onTyping;

  StreamController<MessageEvent> _onMessage;
  StreamController<TypingEvent> _onTyping;

  /// A collection of messages sent to this channel.
  LinkedHashMap<Snowflake, Message> messages;

  /// The ID for the last message in the channel.
  Snowflake lastMessageID;

  MessageChannel._new(Client client, Map<String, dynamic> data, int type)
      : super._new(client, data, type) {
    if (raw.containsKey('last_message_id') && raw['last_message_id'] != null)
      this.lastMessageID = Snowflake(raw['last_message_id'] as String);
    this.messages = LinkedHashMap<Snowflake, Message>();

    _onMessage = StreamController.broadcast();
    _onTyping = StreamController.broadcast();

    onTyping = _onTyping.stream;
    onMessage = _onMessage.stream;
  }

  void _cacheMessage(Message message) {
    if (this.client._options.messageCacheSize > 0) {
      if (this.messages.length >= this.client._options.messageCacheSize) {
        this.messages.values.toList().first._onUpdate.close();
        this.messages.values.toList().first._onDelete.close();
        this.messages.remove(this.messages.values.toList().first.id);
      }
      this.messages[message.id] = message;
    }
  }

  /// Returs message with given [id]. Allows to force fatch message from api
  /// with [force] propery. By default it checks if message is in cache and fatches if not.
  Future<Message> getMessage(Snowflake id, {bool force = false}) async {
    if (force || !messages.containsKey(id)) {
      var r = await this
          .client
          .http
          .send('GET', "/channels/${this.id.toString()}/messages/$id");
      var msg = Message._new(this.client, r.body as Map<String, dynamic>);

      messages[id] = msg;
      return msg;
    }

    return messages[id];
  }

  @override

  /// Sends file to channel and optional [content] with [embed].
  /// Use `expandAttachment(String file)` method to expand file names in embed
  ///
  /// ```
  /// await chan.sendFile([new File("kitten.png"), new File("kitten.jpg")], content: "Kittens ^-^"]);
  /// ```
  /// ```
  /// var embed = new nyxx.EmbedBuilder()
  ///   ..title = "Example Title"
  ///   ..thumbnailUrl = "${expandAttachment('kitten.jpg')}";
  ///
  /// await e.message.channel
  ///   .sendFile([new File("kitten.jpg")], embed: embed, content: "HEJKA!");
  /// ```
  Future<Message> sendFile(List<File> files,
      {String content = "", EmbedBuilder embed, bool disableEveryone}) async {
    var newContent = _sanitizeMessage(content, disableEveryone, client);

    final HttpResponse r = await this.client.http.sendMultipart(
        'POST', '/channels/${this.id}/messages', files, data: <String, dynamic>{
      "content": newContent,
      "embed": embed != null ? embed._build() : ""
    });

    return Message._new(this.client, r.body as Map<String, dynamic>);
  }

  @override

  /// Sends message to channel. Performs `toString()` on thing passed to [content]. Allows to send embeds with [embed] field.
  ///
  /// ```
  /// await chan.send(content: "Very nice message!");
  /// ```
  ///
  /// Can be used in combination with [Emoji]. Just run `toString()` on [Emoji] instance:
  /// ```
  /// var emoji = guild.emojis.values.firstWhere((e) => e.name.startsWith("dart"));
  /// await chan.send(content: "Dart is superb! ${emoji.toString()}");
  /// ```
  /// Embeds can be sent very easily:
  /// ```
  /// var embed = new EmbedBuilder()
  ///   ..title = "Example Title"
  ///   ..addField(name: "Memory usage", value: "${ProcessInfo.currentRss / 1024 / 1024}MB");
  ///
  /// await chan.send(embed: embed);
  /// ```
  Future<Message> send(
      {Object content = "",
      EmbedBuilder embed,
      bool tts = false,
      bool disableEveryone}) async {
    var newContent = _sanitizeMessage(content, disableEveryone, client);

    final HttpResponse r = await this.client.http.send(
        'POST', '/channels/${this.id}/messages', body: <String, dynamic>{
      "content": newContent,
      "tts": tts,
      "embed": embed != null ? embed._build() : ""
    });
    return Message._new(this.client, r.body as Map<String, dynamic>);
  }

  /// Starts typing.
  Future<void> startTyping() async {
    await this.client.http.send('POST', "/channels/$id/typing");
  }

  /// Loops `startTyping` until `stopTypingLoop` is called.
  void startTypingLoop() {
    startTyping();
    this._typing =
        Timer.periodic(const Duration(seconds: 7), (Timer t) => startTyping());
  }

  /// Stops a typing loop if one is running.
  void stopTypingLoop() => this._typing?.cancel();

  /// Bulk removes many messages by its ids. [messagesIds] is list of messages ids to delete.
  ///
  /// ```
  /// var toDelete = chan.messages.keys.take(5);
  /// await chan.bulkRemoveMessages(toDelete);
  /// ```
  Future<void> bulkRemoveMessages(Iterable<Snowflake> messagesIds) async {
    utils.chunk(messagesIds.toList(), 90).listen((data) async {
      await this.client.http.send(
          'POST', "/channels/${id.toString()}/messages/bulk-delete",
          body: {"messages": data});
    });
  }

  /// Gets several [Message] objects from API. Only one of [after], [before], [around] can be specified
  /// otherwise it'll throw.
  ///
  /// Messages will be cached if [cache] is set to true. Defaults to false.
  ///
  /// ```
  /// var messages = await chan.getMessages(limit: 100, after: "222078108977594368");
  /// ```
  Future<LinkedHashMap<Snowflake, Message>> getMessages(
      {int limit = 50,
      Snowflake after,
      Snowflake before,
      Snowflake around,
      bool cache}) async {
    Map<String, String> query = {"limit": limit.toString()};

    if (after != null) query['after'] = after.toString();
    if (before != null) query['before'] = before.toString();
    if (around != null) query['around'] = around.toString();

    final HttpResponse r = await this
        .client
        .http
        .send('GET', '/channels/${this.id}/messages', queryParams: query);

    var response = LinkedHashMap<Snowflake, Message>();

    for (Map<String, dynamic> val in r.body.values.first) {
      var msg = Message._new(this.client, val);
      response[msg.id] = msg;
    }

    if (cache) messages.addAll(response);

    return response;
  }

  @override
  Iterator<Message> get iterator => messages.values.iterator;
}
