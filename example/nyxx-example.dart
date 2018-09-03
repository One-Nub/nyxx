import 'package:nyxx/nyxx.dart' as nyxx;
import 'package:nyxx/commands.dart' as command;

import 'dart:io';
import 'dart:async';

// Example service which can be injected into your command handler
class Service {
  String data;

  Service(this.data);
}

// Main function
void main() {
  // Create new bot instance
  nyxx.Client bot = nyxx.Client(Platform.environment['DISCORD_TOKEN']);

  // Register new command handler.
  // It registers your services and adds command to registry.
  command.CommandsFramework('!', bot)
    ..admins = [const nyxx.Snowflake.static("302359032612651009")]
    ..registerServices([Service("Siema")])
    ..registerLibraryCommands();
}

// Example command with alias and subcommands.
@command.Command(name: "alias", aliases: ["aaa"])
class AliasCommand extends command.CommandContext {
  Service _service;

  // Injecting services into command handler
  AliasCommand(this._service);

  // @Command annotation creates command handler
  @command.Command(main: true)
  Future main(String name) async {
    await reply(content: name);
    await reply(content: _service.data);
  }

  // This command features `nextMessages()` method. Reade more here:
  @command.Command(name: "witam")
  Future witam() async {
    var messages = await nextMessages(2);
    print(messages);
  }

  // You can use customized logger instance
  @command.Command(name: "yyy")
  void yy(String siema, int witam) {
    logger.fine(siema);
    logger.severe(witam);
  }
}
