import 'dart:io';

class MockHttpConnectionInfo implements HttpConnectionInfo {
  @override
  final InternetAddress remoteAddress;
  @override
  final int localPort, remotePort;

  MockHttpConnectionInfo({this.remoteAddress, this.localPort, this.remotePort});
}
