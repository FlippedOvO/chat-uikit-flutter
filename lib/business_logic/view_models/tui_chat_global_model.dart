// ignore_for_file: avoid_print, unnecessary_getters_setters, unused_element
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tencent_cloud_chat_sdk/enum/V2TimAdvancedMsgListener.dart';
import 'package:tencent_cloud_chat_sdk/enum/history_msg_get_type_enum.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_priority_enum.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_status.dart';
import 'package:tencent_cloud_chat_sdk/enum/offlinePushInfo.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_custom_elem.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_custom_elem.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_application.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_application.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_image.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_image.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message_download_progress.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message_download_progress.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message_receipt.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message_receipt.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_msg_create_info_result.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_msg_create_info_result.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_value_callback.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_value_callback.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_class.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/life_cycle/chat_life_cycle.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/separate_models/tui_chat_model_tools.dart';
import 'package:tencent_cloud_chat_uikit/data_services/group/group_services.dart';
import 'package:tencent_cloud_chat_uikit/data_services/message/message_services.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_uikit/ui/constants/history_message_constant.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/logger.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/message.dart';

enum ConvType { none, c2c, group }

enum HistoryMessagePosition {
  bottom,
  inTwoScreen,
  awayTwoScreen,
  notShowLatest
}

class CurrentConversation {
  final String conversationID;
  final ConvType conversationType;

  CurrentConversation(this.conversationID, this.conversationType);
}

class TUIChatGlobalModel extends ChangeNotifier implements TIMUIKitClass {
  final MessageService _messageService = serviceLocator<MessageService>();
  final GroupServices _groupServices = serviceLocator<GroupServices>();
  final Map<String, List<V2TimMessage>?> _messageListMap = {};
  final Map<String, V2TimMessageReceipt> _messageReadReceiptMap = {};
  final Map<String, int> _messageListProgressMap = {};
  final Map<String, String> _fileListLocationMap = {};
  final Map<String, dynamic> _preloadImageMap = {};
  final Map<String, HistoryMessagePosition> _historyMessagePositionMap = {};
  final List<CurrentConversation> _currentConversationList = [];

  Map<String, dynamic> get preloadImageMap => _preloadImageMap;

  ChatLifeCycle? _lifeCycle;
  bool _isDownloading = false;
  final List<Map<String, String>> _waitingDownloadList =
      List.empty(growable: true); // example {"savePath":"","url":"",msgId:""}
  int _totalUnreadCount = 0;
  String localKeyPrefix = "TUIKit_conversation_stored_";
  String localMsgIDListKey = "TUIKit_conversation_list";

  late V2TimAdvancedMsgListener advancedMsgListener;
  int _unreadCountForTongue = 0;

  // use for generate a new sliver list to show received message list
  int _receivedNewMessageCount = 0;
  final List<V2TimMessage> _receivedUnreadMessageList = [];

  TIMUIKitChatConfig chatConfig = const TIMUIKitChatConfig();
  List<V2TimGroupApplication>? _groupApplicationList;
  String Function(V2TimMessage message)? _abstractMessageBuilder;
  final Map<String, int> _c2cMessageEditStatusMap =
      Map.from({}); // 0 normal 1 sending
  final Map<String, bool> _c2cMessageFromUserActiveMap = Map.from({});
  final Map<String, Timer> _c2cMessageActiveTimer = Map.from({});
  bool _showC2cMessageEditStatus = true;
  final Map<String, Timer> _c2cMessageStatusShowTimer = Map.from({});
  Map<String, List> loadingMessage = {};

  TUIChatGlobalModel() {
    advancedMsgListener = V2TimAdvancedMsgListener(
      onRecvC2CReadReceipt: (List<V2TimMessageReceipt> receiptList) {
        _onReceiveC2CReadReceipt(receiptList);
      },
      onRecvMessageRevoked: (String msgID) {
        onMessageRevoked(msgID);
      },
      onRecvNewMessage: (V2TimMessage newMsg) {
        _onReceiveNewMsg(newMsg);
      },
      onSendMessageProgress: (V2TimMessage messagae, int progress) {
        _onSendMessageProgress(messagae, progress);
      },
      onRecvMessageReadReceipts: (List<V2TimMessageReceipt> receiptList) {
        _onReceiveMessageReadReceipts(receiptList);
      },
      onRecvMessageModified: (V2TimMessage newMsg) {
        onMessageModified(newMsg);
      },
      onMessageDownloadProgressCallback:
          (V2TimMessageDownloadProgress messageProgress) {
        onMessageDownloadProgressCallback(messageProgress);
      },
    );
  }

  bool get isDownloading => _isDownloading;

  bool get hasWaiting => _waitingDownloadList.isNotEmpty;

  Map<String, String> get currentDownLoad => _waitingDownloadList.first;

  int getWaitingListLength() {
    return _waitingDownloadList.length;
  }

