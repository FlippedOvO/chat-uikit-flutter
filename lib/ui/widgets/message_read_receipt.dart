import 'package:extended_text/extended_text.dart';
import 'package:flutter/material.dart';

// ignore: unused_import
import 'package:provider/provider.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_sdk/enum/get_group_message_read_member_list_filter.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_member_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_state.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/screen_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitChat/TIMUIKitTextField/special_text/DefaultSpecialTextSpanBuilder.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/separate_models/tui_chat_separate_view_model.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/message.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/time_ago.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitChat/TIMUIKitMessageItem/tim_uikit_chat_face_elem.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitChat/TIMUIKitMessageItem/tim_uikit_chat_file_elem.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitChat/TIMUIKitMessageItem/tim_uikit_chat_image_elem.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitChat/TIMUIKitMessageItem/tim_uikit_chat_sound_elem.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitChat/TIMUIKitMessageItem/tim_uikit_chat_video_elem.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitChat/TIMUIKitMessageItem/tim_uikit_merger_message_elem.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/avatar.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_base.dart';
import 'package:tencent_cloud_chat_uikit/theme/color.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';

class MessageReadReceipt extends StatefulWidget {
  final V2TimMessage messageItem;
  final int unreadCount;
  final int readCount;
  final void Function(String userID, TapDownDetails tapDetails)? onTapAvatar;
  final TUIChatSeparateViewModel model;

  const MessageReadReceipt(
      {Key? key,
      required this.messageItem,
      required this.unreadCount,
      required this.readCount,
      this.onTapAvatar,
      required this.model})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => _MessageReadReceiptState();
}

class _MessageReadReceiptState extends TIMUIKitState<MessageReadReceipt> {
  bool readMemberIsFinished = false;
  bool unreadMemberIsFinished = false;
  int readMemberListNextSeq = 0;
  int unreadMemberListNextSeq = 0;
  List<V2TimGroupMemberInfo> readMemberList = [];
  List<V2TimGroupMemberInfo> unreadMemberList = [];
  int currentIndex = 0;

  _getUnreadMemberList() async {
    final unReadMemberRes = await widget.model.getGroupMessageReadMemberList(widget.messageItem.msgID!,
        GetGroupMessageReadMemberListFilter.V2TIM_GROUP_MESSAGE_READ_MEMBERS_FILTER_UNREAD, unreadMemberListNextSeq);
    if (unReadMemberRes.code == 0) {
      final res = unReadMemberRes.data;
      if (res != null) {
        unreadMemberList = [...unreadMemberList, ...res.memberInfoList];
        unreadMemberIsFinished = res.isFinished;
        unreadMemberListNextSeq = res.nextSeq;
      }
    }
    setState(() {});
  }

  _getReadMemberList() async {
    final readMemberRes = await widget.model.getGroupMessageReadMemberList(
      widget.messageItem.msgID!,
      GetGroupMessageReadMemberListFilter.V2TIM_GROUP_MESSAGE_READ_MEMBERS_FILTER_READ,
      readMemberListNextSeq,
    );
    if (readMemberRes.code == 0) {
      final res = readMemberRes.data;
      if (res != null) {
        readMemberList = [...readMemberList, ...res.memberInfoList];
        readMemberIsFinished = res.isFinished;
        readMemberListNextSeq = res.nextSeq;
      }
    }
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _getReadMemberList();
    _getUnreadMemberList();
  }

