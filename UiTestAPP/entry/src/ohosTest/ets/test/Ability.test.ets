import hilog from '@ohos.hilog';
import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import socket from '@ohos.net.socket';
import { BusinessError } from '@ohos.base';
import request from '@ohos.request';

import { action, myPrint, sleep } from './UiTestProcess';

class SocketInfo {
  message: ArrayBuffer = new ArrayBuffer(1);
  remoteInfo: socket.SocketRemoteInfo = {} as socket.SocketRemoteInfo;
}

function socketSend(client: socket.TCPSocketConnection, data: string){
  myPrint(`socket send: ${data}`);
  let tcpSendOptions : socket.TCPSendOptions = {} as socket.TCPSendOptions;
  tcpSendOptions.data = data;
  client.send(tcpSendOptions, (err: BusinessError) => {
    if (err) {
      myPrint("send fail");
      return;
    }
    myPrint("send success");
  });
}

function startSocketServer(port: number){
  // 创建一个TCPSocketServer连接，返回一个TCPSocketServer对象。
  let tcpServer = socket.constructTCPSocketServerInstance();
  // 绑定本地IP地址和端口，进行监听

  let ipAddress : socket.NetAddress = {} as socket.NetAddress;
  ipAddress.address = "0.0.0.0";
  ipAddress.port = port;
  tcpServer.listen(ipAddress, (err: BusinessError) => {
    if (err) {
      myPrint("listen fail");
      return;
    }
    myPrint("listen success");

    tcpServer.getState().then((data: socket.SocketStateBase) => {
      myPrint('getState success' + JSON.stringify(data));
    }).catch((err: BusinessError) => {
      myPrint('getState fail');
    });
  });

  let tcpExtraOptions: socket.TCPExtraOptions = {
    keepAlive: true,
    OOBInline: false,
    TCPNoDelay: true,
    socketLinger: { on: false, linger: 1 },
    receiveBufferSize: 1024,
    sendBufferSize: 1024,
    reuseAddress: true,
    socketTimeout: 0
  }
  tcpServer.setExtraOptions(tcpExtraOptions).then(() => {
    myPrint('setExtraOptions success');
  }).catch((err: BusinessError) => {
    myPrint('setExtraOptions fail');
  });
  
  // 订阅TCPSocketServer的connect事件
  tcpServer.on("connect", (client: socket.TCPSocketConnection) => {
    myPrint(`on connect: ${client.clientId}`);
    // 订阅TCPSocketConnection相关的事件
    client.on("close", () => {
      myPrint(`on close success: ${client.clientId}`);
    });
    client.on("message", (value: SocketInfo) => {
      let buffer = value.message;
      let dataView = new DataView(buffer);
      let str = "";
      for (let i = 0; i < dataView.byteLength; ++i) {
        str += String.fromCharCode(dataView.getUint8(i));
      }
      myPrint("received message--:" + str);
      // myPrint("received address--:" + value.remoteInfo.address);
      // myPrint("received family--:" + value.remoteInfo.family);
      // myPrint("received port--:" + value.remoteInfo.port);
      // myPrint("received size--:" + value.remoteInfo.size);

      if (str=="hello"){
        socketSend(client, "Hello client!");
        return;
      }

      // msg = msg.split('\\"').join('"');
      myPrint(`msg: ${str}`);
      let msg = str.split("'").join('"');
      // myPrint(`msg: ${msg}`);
      const msgJson: Map<string, string> = JSON.parse(msg);
      myPrint(`msgJson: ${JSON.stringify(msgJson)}`);
      // myPrint(`msgJson: ${msgJson["action"]}`);
      action(msgJson).then((sendData:request.RequestData[])=>{
        myPrint(`action resp: ${JSON.stringify(sendData)}`);
        let retMap:Map<string,string> = new Map<string,string>();
        for (let rr of sendData){
          retMap[rr.name] = rr.value
        }
        socketSend(client, JSON.stringify(retMap));
      });

    });

    // 向客户端发送数据
    // socketSend(client, "Hello, client!")
    
  });
  
}

async function uiTestProcess(serverPort:number) {
  try {
    startSocketServer(serverPort);

    await sleep(86400*1000);
  }catch(aa){
    myPrint("test err: " + JSON.stringify(aa))
  }

}

async function uiTestProcess29100(){
  await uiTestProcess(29100);
}

async function uiTestProcess29200(){
  await uiTestProcess(29200);
}

async function uiTestProcess29300(){
  await uiTestProcess(29300);
}

async function uiTestProcess29400(){
  await uiTestProcess(29400);
}

async function uiTestProcess29500(){
  await uiTestProcess(29500);
}

export default function abilityTest() {
  describe('ActsAbilityTest', () => {
    // Defines a test suite. Two parameters are supported: test suite name and test suite function.
    beforeAll(() => {
      // Presets an action, which is performed only once before all test cases of the test suite start.
      // This API supports only one parameter: preset action function.
    })
    beforeEach(() => {
      // Presets an action, which is performed before each unit test case starts.
      // The number of execution times is the same as the number of test cases defined by **it**.
      // This API supports only one parameter: preset action function.
    })
    afterEach(() => {
      // Presets a clear action, which is performed after each unit test case ends.
      // The number of execution times is the same as the number of test cases defined by **it**.
      // This API supports only one parameter: clear action function.
    })
    afterAll(() => {
      // Presets a clear action, which is performed after all test cases of the test suite end.
      // This API supports only one parameter: clear action function.
    })
    it('uiTestProcess29100', 0, uiTestProcess29100)

    it('uiTestProcess29200', 0, uiTestProcess29200)

    it('uiTestProcess29300', 0, uiTestProcess29300)

    it('uiTestProcess29400', 0, uiTestProcess29400)

    it('uiTestProcess29500', 0, uiTestProcess29500)
  })
}