  void addWaitingList(String msgID) {
    outputLogger.i("add to waiting list success");
    bool contains = false;
    for (Map<String, String> element in _waitingDownloadList) {
      String msgIDItem = element["msgID"] ?? "";
      if (msgIDItem.isNotEmpty) {
        if (msgID == msgIDItem) {
          contains = true;
          break;
        }
      }
    }
    if (!contains) {
      _waitingDownloadList.add(Map.from({
        "msgID": msgID,
      }));
      // setMessageProgress(msgID, 1); // 有一点进度条，表示等待中
    }
  }

  downloadFile() async {
    if (_isDownloading || _waitingDownloadList.isEmpty) {
      return;
    }

    final nextDownload = _waitingDownloadList.first;
    final msgID = nextDownload["msgID"] ?? "";
    if (msgID.isEmpty || _messageListProgressMap[msgID] == 100) {
      return;
    }

    _isDownloading = true;
    await _messageService.downloadMessage(
      msgID: msgID,
      messageType: 6,
      imageType: 0,
      isSnapshot: false,
    );

    outputLogger.i("start another download");
  }

  int getReceived(msgID) {
    return messageListProgressMap[msgID] ?? 0;
  }

  bool isWaiting(String msgID) {
    return _waitingDownloadList.where((element) {
      String msgIDItem = element["msgID"] ?? "";
      if (msgIDItem.isNotEmpty) {
        if (msgID == msgIDItem) {
          return true;
        }
      }
      return false;
    }).isNotEmpty;
  }

  Map<String, int> get messageListProgressMap {
    return _messageListProgressMap;
  }

  Map<String, List<V2TimMessage>?> get messageListMap {
    return _messageListMap;
  }

  int get totalUnReadCount {
    return _totalUnreadCount;
  }

  set totalUnReadCount(int newValue) {
    _totalUnreadCount = newValue;
    notifyListeners();
  }

  int get receivedNewMessageCount => _receivedNewMessageCount;

  set receivedNewMessageCount(int value) {
    _receivedNewMessageCount = value;
  }

  int get unreadCountForTongue => _unreadCountForTongue;

  set unreadCountForTongue(int value) {
    _unreadCountForTongue = value;
    notifyListeners();
  }

  List<V2TimGroupApplication> get groupApplicationList =>
      _groupApplicationList ?? [];

  String Function(V2TimMessage message)? get abstractMessageBuilder =>
      _abstractMessageBuilder;

  Map<String, V2TimMessageReceipt> get messageReadReceiptMap =>
      _messageReadReceiptMap;

  String get currentSelectedConv => _currentConversationList.isNotEmpty
      ? _currentConversationList[_currentConversationList.length - 1]
          .conversationID
      : "";

  ConvType? get currentSelectedConvType => _currentConversationList.isNotEmpty
      ? _currentConversationList[_currentConversationList.length - 1]
          .conversationType
      : null;

  setCurrentConversation(CurrentConversation value) {
    _currentConversationList.add(value);
    notifyListeners();
  }

  clearCurrentConversation() {
    // Only keep the last 20 messages when existing a chat.
    _messageListMap[currentSelectedConv] =
        (_messageListMap[currentSelectedConv] ?? []).sublist(
            0,
            max(
                0,
                min(10,
                    ((_messageListMap[currentSelectedConv] ?? []).length))));
    if (_currentConversationList.isNotEmpty) {
      _currentConversationList.removeLast();
    }

    _receivedUnreadMessageList.clear();
    // notifyListeners();
  }

  void removeMessageList(String conversationID) {
    _messageListMap.remove(conversationID);
  }

  V2TimMessageReceipt? getMessageReadReceipt(String msgID) {
    return messageReadReceiptMap[msgID];
  }

  setShowC2cEditStatus(bool show) {
    _showC2cMessageEditStatus = show;
  }

  /// set edit status from chats
  setC2cMessageEditStatus(String userID, int status) {
    _c2cMessageEditStatusMap[userID] = status;
    if (status == 1) {
      if (_c2cMessageStatusShowTimer[userID] != null) {
        if (_c2cMessageStatusShowTimer[userID]!.isActive) {
          _c2cMessageStatusShowTimer[userID]!.cancel();
          _c2cMessageEditStatusMap[userID] = 0;
        }
      }
      _c2cMessageStatusShowTimer[userID] =
          Timer.periodic(const Duration(seconds: 5), (timer) {
        _c2cMessageEditStatusMap[userID] = 0;
        Timer? t = _c2cMessageStatusShowTimer[userID];
        if (t != null && t.isActive) {
          // 取消当前的定时器
          t.cancel();
        }
      });
    }
    notifyListeners();
  }

  int getC2cMessageEditStatus(String userID) {
    return _c2cMessageEditStatusMap[userID] ?? 0;
  }

  set abstractMessageBuilder(String Function(V2TimMessage message)? value) {
    _abstractMessageBuilder = value;
  }

  set lifeCycle(ChatLifeCycle? value) {
    _lifeCycle = value;
  }

  set groupApplicationList(List<V2TimGroupApplication> value) {
    _groupApplicationList = value;
  }

  setChatConfig(TIMUIKitChatConfig config) {
    chatConfig = config;
  }