  Widget _getMsgItem(V2TimMessage message) {
    final type = message.elemType;
    final isFromSelf = message.isSelf ?? true;

    switch (type) {
      case MessageElemType.V2TIM_ELEM_TYPE_CUSTOM:
        return Text(TIM_t("[自定义]"));
      case MessageElemType.V2TIM_ELEM_TYPE_SOUND:
        return TIMUIKitSoundElem(
            isShowMessageReaction: false,
            chatModel: widget.model,
            message: message,
            soundElem: message.soundElem!,
            msgID: message.msgID ?? "",
            isFromSelf: isFromSelf,
            localCustomInt: message.localCustomInt);
      case MessageElemType.V2TIM_ELEM_TYPE_TEXT:
        return ExtendedText(Encrypt.shared.decrypt(message.textElem!.text!),
            softWrap: true,
            style: const TextStyle(fontSize: 16),
            specialTextSpanBuilder: DefaultSpecialTextSpanBuilder(
              isUseQQPackage: widget.model.chatConfig.stickerPanelConfig?.useQQStickerPackage ?? true,
              isUseTencentCloudChatPackage:
                  widget.model.chatConfig.stickerPanelConfig?.useTencentCloudChatStickerPackage ?? true,
              isUseTencentCloudChatPackageOldKeys:
                  widget.model.chatConfig.stickerPanelConfig?.useTencentCloudChatStickerPackageOldKeys ?? false,
              showAtBackground: true,
              checkHttpLink: true,
            ));
      // return Text(message.textElem!.text!);
      case MessageElemType.V2TIM_ELEM_TYPE_FACE:
        return TIMUIKitFaceElem(
            isShowMessageReaction: false,
            model: widget.model,
            isShowJump: false,
            path: message.faceElem?.data ?? "",
            message: message);
      case MessageElemType.V2TIM_ELEM_TYPE_FILE:
        return TIMUIKitFileElem(
          chatModel: widget.model,
          isShowMessageReaction: false,
          message: message,
          messageID: message.msgID,
          fileElem: message.fileElem,
          isSelf: isFromSelf,
          isShowJump: false,
        );
      case MessageElemType.V2TIM_ELEM_TYPE_IMAGE:
        return TIMUIKitImageElem(
          chatModel: widget.model,
          isShowMessageReaction: false,
          message: message,
          isFrom: "merger",
          key: Key("${message.seq}_${message.timestamp}"),
        );
      case MessageElemType.V2TIM_ELEM_TYPE_VIDEO:
        return TIMUIKitVideoElem(message, chatModel: widget.model, isShowMessageReaction: false, isFrom: "merger");
      case MessageElemType.V2TIM_ELEM_TYPE_LOCATION:
        return Text(TIM_t("[位置]"));
      case MessageElemType.V2TIM_ELEM_TYPE_MERGER:
        return TIMUIKitMergerElem(
            isShowMessageReaction: false,
            model: widget.model,
            isShowJump: false,
            message: message,
            mergerElem: message.mergerElem!,
            isSelf: isFromSelf,
            messageID: message.msgID!);
      default:
        return Text(TIM_t("未知消息"));
    }
  }

  _getShowName(V2TimGroupMemberInfo item) {
    final friendRemark = item.friendRemark ?? "";
    final nickName = item.nickName ?? "";
    final userID = item.userID;
    final showName = nickName != "" ? nickName : userID;
    return friendRemark != "" ? friendRemark : showName;
  }

