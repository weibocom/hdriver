import {Component, Driver, UiWindow, ON, MatchPattern, DisplayRotation, ResizeDirection, UiDirection, MouseButton, WindowMode, PointerMatrix,
  On } from '@ohos.UiTest';
import request from '@ohos.request';
import { BusinessError } from '@ohos.base';
import fs from '@ohos.file.fs'
import util from '@ohos.util'
import buffer from '@ohos.buffer';
import AbilityDelegatorRegistry from '@ohos.app.ability.abilityDelegatorRegistry';

let abilityDelegator: AbilityDelegatorRegistry.AbilityDelegator;
abilityDelegator = AbilityDelegatorRegistry.getAbilityDelegator();

let driver:Driver = Driver.create();
let eleMap:Map<string, Component> = new Map<string, Component>();

export function myPrint(message: string){
  console.info("UiTestCase: "+message);
}

export function sleep(time: number) {
  return new Promise<void>((resolve: Function) => setTimeout(resolve, time));
}

async function execShell(cmd:string) {
  abilityDelegator.executeShellCommand(cmd, (err : BusinessError, data: AbilityDelegatorRegistry.ShellCmdResult) => {
    console.info('UiTestCase: executeShellCommand callback: ' + data.stdResult);
  });
}

async function getProperty(eleGet:Component, property:string):Promise<string> {
  let retProperty:string;
  switch(property){
    case "id":
      retProperty = await eleGet.getId();
      break;
    case "text":
      retProperty = await eleGet.getText();
      break;
    case "type":
      retProperty = await eleGet.getType();
      break;
    case "bounds":
      retProperty = JSON.stringify(await eleGet.getBounds());
      break;
    case "boundsCenter":
      retProperty = JSON.stringify(await eleGet.getBoundsCenter());
      break;
    default:
      retProperty = `unknown property: ${property}`;
  }

  return retProperty;
}

async function doOperate(eleOperate:Component, operate:string, extend:string):Promise<boolean> {
  let ret:boolean = true;
  switch(operate){
    case "tap":
      await eleOperate.click();
      eleMap = new Map<string, Component>();
      break;
    case "input":
      await eleOperate.inputText(extend);
      break;
    case "clear":
      await eleOperate.clearText();
      break;
    default:
      ret = false;
  }
  await commonWaitIdle();
  return ret;
}

async function getOn(by:string, data:string):Promise<On|null>{
  let curOn:On;
  // myPrint(`by: ${by}. data: ${data}`)
  switch(by){
    case "id":
      curOn = ON.id(data);
      break;
    case "text":
      curOn = ON.text(data);
      break;
    case "type":
      curOn = ON.type(data);
      break;
    default:
      return null;
  }
  return curOn;
}

async function commonWaitIdle(){
  myPrint(`before waitIdle}`);
  let waitIdle = await driver.waitForIdle(2000, 5000);
  myPrint(`waitIdle: ${waitIdle}`);
}

