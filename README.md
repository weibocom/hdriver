# harmony_ui_test

harmony_ui_test包括两部分UiTestAPP和PythonClient，UiTestAPP是ArkTS语言开发的测试APP，其在鸿蒙端启动一个SocketServer，接收PythonClient的指令，执行APP启停、元素查找、点击、滑动等操作，并返回结果。这是一个鸿蒙系统UI测试的端到端测试方案，具备通用设备测试能力。UiTestAPP基于鸿蒙系统提供的“@ohos.UiTest”模块。

## 特点
 * 支持鸿蒙手机、Pad等其他设备
 * 通过USB与鸿蒙设备通信，不依赖网络，快捷高效
 * PythonSocket端相比ArkTS语言更易用，降低了使用门槛
 * Socket长连接通信，高效率低延迟
 * UiTestAPP通过鸿蒙IDE编译安装到设备之后，通过PythonClient即可操作APP的启停和通信，易用

## 使用说明


1. UiTestAPP基于HarmonyOS4.1，按照鸿蒙官方说明安装SDK和DevEco-studio等必要环境后，使用evEco-studio打开UiTestAPP工程，设置dependencies和SigningConfig后，并且鸿蒙设备连接就绪，点击下图箭头所指的绿色按钮，测试APP编译安装


![image](https://git.intra.weibo.com/honglei8/harmony_ui_test/-/raw/master/run.png?inline=false)
   

2. PythonClient基于Python3.8，且无需安装额外的第三方包，使用举例如下：
<figure>
from hdriver import HDriver

hdriver = HDriver(【鸿蒙设备ID】, 【APP Bundle】, 【APP Ability】)

获取屏幕尺寸：

hdriver.get_screen_size()

w, h = size_dict["width"], size_dict["height"]

滑动：

hdriver.swipe(w/2, h*0.8, w/2, h*0.2, 1)

根据坐标点击：

hdriver.tap(w/2, h/2)

回退：

hdriver.back()

返回桌面：

hdriver.home()

元素查找：

hdriver.find_element("text", "蓝牙", timeout_s=15)
</figure>

## License

harmony_ui_test is released under the [Apache License 2.0](http://www.apache.org/licenses/LICENSE-2.0).