  initMessageMapFromLocalDatabase(
      List<V2TimConversation?> conversations) async {
    int index = 0;
    for (V2TimConversation? conversationItem in conversations) {
      if (conversationItem == null || conversationItem.type == null) {
        return;
      }
      final conversationID =
          TencentUtils.checkString(conversationItem.userID) ??
              TencentUtils.checkString(conversationItem.groupID) ??
              conversationItem.conversationID;
      if (messageListMap[conversationID] == null ||
          messageListMap[conversationID]!.isEmpty) {
        index++;
        Future.delayed(Duration(milliseconds: 500 * index), () {
          preloadMessageForConversation(
              conversationID: conversationID,
              conversationType: ConvType.values[conversationItem.type!]);
        });
      }
    }
  }

  preloadMessageForConversation({
    required ConvType conversationType,
    required String conversationID,
  }) async {
    final response = await _messageService.getHistoryMessageList(
        count: 20,
        getType: HistoryMsgGetTypeEnum.V2TIM_GET_LOCAL_OLDER_MSG,
        userID: conversationType == ConvType.c2c ? conversationID : null,
        groupID: conversationType == ConvType.group ? conversationID : null);
    if (_messageListMap[conversationID] == null ||
        _messageListMap[conversationID]!.isEmpty) {
      _messageListMap[conversationID] = response;
    }
  }

  clearMessageMapFromLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? localMsgIDList = prefs.getStringList(localMsgIDListKey);

    if (localMsgIDList != null) {
      for (String convID in localMsgIDList) {
        prefs.remove("$localKeyPrefix$convID");
      }
    }