// export async function action(context: Context, msg:Map<string, string>): Promise<request.RequestData[]> {
export async function action(msg:Map<string, string>): Promise<request.RequestData[]> {
  // myPrint("action start");
  let sendData:request.RequestData[]=[];
  try {
    // myPrint(`msg: ${JSON.stringify(msg)}`);
    if (msg["uuid"]==undefined){
      return sendData.concat([{name:"ret", value:"error"}, {name:"description", value:"msg must include parameter 'uuid'"}]);
    }
    const uuid:string = msg["uuid"];
    sendData.push({name:"uuid", value:uuid});
    if (msg["action"]==undefined){
      return [{name:"ret", value:"error"}, {name:"description", value:"msg must include parameter 'action'"}];
    }
    const action:string = msg["action"];
    // myPrint(`action: ${action}. uuid: ${uuid}`)

    switch(action){
      case "find":
        if (msg["by"]==undefined){
          return sendData.concat([{name:"ret", value:"error"}, {name:"description", value:"msg must include parameter 'by'"}]);
        }
        if (msg["data"]==undefined){
          return sendData.concat([{name:"ret", value:"error"}, {name:"description", value:"msg must include parameter 'data'"}]);
        }
        let by:string = msg["by"];
        let data:string = msg["data"];
        let curOn:On|null = await getOn(by, data)
        if (curOn==null) {
          return sendData.concat([{name:"ret", value:"error"}, {name:"description", value:`unknown by: ${by}`}]);
        }
        let ele:Component;
        if (msg["timeout_s"]==undefined || msg["timeout_s"]=="0") {
           ele = await driver.findComponent(curOn!);
        }else{
          ele = await driver.waitForComponent(curOn!, Number(msg["timeout_s"])*1000);
        }
        if (ele==null){
          return sendData.concat([{name:"ret", value:"error"}, {name:"description", value:`no ele: ${by} ${data}`}]);
        }
        eleMap[uuid] = ele;
        sendData.push({name:"euid", value:uuid});
        // myPrint(`attributes: ${msg["attributes"]}`);
        if (msg["attributes"]!=undefined && msg["attributes"]!="None"){
          let attributes:string[] = msg["attributes"].split(",");
          // myPrint(`attributes: ${attributes}`);
          for(let attribute of attributes){
            let retProperty:string = await getProperty(ele, attribute);
            if (retProperty.startsWith("unknown property")){
              return sendData.concat([{name:"ret", value:"error"}, {name:"description", value:`unknown property: ${attribute}`}]);
            }
            sendData.push({name:attribute, value:retProperty});
          }
        }
        if (msg["operates"]!=undefined && msg["operates"]!="None"){
          let operates:string[] = msg["operates"].split(",");
          for(let operate of operates){
            let inputText = "";
            if (operate=="input"){
              if (msg["extend"]==undefined) {
                return sendData.concat([{ name: "ret", value: "error" }, {name: "description", value: "'input' msg must include parameter 'extend'"}]);
              }
              inputText = msg["extend"];
            }
            let retOperate:boolean = await doOperate(ele, operate, inputText);
            if (!retOperate){
              return sendData.concat([{name:"ret", value:"error"}, {name:"description", value:`unknown operate: ${operate}`}]);
            }
          }
        }
        return sendData;
        break;
      case "finds":
        if (msg["by"]==undefined){
          return sendData.concat([{name:"ret", value:"error"}, {name:"description", value:"msg must include parameter 'by'"}]);
        }
        if (msg["data"]==undefined){
          return sendData.concat([{name:"ret", value:"error"}, {name:"description", value:"msg must include parameter 'data'"}]);
        }
        let byFinds:string = msg["by"];
        let dataFinds:string = msg["data"];
        let curOnFinds:On|null = await getOn(byFinds, dataFinds)
        if (curOnFinds==null) {
          return sendData.concat([{name:"ret", value:"error"}, {name:"description", value:`unknown by: ${byFinds}`}]);
        }
        let eleArray:Component[] = await driver.findComponents(curOnFinds!);
        if (eleArray==null){
          return sendData.concat([{name:"data", value:"[]"}]);
        }
        let eleMapArray:Map<string,string>[] = [];
        for (let ii=0; ii<eleArray.length; ii++){
          let tmpEuid = `${uuid}${ii}`;
          eleMap[tmpEuid] = eleArray[ii];
          let tmpE:Map<string,string> = new Map<string,string>();
          tmpE["euid"] = tmpEuid;
          eleMapArray.push(tmpE)
          // myPrint(`${tmpEuid}  ${JSON.stringify(tmpE)}  ${JSON.stringify(eleMapArray)}`);
        }

        if (msg["attributes"]!=undefined && msg["attributes"]!="None"){
          let attributes:string[] = msg["attributes"].split(",");
          for (let eleIndex=0;eleIndex<eleArray.length;eleIndex++) {
            for (let attribute of attributes) {
              let retProperty: string = await getProperty(eleArray[eleIndex], attribute);
              if (retProperty.startsWith("unknown property")) {
                return sendData.concat([{ name: "ret", value: "error" }, {name: "description",value: `unknown property: ${attribute}`}]);
              }
              eleMapArray[eleIndex][attribute] = retProperty;
            }
          }
        }
        if (msg["operates"]!=undefined && msg["operates"]!="None"){
          let operates:string[] = msg["operates"].split(",");
          for (let eleIndex=0;eleIndex<eleArray.length;eleIndex++) {
            for (let operate of operates) {
              let inputText = "";
              if (operate == "input") {
                if (msg["extend"] == undefined) {
                  return sendData.concat([{ name: "ret", value: "error" }, {name: "description",value: "'input' msg must include parameter 'extend'"}]);
                }
                inputText = msg["extend"];
              }
              let retOperate: boolean = await doOperate(eleArray[eleIndex], operate, inputText);
              if (!retOperate) {
                return sendData.concat([{ name: "ret", value: "error" }, {name: "description",value: `unknown operate: ${operate}`}]);
              }
            }
          }
        }
        return sendData.concat([{name:"data", value:JSON.stringify(eleMapArray)}]);
        break;
      case  "get":
        if (msg["euid"]==undefined){
          return sendData.concat([{name:"ret", value:"error"}, {name:"description", value:"msg must include parameter 'euid'"}]);
        }
        if (msg["property"]==undefined){
          return sendData.concat([{name:"ret", value:"error"}, {name:"description", value:"msg must include parameter 'property'"}]);
        }
        let euidGet:string = msg["euid"];
        let property:string = msg["property"];
        let eleGet:Component = eleMap[euidGet];
        if (eleGet==undefined){
          return sendData.concat([{name:"ret", value:"error"}, {name:"description", value:`get ele failed by euid '${euidGet}', before get property`}]);
        }
        let retProperty:string = await getProperty(eleGet, property);
        if (retProperty.startsWith("unknown property")){
          return sendData.concat([{name:"ret", value:"error"}, {name:"description", value:`unknown property: ${property}`}]);
        }
        return sendData.concat([{name:"data", value:retProperty}])
      case "operate":
        if (msg["euid"]==undefined){
          return sendData.concat([{name:"ret", value:"error"}, {name:"description", value:"msg must include parameter 'euid'"}]);
        }
        if (msg["operate"]==undefined){
          return sendData.concat([{name:"ret", value:"error"}, {name:"description", value:"msg must include parameter 'operate'"}]);
        }
        let euidOperate:string = msg["euid"];
        let operate:string = msg["operate"];
        let eleOperate:Component = eleMap[euidOperate];
        if (eleOperate==undefined){
          return sendData.concat([{name:"ret", value:"error"}, {name:"description", value:`get ele failed by euid '${euidOperate}, before operate'`}]);
        }
        let inputText = "";
        if (operate=="input"){
          if (msg["text"]==undefined) {
            return sendData.concat([{ name: "ret", value: "error" }, {name: "description", value: "msg must include parameter 'text'"}]);
          }
          inputText = msg["text"];
        }
        let retOperate:boolean = await doOperate(eleOperate, operate, inputText);
        if (!retOperate){
          return sendData.concat([{name:"ret", value:"error"}, {name:"description", value:`unknown operate: ${operate}`}]);
        }
        return sendData.concat([{name:"data", value:"ok"}])
      case "tap":
        if (msg["x"]==undefined || msg["y"]==undefined){
          return sendData.concat([{name:"ret", value:"error"}, {name:"description", value:"msg must include parameter 'x' 'y'"}]);
        }
        let x:string = msg["x"];
        let y:string = msg["y"];
        await driver.click(Number(x), Number(y));
        eleMap = new Map<string, Component>();
        await commonWaitIdle();
        return sendData.concat([{name:"data", value:"ok"}])
      case "swipe":
        if (msg["startx"]==undefined || msg["starty"]==undefined || msg["endx"]==undefined || msg["endy"]==undefined || msg["speed"]==undefined){
          return sendData.concat([{name:"ret", value:"error"}, {name:"description", value:"msg must include parameters 'startx' 'starty' 'endx' 'endy' 'speed'"}]);
        }
        let startx:number = Number(msg["startx"]);
        let starty:number = Number(msg["starty"]);
        let endx:number = Number(msg["endx"]);
        let endy:number = Number(msg["endy"]);
        let speed:number = Number(msg["speed"]);
        await driver.swipe(startx, starty, endx, endy, speed);
        eleMap = new Map<string, Component>();
        await commonWaitIdle();
        return sendData.concat([{name:"data", value:"ok"}])
      case "home":
        await driver.pressHome();
        eleMap = new Map<string, Component>();
        await commonWaitIdle();
        return sendData.concat([{name:"data", value:"ok"}])
      case "back":
        await driver.pressBack();
        eleMap = new Map<string, Component>();
        await commonWaitIdle();
        return sendData.concat([{name:"data", value:"ok"}])
      case "currentBundle":
        let window = await driver.findWindow({actived:true});
        let name = await window.getBundleName();
        return sendData.concat([{name:"data", value:name}])
      case "screenSize":
        // let screenSize = await driver.getDisplayDensity();
        let screenSize = await driver.getDisplaySize();
        return sendData.concat([{name:"data", value:JSON.stringify(screenSize)}])
      // case "screenCapture":
      //   let pngPath = `${context.cacheDir}/${uuid}.png`;
      //   let ret:boolean;
      //   if (msg["border"]!=undefined){
      //     let border:string = msg["border"];
      //     let borderRect:Map<string, number> = JSON.parse(border);
      //     if (borderRect["left"]==undefined || borderRect["top"]==undefined || borderRect["right"]==undefined || borderRect["bottom"]==undefined){
      //       return sendData.concat([{name:"ret", value:"error"}, {name:"description", value:"msg must include parameter 'left' 'top' 'right' 'bottom'"}]);
      //     }
      //     // ret = await driver.screenCapture(pngPath, borderRect);
      //     ret = await driver.screenCapture(pngPath);
      //   }else {
      //     ret = await driver.screenCapture(pngPath);
      //   }
      //   if (ret){
      //     let res = fs.accessSync(pngPath);
      //     if (res) {
      //       return sendData.concat([{name:"data", value:pngPath}]);  // hdc
      //
      //       let stat = fs.statSync(pngPath);
      //       // myPrint(`${pngPath}  size: ${stat.size}`);
      //       let pngArrayBuffer = new ArrayBuffer(stat.size);
      //       let file = fs.openSync(pngPath, fs.OpenMode.READ_ONLY);
      //       fs.readSync(file.fd, pngArrayBuffer);
      //       fs.closeSync(file);
      //       // let pngStr = fs.readTextSync(pngPath)
      //       fs.unlink(pngPath).then(()=>{});
      //       // base64
      //       let that = new util.Base64Helper();
      //       let pngStr = that.encodeToStringSync(new Uint8Array(pngArrayBuffer));
      //       // buffer base64
      //       // let pngBuffer = buffer.from(pngArrayBuffer);
      //       // myPrint(`pngBuffer: ${JSON.stringify(pngBuffer)}`);
      //       // let pngStr = buffer.transcode(pngBuffer, "hex", "base64").toString();
      //       // myPrint(`${pngStr.length} pngStr: ${pngStr}`);
      //       return sendData.concat([{name:"data", value:pngStr}])
      //     }
      //   }
      //   return sendData.concat([{name:"ret", value:"error"}, {name:"description", value:"screenCapture failed"}]);
      case "app":
        if (msg["cmd"]==undefined){
          return sendData.concat([{name:"ret", value:"error"}, {name:"description", value:"msg must include parameter 'cmd'"}]);
        }
        if (msg["bundle"]==undefined){
          return sendData.concat([{name:"ret", value:"error"}, {name:"description", value:"msg must include parameter 'bundle'"}]);
        }
        let cmd:string = msg["cmd"];
        let bundle:string = msg["bundle"];
        if (msg["ability"]==undefined && cmd=="start"){
          return sendData.concat([{name:"ret", value:"error"}, {name:"description", value:"msg must include parameter 'ability'"}]);
        }
        let ability:string = msg["ability"];
        let shellCmd:string;
        switch(cmd){
          case "start":
            shellCmd = `aa start -b ${bundle} -a ${ability}`;
            break;
          case "stop":
            shellCmd = `aa force-stop ${bundle}`;
            break;
          default:
            return sendData.concat([{name:"ret", value:"error"}, {name:"description", value:`unknown app cmd: ${cmd}`}]);
        }
        await execShell(shellCmd);
        let appWaitIdle = await driver.waitForIdle(5000, 8000);
        myPrint(`appWaitIdle: ${appWaitIdle}`);
        eleMap = new Map<string, Component>();
        return sendData.concat([{name:"data", value:"ok"}])
      default:
        return sendData.concat([{name:"ret", value:"error"}, {name:"description", value:`unknown action: ${action}`}]);
    }
  } catch (err) {
    console.error(`UiTestCase: action: ${msg}. err: ${err}`);
    return sendData.concat([{name:"ret", value:"error"}, {name:"description", value:`unknown error: ${err}`}]);
  }
}