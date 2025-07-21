import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/message.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/platform.dart';

enum ChatTimeType {
  row,
  column,
}

class ChatTime extends StatelessWidget {
  final int? timestamp;
  final Color? color;
  final Widget child;
  final bool? isSelf;
  final ChatTimeType chatTimeType;

  const ChatTime({
    super.key,
    required this.timestamp,
    required this.color,
    required this.child,
    this.isSelf,
    this.chatTimeType = ChatTimeType.column,
  });

  @override
  Widget build(BuildContext context) {
    return switch (chatTimeType) {
      ChatTimeType.row => Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            child,
            Container(
              margin: const EdgeInsets.only(left: 12),
              child: Text(
                MessageUtils.formatMessageTime(timestamp),
                style: TextStyle(
                  fontSize: PlatformUtils().isDesktop ? 12 : 14,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ChatTimeType.column => Column(
          crossAxisAlignment: isSelf ?? false
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            child,
            Text(
              MessageUtils.formatMessageTime(timestamp),
              style: TextStyle(
                fontSize: PlatformUtils().isDesktop ? 12 : 14,
                color: color,
              ),
            ),
          ],
        ),
    };
  }
}