  Widget _memberItemBuilder(V2TimGroupMemberInfo item, TUITheme theme) {
    final faceUrl = item.faceUrl ?? '';
    final showName = _getShowName(item);
    final isDesktopScreen = TUIKitScreenUtils.getFormFactor(context) == DeviceType.Desktop;

    return InkWell(
      onTapDown: (details) {
        if (widget.onTapAvatar != null) {
          widget.onTapAvatar!(item.userID!, details);
        }
      },
      child: Container(
        padding: const EdgeInsets.only(top: 10, left: 16),
        child: Row(
          children: [
            Container(
              height: isDesktopScreen ? 30 : 40,
              width: isDesktopScreen ? 30 : 40,
              margin: EdgeInsets.only(right: 12, bottom: isDesktopScreen ? 6 : 0),
              child: Avatar(faceUrl: faceUrl, showName: showName),
            ),
            Expanded(
                child: Container(
              alignment: Alignment.centerLeft,
              padding: EdgeInsets.only(top: 10, bottom: isDesktopScreen ? 14 : 19, right: 28),
              decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: theme.weakDividerColor ?? CommonColor.weakDividerColor))),
              child: Text(
                showName,
                style: TextStyle(color: Colors.black, fontSize: isDesktopScreen ? 14 : 18),
              ),
            )),
          ],
        ),
      ),
    );
  }

  @override
  Widget tuiBuild(BuildContext context, TUIKitBuildValue value) {
    final TUITheme theme = value.theme;
    final option1 = widget.readCount;
    final option2 = widget.unreadCount;
    final isDesktopScreen = TUIKitScreenUtils.getFormFactor(context) == DeviceType.Desktop;

    Widget pageBody() {
      return Container(
        color: isDesktopScreen ? null : Colors.white,
        child: Column(
          children: [
            // The top part of the message content
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height / 2,
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(MessageUtils.getDisplayName(widget.messageItem)),
                          const SizedBox(width: 8),
                          Text(
                            TimeAgo().getTimeForMessage(widget.messageItem.timestamp ?? 0),
                            softWrap: true,
                            style: TextStyle(fontSize: 12, color: theme.weakTextColor),
                          )
                        ],
                      ),
                      const SizedBox(height: 6),
                      // message content
                      _getMsgItem(widget.messageItem),
                    ],
                  ),
                ),
              ),
            ),
            // divider
            Container(
              height: 8,
              color: theme.weakBackgroundColor,
            ),
            // The bottom part shows the read/unread list
            Expanded(
              child: Column(
                children: [
                  // read/unread switch button
                  Row(
                    children: <Widget>[
                      Expanded(
                        flex: 1,
                        child: InkWell(
                          onTap: () {
                            currentIndex = 0;
                            setState(() {});
                          },
                          child: Container(
                            height: isDesktopScreen ? 40 : 50.0,
                            alignment: Alignment.bottomCenter,
                            padding: EdgeInsets.only(bottom: isDesktopScreen ? 8 : 12),
                            decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border(
                                    bottom: BorderSide(
                                        width: 2, color: currentIndex == 0 ? theme.primaryColor! : Colors.white))),
                            child: Text(
                              TIM_t_para("{{option1}}人已读", "$option1人已读")(option1: option1),
                              style: TextStyle(
                                color: currentIndex != 0 ? theme.weakTextColor : Colors.black,
                                fontSize: isDesktopScreen ? 14 : 18,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: InkWell(
                          onTap: () {
                            currentIndex = 1;
                            setState(() {});
                          },
                          child: Container(
                            alignment: Alignment.bottomCenter,
                            height: isDesktopScreen ? 40 : 50.0,
                            padding: EdgeInsets.only(bottom: isDesktopScreen ? 8 : 12),
                            decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border(
                                    bottom: BorderSide(
                                        width: 2, color: currentIndex == 1 ? theme.primaryColor! : Colors.white))),
                            child: Text(
                              TIM_t_para("{{option2}}人未读", "$option2人未读")(option2: option2),
                              style: TextStyle(
                                color: currentIndex != 1 ? theme.weakTextColor : Colors.black,
                                fontSize: isDesktopScreen ? 14 : 18,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    height: 1,
                    decoration: BoxDecoration(
                        border:
                            Border(bottom: BorderSide(color: theme.weakDividerColor ?? CommonColor.weakDividerColor))),
                  ),
                  // member list
                  Expanded(
                    child: IndexedStack(
                      index: currentIndex,
                      children: [
                        ListView.builder(
                          shrinkWrap: false,
                          itemCount: readMemberList.length,
                          itemBuilder: (context, index) {
                            if (!readMemberIsFinished && index == readMemberList.length - 5) {
                              _getReadMemberList();
                            }
                            return _memberItemBuilder(readMemberList[index], theme);
                          },
                        ),
                        ListView.builder(
                          shrinkWrap: false,
                          itemCount: unreadMemberList.length,
                          itemBuilder: (context, index) {
                            if (!unreadMemberIsFinished && index == unreadMemberList.length - 5) {
                              _getUnreadMemberList();
                            }
                            return _memberItemBuilder(unreadMemberList[index], theme);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return TUIKitScreenUtils.getDeviceWidget(
        context: context,
        desktopWidget: pageBody(),
        defaultWidget: DefaultTabController(
          length: 2,
          child: Scaffold(
              appBar: AppBar(
                  title: Text(
                    TIM_t("消息详情"),
                    style: TextStyle(color: theme.appbarTextColor, fontSize: 17),
                  ),
                  shadowColor: theme.weakDividerColor,
                  backgroundColor: theme.appbarBgColor ?? theme.primaryColor,
                  iconTheme: IconThemeData(
                    color: theme.appbarTextColor,
                  )),
              body: pageBody()),
        ));
  }
}