    prefs.remove(localMsgIDListKey);
  }

  Future<void> updateMessageFromController(
      {required String msgID,
      required String conversationID,
      required ConvType conversationType}) async {
    final TUIChatModelTools tools = serviceLocator<TUIChatModelTools>();
    V2TimMessage? newMessage = await tools.getExistingMessageByID(
        msgID: msgID,
        conversationID: conversationID,
        conversationType: conversationType);
    if (newMessage != null) {
      onMessageModified(newMessage, currentSelectedConv);
    }
  }

  clearData() {
    _messageListMap.clear();
    _currentConversationList.clear();
    _totalUnreadCount = 0;
    _groupApplicationList?.clear();
    _totalUnreadCount = 0;
    _receivedNewMessageCount = 0;
    _messageReadReceiptMap.clear();
    _messageListProgressMap.clear();
    notifyListeners();
  }

  clearReceivedNewMessageCount() {
    _receivedNewMessageCount = 0;
  }

  _preLoadImage(List<V2TimMessage> msgList) {
    List<V2TimMessage> needPreViewList =
        msgList.sublist(0, max(0, min(5, msgList.length - 1)));
    for (var msgItem in needPreViewList) {
      V2TimImage? getImageFromList(V2TimImageTypesEnum imgType) {
        V2TimImage? img = MessageUtils.getImageFromImgList(
            msgItem.imageElem?.imageList,
            HistoryMessageDartConstant.imgPriorMap[imgType] ??
                HistoryMessageDartConstant.oriImgPrior);
        return img;
      }

      V2TimImage? originalImg = getImageFromList(V2TimImageTypesEnum.small);
      if (originalImg?.localUrl != null && originalImg!.localUrl != "") {
        try {
          ImageConfiguration configuration = const ImageConfiguration();
          final image = FileImage(File((originalImg.localUrl!)));

          image.resolve(configuration).addListener(
              ImageStreamListener((ImageInfo image, bool synchronousCall) {
            final tempImg = image.image;
            _preloadImageMap[msgItem.seq! +
                msgItem.timestamp.toString() +
                (msgItem.msgID ?? "")] = tempImg;
            outputLogger.i("cacheImage ${msgItem.msgID}");
          }));
        } catch (e) {
          outputLogger.i("cacheImage error ${msgItem.msgID}");
        }
      }
    }
  }

  int getMessageProgress(String? msgID) {
    return _messageListProgressMap[msgID] ?? 0;
  }

  String getFileMessageLocation(String? msgID) {
    return _fileListLocationMap[msgID] ?? '';
  }

  setMessageProgress(String msgID, int progress) {
    _messageListProgressMap[msgID] = progress;
    if (progress > 0 && progress < 100) {
      _isDownloading = true;
    } else {
      _isDownloading = false;
      _waitingDownloadList.removeWhere((element) {
        String msgIDItem = element["msgID"] ?? "";
        if (msgIDItem.isNotEmpty) {
          if (msgID == msgIDItem) {
            outputLogger.i("remove download");
            return true;
          }
        }
        return false;
      });
    }
  }

  setFileMessageLocation(String msgID, String location) {
    _fileListLocationMap[msgID] = location;
    notifyListeners();
  }

  _editStatusCheck(V2TimMessage msg) {
    bool isStatusMessage = false;
    if (msg.customElem != null &&
        TencentUtils.checkString(msg.groupID) == null) {
      V2TimCustomElem customElem = msg.customElem!;
      String sender = msg.sender ?? "";
      if (customElem.data!.isNotEmpty) {
        try {
          Map<String, dynamic>? data = json.decode(customElem.data ?? "");
          if (data != null) {
            var businessID = data["businessID"];
            int? userAction = data["userAction"];
            String? actionParam = data["actionParam"];
            if (businessID.toString() == "user_typing_status") {
              int? typingStatus = data["typingStatus"];
              if (sender != "") {
                if (typingStatus != null) {
                  setC2cMessageEditStatus(sender, typingStatus);
                } else {
                  // 兼容旧版本逻辑
                  if (userAction != null) {
                    if (userAction == 14) {
                      if (actionParam != null) {
                        setC2cMessageEditStatus(sender,
                            actionParam == "EIMAMSG_InputStatus_Ing" ? 1 : 0);
                      }
                    }
                  }
                }
              }
              return true;
            }
          }
        } catch (err) {
          // err;
        }
      }
    }
    return isStatusMessage;
  }

  _checkFromUserisActive(V2TimMessage msg) async {
    // check message is c2c message and message cloudcustomdata field is not null
    if (msg.groupID == null && msg.cloudCustomData != null) {
      try {
        Map<String, dynamic> data = json.decode(msg.cloudCustomData ?? "");
        Map<String, dynamic>? messageFeature = data["messageFeature"];
        if (messageFeature != null) {
          int needTyping = messageFeature["needTyping"];
          if (needTyping == 1) {
            _c2cMessageFromUserActiveMap[msg.sender ?? ""] = true;

            if (_c2cMessageActiveTimer[msg.sender ?? ""] != null) {
              Timer? t = _c2cMessageActiveTimer[msg.sender ?? ""];
              if (t != null && t.isActive) {
                //取消原来的定时器
                t.cancel();
              }
            }
            _c2cMessageActiveTimer[msg.sender ?? ""] =
                Timer.periodic(const Duration(seconds: 30), (timer) {
              _c2cMessageFromUserActiveMap[msg.sender ?? ""] = false;
              Timer? t = _c2cMessageActiveTimer[msg.sender ?? ""];
              if (t != null && t.isActive) {
                // 取消当前的定时器
                t.cancel();
              }
            });
          }
        }
      } catch (err) {
        // err
      }
    }
  }

  sendEditStatusMessage(bool isEditing, String toUser) async {
    if (!_showC2cMessageEditStatus) {
      return;
    }
    if (!(_c2cMessageFromUserActiveMap[toUser] ?? false)) {
      return;
    }
    V2TimMsgCreateInfoResult? res = await _messageService.createCustomMessage(
        data: json.encode({
      "businessID": "user_typing_status",
      "typingStatus": isEditing == true ? 1 : 0,
      "userAction": 14,
      "version": 0,
      "actionParam": isEditing == true
          ? "EIMAMSG_InputStatus_Ing"
          : "EIMAMSG_InputStatus_End"
    }));
    if (res != null) {
      _sendMessage(
        id: res.id!,
        convID: toUser,
        convType: ConvType.c2c,
        onlineUserOnly: true,
        isEditStatusMessage: true,
      );
    }
  }

  void refreshGroupApplicationList() async {
    final res = await _groupServices.getGroupApplicationList();
    _groupApplicationList = res.data?.groupApplicationList?.map((item) {
          final V2TimGroupApplication applicationItem = item!;
          return applicationItem;
        }).toList() ??
        [];
    notifyListeners();
  }

  cancelAllTimer() {
    _c2cMessageActiveTimer.forEach((key, value) {
      if (value.isActive) {
        value.cancel();
      }
    });
    _c2cMessageStatusShowTimer.forEach((key, value) {
      if (value.isActive) {
        value.cancel();
      }
    });
  }

  _onReceiveNewMsg(V2TimMessage msgComing) async {
    final convID =
        TencentUtils.checkString(msgComing.userID) ?? msgComing.groupID;
    if (convID != currentSelectedConv) {
      return;
    }

    final V2TimMessage? newMsg = _lifeCycle?.newMessageWillMount != null
        ? await _lifeCycle?.newMessageWillMount(msgComing)
        : msgComing;
    if (newMsg == null) {
      return;
    }
    // check the message is editing status msg. and flutter is only support the latest version
    bool isEditMessage = _editStatusCheck(msgComing);

    // if the message is edit status message don't up to screen
    if (isEditMessage) {
      return;
    }

    _checkFromUserisActive(msgComing);
    final convType = TencentUtils.checkString(newMsg.groupID) != null
        ? ConvType.group
        : ConvType.c2c;
    if (convID != null && convID == currentSelectedConv) {
      // when receive new message in the current chat page, we need to mark the message as read.
      if (chatConfig.isAutoReportRead) {
        Future.delayed(const Duration(seconds: 1), () {
          markMessageAsRead(
            convID: convID,
            convType: convType,
          );
        });
      }

      final position = getMessageListPosition(convID);
      if (position == HistoryMessagePosition.notShowLatest) {
        return;
      }
      if (position == HistoryMessagePosition.bottom &&
          unreadCountForTongue == 0) {
        _unreadCountForTongue = 0;
        _receivedNewMessageCount = 0;
        final tempCurrentMsgList = _messageListMap[convID] ?? [];
        _messageListMap[convID] = [newMsg, ...tempCurrentMsgList];
        notifyListeners();
      } else {
        if (convID == currentSelectedConv) {
          unreadCountForTongue++;
          _receivedNewMessageCount++;
          _receivedUnreadMessageList.add(newMsg);
          final currentMsg = _messageListMap[convID] ?? [];
          _messageListMap[convID] = [newMsg, ...currentMsg];
          notifyListeners();
        }
      }
    } else if (convID != null) {
      final tempCurrentMsgList = _messageListMap[convID] ?? [];
      _messageListMap[convID] = [newMsg, ...tempCurrentMsgList];
      notifyListeners();
    }
  }

  onMessageRevoked(String msgID, [String? convID]) {
    final activeMessageList = _messageListMap[convID ?? currentSelectedConv];
    if (activeMessageList != null) {
      final findIndex =
          activeMessageList.indexWhere((element) => element.msgID == msgID);
      if (findIndex != -1) {
        final targetItem = activeMessageList[findIndex];
        targetItem.status = MessageStatus.V2TIM_MSG_STATUS_LOCAL_REVOKED;
        targetItem.id = DateTime.now().millisecondsSinceEpoch.toString();
        activeMessageList[findIndex] = targetItem;

        bool isUnreadMessage =
            _receivedUnreadMessageList.any((element) => element.msgID == msgID);
        if (!(targetItem.isSelf ?? true) && isUnreadMessage) {
          if (_unreadCountForTongue > 0) {
            if (_unreadCountForTongue > 0) {
              _unreadCountForTongue--;
            }
            if (_receivedNewMessageCount > 0) {
              _receivedNewMessageCount--;
            }

            _receivedUnreadMessageList
                .removeWhere((element) => element.msgID == targetItem.msgID);
          }
        }
      }

      _messageListMap[convID ?? currentSelectedConv] = activeMessageList;
      notifyListeners();
    }
  }

  onMessageModified(V2TimMessage modifiedMessage, [String? convID]) async {
    modifiedMessage.id = DateTime.now().millisecondsSinceEpoch.toString();
    final String? exactId = TencentUtils.checkString(modifiedMessage.userID) ??
        TencentUtils.checkString(modifiedMessage.groupID);
    final activeMessageList = _messageListMap[convID ?? exactId];
    if (activeMessageList == null || activeMessageList.isEmpty) {
      return;
    }
    final V2TimMessage newMsg =
        await _lifeCycle?.modifiedMessageWillMount(modifiedMessage) ??
            modifiedMessage;
    final msgID = newMsg.msgID;
    _messageListMap[convID ?? exactId ?? ""] = activeMessageList.map((item) {
      if (item.msgID == msgID) {
        return newMsg;
      }
      return item;
    }).toList();
    notifyListeners();
  }

  _onReceiveC2CReadReceipt(List<V2TimMessageReceipt> receiptList) {
    for (var receipt in receiptList) {
      final convID = receipt.userID;
      final isNotEmpty = _messageListMap[convID]?.isNotEmpty;
      if (isNotEmpty != null && isNotEmpty) {
        _messageListMap[convID] = _messageListMap[convID]!.map((element) {
          final isSelf = element.isSelf ?? true;
          final isPeerRead = element.isPeerRead ?? false;
          if (isSelf && !isPeerRead) {
            element.isPeerRead = true;
          }
          return element;
        }).toList();
      }
    }
    notifyListeners();
  }

  _onReceiveMessageReadReceipts(List<V2TimMessageReceipt> receiptList) {
    try {
      for (var receipt in receiptList) {
        final msgID = receipt.msgID;
        if (msgID != null) {
          _messageReadReceiptMap[msgID] = receipt;
        }
      }
      notifyListeners();
      // ignore: empty_catches
    } catch (e) {}
  }

  _onSendMessageProgress(V2TimMessage messagae, int progress) {
    outputLogger.i("message progress: $progress");
  }

  Future<void> onMessageDownloadProgressCallback(
      V2TimMessageDownloadProgress messageProgress) async {
    final currentProgress = getMessageProgress(messageProgress.msgID);
    print(
        "onMessageDownloadProgressCallback, ${messageProgress.type} - ${messageProgress.isFinish} - ${messageProgress.currentSize} - $currentProgress - ");

    if (messageProgress.isError || messageProgress.errorCode != 0) {
      V2TimMessage? message =
          await _findAndRetrieveMessage(messageProgress.msgID);
      _handleDownloadError(messageProgress, message);
      return;
    }

    if (messageProgress.isFinish && currentProgress < 100) {
      V2TimMessage? message =
          await _findAndRetrieveMessage(messageProgress.msgID);
      _handleFinishedDownload(messageProgress, message);
      return;
    }

    _updateProgressIfNeeded(messageProgress, currentProgress);
  }

  Future<V2TimMessage?> _findAndRetrieveMessage(String messageId) async {
    final messages =
        await _messageService.findMessages(messageIDList: [messageId]);
    return messages?.first;
  }

  void _handleFinishedDownload(
      V2TimMessageDownloadProgress messageProgress, V2TimMessage? message) {
    if (message != null) {
      bool isImageType =
          message.elemType == MessageElemType.V2TIM_ELEM_TYPE_IMAGE;
      bool isVideoType =
          message.elemType == MessageElemType.V2TIM_ELEM_TYPE_VIDEO;
      const originalImageType = 0;
      if (!isImageType && !isVideoType) {
        _updateMessageLocationAndDownloadFile(messageProgress);
      } else if ((isImageType && messageProgress.type == originalImageType) ||
          (isVideoType && !messageProgress.isSnapshot)) {
        Future.delayed(const Duration(seconds: 1),
            () => _updateMessageAndDownloadFile(message, messageProgress));
      } else {
        return;
      }
    } else {
      _updateMessageLocationAndDownloadFile(messageProgress);
    }
  }

  void _handleDownloadError(
      V2TimMessageDownloadProgress messageProgress, V2TimMessage? message) {
    setMessageProgress(messageProgress.msgID, 0);
    downloadFile();
  }

  void _updateMessageAndDownloadFile(
      V2TimMessage message, V2TimMessageDownloadProgress messageProgress) {
    updateAsyncMessage(
        message,
        TencentUtils.checkString(message.userID) ??
            TencentUtils.checkString(message.groupID) ??
            "");

    _updateMessageLocationAndDownloadFile(messageProgress);
  }

  void _updateMessageLocationAndDownloadFile(
      V2TimMessageDownloadProgress messageProgress) {
    setFileMessageLocation(messageProgress.msgID, messageProgress.path);
    setMessageProgress(messageProgress.msgID, 100);
    downloadFile();
  }

  void _updateProgressIfNeeded(
      V2TimMessageDownloadProgress messageProgress, int currentProgress) {
    try {
      if (messageProgress.totalSize != -1 && !messageProgress.isFinish) {
        int progress = min(
            99,
            (messageProgress.currentSize / messageProgress.totalSize * 100)
                .floor());
        if (progress > 1 && progress > currentProgress) {
          setMessageProgress(messageProgress.msgID, progress);
        }
      }
    } catch (e) {
      outputLogger.i("calculate error: ${messageProgress.toJson()}");
    }
  }

  void addAdvancedMsgListener() {
    _messageService.addAdvancedMsgListener(listener: advancedMsgListener);
  }

  void removeAdvanceMsgListener() {
    _messageService.removeAdvancedMsgListener(listener: advancedMsgListener);
  }

  markMessageAsRead({
    required String convID,
    required ConvType convType,
  }) async {
    if (convType == ConvType.c2c) {
      return _messageService.markC2CMessageAsRead(userID: convID);
    }
    _messageService.markGroupMessageAsRead(groupID: convID);
  }

  Future<V2TimValueCallback<V2TimMessage>?>? sendMessageFromController({
    required V2TimMessage? messageInfo,
    required ConvType convType,
    required String convID,
    ValueChanged<String>? setInputField,
    OfflinePushInfo? offlinePushInfo,
    MessagePriorityEnum priority = MessagePriorityEnum.V2TIM_PRIORITY_NORMAL,
    bool? onlineUserOnly,
    bool? isExcludedFromUnreadCount,
    bool? needReadReceipt,
    String? cloudCustomData,
    String? localCustomData,
  }) {
    final TUIChatModelTools tools = serviceLocator<TUIChatModelTools>();
    List<V2TimMessage> currentHistoryMsgList = _messageListMap[convID] ?? [];
    if (messageInfo != null) {
      final messageInfoWithSender = messageInfo.sender == null
          ? tools.setUserInfoForMessage(messageInfo, messageInfo.id!)
          : messageInfo;
      messageInfoWithSender.status = MessageStatus.V2TIM_MSG_STATUS_SENDING;
      currentHistoryMsgList = [messageInfoWithSender, ...currentHistoryMsgList];
      setMessageList(convID, currentHistoryMsgList);
      if (loadingMessage[convID] != null &&
          loadingMessage[convID]!.isNotEmpty) {
        loadingMessage[convID]!.add(messageInfoWithSender);
      } else {
        loadingMessage[convID] = <V2TimMessage>[messageInfoWithSender];
      }
      return _sendMessage(
        priority: priority,
        onlineUserOnly: onlineUserOnly,
        isExcludedFromUnreadCount: isExcludedFromUnreadCount,
        needReadReceipt: needReadReceipt,
        cloudCustomData: cloudCustomData,
        localCustomData: localCustomData,
        isExcludedFromContentModeration:
            messageInfo.isExcludedFromContentModeration ?? false,
        convID: convID,
        setInputField: setInputField,
        id: messageInfo.id as String,
        convType: ConvType.values[convType.index],
        offlinePushInfo: offlinePushInfo ??
            tools.buildMessagePushInfo(
                messageInfo, convID, ConvType.values[convType.index]),
      );
    }
    return null;
  }

  Future<V2TimValueCallback<V2TimMessage>?> sendReplyMessageFromController({
    required String text,
    required V2TimMessage messageBeenReplied,
    required String convID,
    required ConvType convType,
    ValueChanged<String>? setInputField,
    OfflinePushInfo? offlinePushInfo,
    MessagePriorityEnum priority = MessagePriorityEnum.V2TIM_PRIORITY_NORMAL,
    bool? onlineUserOnly,
    bool? isExcludedFromUnreadCount,
    bool? needReadReceipt,
    String? localCustomData,
  }) async {
    if (text.isEmpty) {
      return null;
    }
    final TUIChatModelTools tools = serviceLocator<TUIChatModelTools>();
    List<V2TimMessage> currentHistoryMsgList = _messageListMap[convID] ?? [];
    V2TimMsgCreateInfoResult? textMessageInfo =
        await _messageService.createTextMessage(text: text);

    textMessageInfo = await _messageService.createTextAtMessage(
        text: text +
            "\n@${TencentUtils.checkString(messageBeenReplied.nickName) ?? TencentUtils.checkString(messageBeenReplied.sender) ?? TencentUtils.checkString(messageBeenReplied.userID)}",
        atUserList: [
          TencentUtils.checkString(messageBeenReplied.sender) ??
              TencentUtils.checkString(messageBeenReplied.userID) ??
              ""
        ]);

    final V2TimMessage? messageInfo = textMessageInfo!.messageInfo;

    if (messageInfo != null) {
      final messageInfoWithSender = messageInfo.sender == null
          ? tools.setUserInfoForMessage(
              messageInfo, messageInfo.id ?? textMessageInfo.id ?? "")
          : messageInfo;
      messageInfoWithSender.status = MessageStatus.V2TIM_MSG_STATUS_SENDING;
      final hasNickName = messageBeenReplied.nickName != null &&
          messageBeenReplied.nickName != "";
      final cloudCustomData = {
        "messageReply": {
          "messageID": messageBeenReplied.msgID,
          "messageAbstract": tools.getMessageAbstract(
              messageBeenReplied, abstractMessageBuilder),
          "messageSender": hasNickName
              ? messageBeenReplied.nickName
              : messageBeenReplied.sender,
          "messageType": messageBeenReplied.elemType,
          "version": 1
        }
      };
      messageInfoWithSender.cloudCustomData = json.encode(cloudCustomData);

      currentHistoryMsgList = [messageInfoWithSender, ...currentHistoryMsgList];
      setMessageList(convID, currentHistoryMsgList);

      return _sendMessage(
        cloudCustomData: json.encode(cloudCustomData),
        id: textMessageInfo.id as String,
        offlinePushInfo: offlinePushInfo ??
            tools.buildMessagePushInfo(
                messageInfo, convID, ConvType.values[convType.index]),
        priority: priority,
        onlineUserOnly: onlineUserOnly,
        isExcludedFromUnreadCount: isExcludedFromUnreadCount,
        needReadReceipt: needReadReceipt,
        localCustomData: localCustomData,
        convID: convID,
        setInputField: setInputField,
        convType: ConvType.values[convType.index],
      );
    }
    return null;
  }

  Future<bool> setLocalCustomData(
      String msgID, String localCustomData, String conversationID) async {
    final res = await _messageService.setLocalCustomData(
        msgID: msgID, localCustomData: localCustomData);
    List<V2TimMessage> messageList = _messageListMap[conversationID] ?? [];
    if (res.code == 0) {
      messageList = messageList.map((item) {
        if (item.msgID == msgID) {
          item.localCustomData = localCustomData;
          // item.id = DateTime.now().millisecondsSinceEpoch.toString();
        }
        return item;
      }).toList();
      setMessageList(conversationID, messageList,
          needResetNewMessageCount: false);
      return true;
    }
    return false;
  }

  Future<bool> setLocalCustomInt(
      String msgID, int localCustomInt, String conversationID) async {
    final res = await _messageService.setLocalCustomInt(
        msgID: msgID, localCustomInt: localCustomInt);
    List<V2TimMessage> messageList = _messageListMap[conversationID] ?? [];
    if (res.code == 0) {
      messageList = messageList.map((item) {
        if (item.msgID == msgID) {
          item.localCustomInt = HistoryMessageDartConstant.read;
          // item.id = DateTime.now().millisecondsSinceEpoch.toString();
        }
        return item;
      }).toList();
      setMessageList(conversationID, messageList,
          needResetNewMessageCount: false);
      return true;
    }
    return false;
  }

  Future<V2TimValueCallback<V2TimMessage>> _sendMessage({
    required String id,
    required String convID,
    required ConvType convType,
    OfflinePushInfo? offlinePushInfo,
    bool? onlineUserOnly = false,
    bool? isEditStatusMessage = false,
    GroupReceiptAllowType? groupType,
    ValueChanged<String>? setInputField,
    MessagePriorityEnum priority = MessagePriorityEnum.V2TIM_PRIORITY_NORMAL,
    bool? isExcludedFromUnreadCount,
    bool? needReadReceipt,
    String? cloudCustomData,
    String? localCustomData,
    bool isExcludedFromContentModeration = false,
  }) async {
    String receiver = convType == ConvType.c2c ? convID : '';
    String groupID = convType == ConvType.group ? convID : '';
    final sendMsgRes = await _messageService.sendMessage(
        id: id,
        receiver: receiver,
        needReadReceipt: needReadReceipt ?? chatConfig.isShowReadingStatus,
        groupID: groupID,
        priority: priority,
        localCustomData: localCustomData,
        isExcludedFromUnreadCount: isExcludedFromUnreadCount ?? false,
        offlinePushInfo: offlinePushInfo,
        isExcludedFromContentModeration: isExcludedFromContentModeration,
        onlineUserOnly: onlineUserOnly ?? false,
        cloudCustomData: cloudCustomData ??
            json.encode({
              "messageFeature": {
                "needTyping": 1,
                "version": 1,
              }
            }));
    if (isEditStatusMessage == false) {
      updateMessage(sendMsgRes, convID, id, convType, groupType, setInputField);
    }
    if (_lifeCycle?.messageDidSend != null) {
      _lifeCycle!.messageDidSend(sendMsgRes);
    }

    return sendMsgRes;
  }

  void setMessageList(String conversationID, List<V2TimMessage> messageList,
      {bool needResetNewMessageCount = true, bool isDeleteMsg = false}) {
    print("ddd==setList$conversationID, ${messageList.length}");
    _messageListMap[conversationID] = messageList;
    if (needResetNewMessageCount) {
      _receivedNewMessageCount = 0;
    }

    if (isDeleteMsg) {
      HistoryMessagePosition position = getMessageListPosition(conversationID);
      if (position == HistoryMessagePosition.awayTwoScreen) {
        _historyMessagePositionMap[conversationID] =
            HistoryMessagePosition.notShowLatest;
      }
    }

    notifyListeners();
  }

  updateMessage(
      V2TimValueCallback<V2TimMessage> sendMsgRes,
      String convID,
      String id,
      ConvType convType,
      GroupReceiptAllowType? groupType,
      ValueChanged<String>? setInputField) {
    List<V2TimMessage> currentHistoryMsgList = _messageListMap[convID] ?? [];
    final V2TimMessage sendMsgResData = sendMsgRes.data as V2TimMessage;
    final findIdIndex =
        currentHistoryMsgList.indexWhere((element) => element.id == id);
    final targetIndex = findIdIndex == -1
        ? currentHistoryMsgList
            .indexWhere((element) => element.msgID == sendMsgResData.msgID)
        : findIdIndex;
    if (targetIndex != -1) {
      currentHistoryMsgList[targetIndex] = sendMsgResData;
    } else {
      currentHistoryMsgList = [sendMsgResData, ...currentHistoryMsgList];
    }
    if (loadingMessage[convID] != null && loadingMessage[convID]!.isNotEmpty) {
      loadingMessage[convID]!.removeWhere((element) => element.id == id);
    }
    if (chatConfig.isShowReadingStatus && sendMsgRes.data?.msgID != null) {
      _messageReadReceiptMap[sendMsgRes.data!.msgID!] =
          V2TimMessageReceipt(timestamp: 0, userID: "", readCount: 0);
    }
    _messageListMap[convID] = currentHistoryMsgList;
    notifyListeners();
  }

  void updateAsyncMessage(
    V2TimMessage message,
    String convID,
  ) {
    message.id = DateTime.now().millisecondsSinceEpoch.toString();

    final activeMessageList = _messageListMap[convID];
    if (activeMessageList == null || activeMessageList.isEmpty) {
      return;
    }
    final msgID = message.msgID;
    _messageListMap[convID] = activeMessageList.map((item) {
      if (item.msgID == msgID) {
        return message;
      }
      return item;
    }).toList();
    if (convID == currentSelectedConv) {
      notifyListeners();
    }
  }

  List<V2TimMessage>? getMessageList(String conversationID) {
    final list = (messageListMap[conversationID]?.reversed.toList() ?? [])
        .where((element) => _lifeCycle?.messageShouldMount(element) ?? true)
        .toList();
    final finalList = _lifeCycle?.messageListShouldMount(list) ?? list;
    final List<V2TimMessage> listWithTimestamp = [];
    final interval = chatConfig.timeDividerConfig?.timeInterval ?? 300;
    for (var item in finalList) {
      {
        if (listWithTimestamp.isEmpty ||
            (listWithTimestamp[listWithTimestamp.length - 1].timestamp !=
                    null &&
                item.timestamp != null &&
                (item.timestamp! -
                        listWithTimestamp[listWithTimestamp.length - 1]
                            .timestamp! >
                    interval))) {
          listWithTimestamp.add(V2TimMessage(
            userID: '',
            isSelf: false,
            elemType: 11,
            msgID: 'time-divider-${item.timestamp}',
            timestamp: item.timestamp,
          ));
        }
        listWithTimestamp.add(item);
      }
    }
    return listWithTimestamp.reversed.toList();
  }

  HistoryMessagePosition getMessageListPosition(String? conversationID) {
    final HistoryMessagePosition? position =
        _historyMessagePositionMap[conversationID];
    if (position == null) {
      _historyMessagePositionMap[conversationID ?? currentSelectedConv] =
          HistoryMessagePosition.bottom;
      return HistoryMessagePosition.bottom;
    } else {
      return position;
    }
  }

  void setMessageListPosition(
      String conversationID, HistoryMessagePosition position) {
    _historyMessagePositionMap[conversationID] = position;
    notifyListeners();
  }
}
