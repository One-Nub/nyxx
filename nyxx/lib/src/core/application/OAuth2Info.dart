part of nyxx;

/// Info about a OAuth2 app, bot, user, and possible guilds that that bot can
/// be invited to.
class OAuth2Info {
  /// The OAuth2 app.
  late final OAuth2Application app;

  /// The app's bot.
  late final User bot;

  /// You.
  late final User me;

  /// Mini guild objects with permissions for every guild you are on.
  late final Map<Snowflake, OAuth2Guild> guilds;

  OAuth2Info._new(Map<String, dynamic> raw, Nyxx client) {
    this.app = OAuth2Application._new(raw["application"] as Map<String, dynamic>);
    this.bot = User._new(client, raw["bot"] as Map<String, dynamic>);
    this.me = User._new(client, raw["user"] as Map<String, dynamic>);

    this.guilds = <Snowflake, OAuth2Guild>{};
    for (final raw in raw["guilds"]) {
      final guild = OAuth2Guild._new(raw as Map<String, dynamic>);
      this.guilds[Snowflake(guild.id as String)] = guild;
    }
  }
}
