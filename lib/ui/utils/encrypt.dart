import 'dart:convert';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart';
import 'package:pointycastle/digests/sha256.dart';
import 'package:pointycastle/key_derivators/api.dart';
import 'package:pointycastle/key_derivators/pbkdf2.dart';
import 'package:pointycastle/macs/hmac.dart';

class Encrypt {
  late final String password;
  late final Uint8List salt;
  late final Uint8List iv;
  late final Key _key;

  int? appID;
  String? appSign;

  static final Encrypt shared = Encrypt();

  Encrypt() {
    password = "123123";
    salt = base64.decode("YWFhYWFhYWFhYWFhYWFhYQ==");
    iv = base64.decode("YmJiYmJiYmJiYmJiYmJiYg==");
    _validateParameters();
    _key = _deriveKey();
  }

  // 验证参数有效性
  void _validateParameters() {
    if (password.isEmpty) throw ArgumentError('Password cannot be empty');
    if (salt.length < 8) throw ArgumentError('Salt must be at least 8 bytes');
    if (iv.length != 16) throw ArgumentError('IV must be exactly 16 bytes');
  }

  Key _deriveKey() {
    final hmac = HMac(SHA256Digest(), 64); // SHA256 区块大小=64字节

    final generator = PBKDF2KeyDerivator(hmac)
      ..init(Pbkdf2Parameters(salt, 10000, 32)); // 32字节 = 256位

    final keyBytes = generator.process(utf8.encode(password));
    return Key(keyBytes);
  }

  // 加密字符串
  String encrypt(String text) {
    if (text.isEmpty) return "";
    final encrypter = Encrypter(AES(_key, mode: AESMode.cbc));
    final encrypted = encrypter.encrypt(text, iv: IV(iv));
    return base64.encode(encrypted.bytes);
  }

  // 解密字符串
  String decrypt(String text) {
    if (text.isEmpty) return "";
    final t = base64.decode(text);
    final encrypter = Encrypter(AES(_key, mode: AESMode.cbc));
    return encrypter.decrypt(Encrypted(t), iv: IV(iv));
  }

  // 加密二进制数据
  Uint8List encryptBytes(Uint8List data) {
    final encrypter = Encrypter(AES(_key, mode: AESMode.cbc));
    final encrypted = encrypter.encryptBytes(data, iv: IV(iv));
    return encrypted.bytes;
  }

  // 解密二进制数据
  List<int> decryptBytes(Uint8List cipherText) {
    final encrypter = Encrypter(AES(_key, mode: AESMode.cbc));
    return encrypter.decryptBytes(Encrypted(cipherText), iv: IV(iv));
  }
}
