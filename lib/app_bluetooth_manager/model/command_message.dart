import 'dart:convert';

///用来描述要传递的命令消息
class CommandMessage {
  final String commandFlag;
  final String value;

  CommandMessage({required this.commandFlag, required this.value});

  Map<String, dynamic> toJson() {
    return {'c': commandFlag, 'v': value};
  }

  factory CommandMessage.fromJson(Map<String, dynamic> json) {
    return CommandMessage(
      commandFlag: json['c'] as String,
      value: json['v'] as String,
    );
  }

  @override
  String toString() {
    return jsonEncode(toJson());
  }
}
