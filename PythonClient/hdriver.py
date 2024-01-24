# -*- coding: utf-8 -*-
import os
import uuid
import json
import time
import socket
import struct
import logging
import subprocess


logging.basicConfig(level=logging.INFO,
                format='%(asctime)s %(filename)s[line:%(lineno)d] %(levelname)s %(message)s',
                datefmt='%a, %d %b %Y %H:%M:%S')


class Element(object):
    def __init__(self, hdriver, euid: str, id: str=None, text: str=None, type: str=None, bounds: str=None, bounds_center: str=None):
        self._hdriver = hdriver
        self._euid = euid
        self._id = id
        self._text = text
        self._type = type
        self._bounds = json.loads(bounds) if isinstance(bounds, str) else bounds
        self._bounds_center = json.loads(bounds_center) if isinstance(bounds_center, str) else bounds_center

    def __repr__(self):
        return f'<Element(euid={self._euid}, id={self._id}, text={self._text}, type={self._type}, bounds={self._bounds}, bounds_center={self._bounds_center})>'

    @property
    def id(self):
        if self._id is None:
            self._id = self._hdriver.req({"action": "get", "property": ElementAttribute.ID, "euid": self._euid})["data"]
        return self._id

    @property
    def text(self):
        if self._text is None:
            self._text = self._hdriver.req({"action": "get", "property": ElementAttribute.TEXT, "euid": self._euid})["data"]
        return self._text

    @property
    def type(self):
        if self._type is None:
            self._type = self._hdriver.req({"action": "get", "property": ElementAttribute.TYPE, "euid": self._euid})["data"]
        return self._type

    @property
    def bounds(self):
        if self._bounds is None:
            self._bounds = json.loads(self._hdriver.req({"action": "get", "property": ElementAttribute.BOUNDS, "euid": self._euid})["data"])
        return self._bounds

    @property
    def bounds_center(self):
        if self._bounds_center is None:
            self._bounds_center = json.loads(self._hdriver.req({"action": "get", "property": ElementAttribute.BOUNDSCENTER, "euid": self._euid})["data"])
        return self._bounds_center

    def tap(self):
        return self._hdriver.req({"action": "operate", "operate": ElementOperate.TAP, "euid": self._euid})["data"]

    def input(self, text):
        return self._hdriver.req({"action": "operate", "operate": ElementOperate.INPUT, "text": text, "euid": self._euid})["data"]

    def clear(self):
        return self._hdriver.req({"action": "operate", "operate": ElementOperate.CLEAR, "euid": self._euid})["data"]


class ElementNotFoundError(Exception):
    pass


class ElementFoundTimeout(Exception):
    pass


class HDriverError(Exception):
    pass


class SocketError(Exception):
    pass


class ElementBy:
    ID = "id"
    TEXT = "text"
    TYPE = "type"


class ElementAttribute:
    ID = "id"
    TEXT = "text"
    TYPE = "type"
    BOUNDS = "bounds"
    BOUNDSCENTER = "boundsCenter"


class ElementType:
    Text = "Text"
    TextInput = "TextInput"
    Button = "Button"
    Image = "Image"
    Column = "Column"
    Divider = "Divider"
    TabBar = "TabBar"
    Row = "Row"
    Stack = "Stack"
    XComponent = "XComponent"
    Flex = "Flex"
    Canvas = "Canvas"
    RelativeContainer = "RelativeContainer"
    ListItem = "ListItem"
    GridItem = "GridItem"
    Grid = "Grid"
    TabContent = "TabContent"
    Swiper = "Swiper"
    Tabs = "Tabs"


class ElementOperate:
    TAP = "tap"
    CLEAR = "clear"
    INPUT = "input"


# 初始化的异常处理
def action(func):
    def _do(*args, **kwargs):
        start_time = time.time()
        logging.info(f"#### start {func.__name__} {args}")
        self = args[0]

        re_dict = None
        for rr in range(2):
            tmp_uuid = str(uuid.uuid1()).replace("-", "")
            try:
                data_dict = func(*args, **kwargs)
                data_dict["uuid"] = tmp_uuid
                logging.info(f"data_dict: {data_dict}")
                self.socket_send(data_dict)
                st = time.time()
                time_s = float(args[1].get("time_s", 0))
                timeout_s = float(args[1].get("timeout_s", 0))
                total_s = self.find_timeout_s+timeout_s+time_s
                while time.time() - st < total_s:
                    try:
                        re_bytes = self.s.recv(self.socket_buffer_size, socket.MSG_DONTWAIT)
                        logging.info(f"recv: {re_bytes}")
                    except Exception as e:
                        if e.strerror == 'Resource temporarily unavailable':
                            time.sleep(0.1)
                        else:
                            logging.exception(e)
                            raise SocketError()
                    else:
                        re_str = re_bytes.decode("utf8")
                        if len(re_str) > 0:
                            re_dict = json.loads(re_str)
                            if tmp_uuid == re_dict.get("uuid", ""):
                                break
                else:
                    err_desc = f"wait for {total_s} seconds"
                    raise ElementFoundTimeout(err_desc)

                logging.info(f"re_dict: {re_dict}")
                del re_dict["uuid"]
                if re_dict.get("ret") == "error":
                    error_desc = re_dict.get("description", "")
                    if error_desc.startswith("no ele"):
                        raise ElementNotFoundError(error_desc)
                    else:
                        raise HDriverError(error_desc)
            except SocketError as se:
                logging.exception(se)
                self.s = self.socket_client()
                continue
            except ElementFoundTimeout as ee:
                # logging.exception(ee)
                raise ee
            except ElementNotFoundError as fe:
                raise fe
            except HDriverError as he:
                raise he
            except Exception as e:
                logging.exception(e)
            else:
                pass
            finally:
                pass
            break
        used_time = time.time() - start_time
        logging.info(f"#### end {func.__name__},after {used_time}s")
        return re_dict

    return _do


class HDriver:
    test_app_file = "entry-ohosTest-signed.hap"
    test_app_bundle = "com.harmony.uitest"
    socket_buffer_size = 1024

    def __init__(self, device_id:str, app_bundle:str, app_ability:str, find_timeout_s:int = 10):
        self.device_id = device_id
        self.app_bundle = app_bundle
        self.app_ability = app_ability
        self.find_timeout_s = find_timeout_s
        self.server_port = 29100
        self.start_test_app(force_stop=True)
        self.s = self.socket_client()

    def socket_client(self, timeout=15):
        logging.info("start socket client init")
        self.start_test_app(force_stop=False)
        st = time.time()
        while time.time() - st < timeout:
            try:
                cmd = f"hdc -t {self.device_id} fport rm tcp:{self.server_port} tcp:{self.server_port}; hdc -t {self.device_id} fport tcp:{self.server_port} tcp:{self.server_port}; hdc -t {self.device_id} fport ls"
                out = os.popen(cmd).read()
                logging.info(out)
                s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                # s.setsockopt(socket.SOL_SOCKET, socket.SO_KEEPALIVE, 1)
                l_onoff = 1
                l_linger = 0
                s.setsockopt(socket.SOL_SOCKET, socket.SO_LINGER, struct.pack('ii', l_onoff, l_linger))
                logging.info("after set sock opt")
                s.connect(("127.0.0.1", self.server_port))
                logging.info("after connect")
                s.send(b"hello")
                logging.info("after send")
                hello_msg = s.recv(self.socket_buffer_size)
                logging.info(f"socket client init ok. got hell message: {hello_msg}")
                return s
            except Exception as e:
                logging.exception(e)
                time.sleep(0.5)
        raise Exception(f"socket client init timeout after {timeout} seconds!")

    def socket_send(self, msg_dict: dict):
        for retry in range(3):
            try:
                self.s.send(json.dumps(msg_dict).encode("utf8"))
                break
            except Exception as e:
                logging.exception(e)
                self.s = self.socket_client()

    def hdc_ps(self, key_word):
        cmd = f"hdc -t {self.device_id} shell ps -Af | grep {key_word} | grep -v grep"
        out_list = os.popen(cmd).readlines()
        return [line.split()[1] for line in out_list]

    def hdc_kill(self, pid_list):
        for pid in pid_list:
            os.popen(f"hdc -t {self.device_id} shell kill {pid}").read()

    @staticmethod
    def exec_cmd_backend(cmd, wait=True):
        p = subprocess.Popen(cmd.split(" "), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        if wait:
            p.wait()

    def start_test_app(self, force_stop=False, only_stop=False):
        logging.info(f"test app starting. force_stop: {force_stop} only_stop: {only_stop}")
        key_word = f"ActsAbilityTest#uiTestProcess{self.server_port}"
        pid_list = self.hdc_ps(key_word)
        if pid_list and not force_stop:
            return

        self.hdc_kill(self.hdc_ps(self.test_app_bundle))
        if only_stop:
            return

        for tmp_port in [29100, 29200, 29300, 29400, 29500]:  # 等aa test 支持传参后，优化这块
            # clear connection
            cmd_cliear = f"hdc -t {self.device_id} fport rm tcp:{tmp_port} tcp:{tmp_port}; hdc -t {self.device_id} fport ls"
            out = os.popen(cmd_cliear).read()
            logging.info(out)
            cmd_wait = f"hdc -t {self.device_id} shell netstat -anpl | grep -v unix | grep {tmp_port}"
            out = os.popen(cmd_wait).read().strip()
            if len(out) == 0:
                self.server_port = tmp_port
                break
        else:
            raise Exception("29100, 29200, 29300, 29400, 29500 all busy!")
        # 启动
        cmd = f"hdc -t {self.device_id} shell aa test -b {self.test_app_bundle} -m entry_test -s unittest /ets/testrunner/OpenHarmonyTestRunner -s class ActsAbilityTest#uiTestProcess{self.server_port} -s timeout 86400000"
        self.exec_cmd_backend(cmd, wait=False)  # 使用subprocess启动，在结束调试时，会自动杀死，如果时system启动，结束调试时，不会自动kill，就会卡住

    @action
    def req(self, msg_data):
        return msg_data

    def find_element(self, by: str, data: str, timeout_s: int = 0, attributes: list = None, operates: list = None, extend: str = ""):
        resp = self.req({"action": "find", "by": by, "data": data, "timeout_s": str(timeout_s),
                            "attributes": ",".join(attributes) if attributes else str(attributes),
                            "operates": ",".join(operates) if operates else str(operates), "extend": extend})
        return Element(self, resp["euid"],
                       id=resp.get(ElementAttribute.ID),
                       type=resp.get(ElementAttribute.TYPE),
                       text=resp.get(ElementAttribute.TEXT),
                       bounds=resp.get(ElementAttribute.BOUNDS),
                       bounds_center=resp.get(ElementAttribute.BOUNDSCENTER))

    def find_elements(self, by: str, data: str, attributes: list = None, operates: list = None, extend: str = ""):
        resp = self.req({"action": "finds", "by": by, "data": data,
                            "attributes": ",".join(attributes) if attributes else str(attributes),
                            "operates": ",".join(operates) if operates else str(operates), "extend": extend})
        ele_list = json.loads(resp["data"])
        return [Element(self, ele["euid"],
                        id=ele.get(ElementAttribute.ID),
                        type=ele.get(ElementAttribute.TYPE),
                        text=ele.get(ElementAttribute.TEXT),
                        bounds=ele.get(ElementAttribute.BOUNDS),
                        bounds_center=ele.get(ElementAttribute.BOUNDSCENTER)) for ele in ele_list]

    def tap(self, x, y):
        return self.req({"action": "tap", "x": str(x), "y": str(y)})["data"]

    def swipe(self, startx, starty, endx, endy, time_s):
        # 滑动速率，范围：200-15000，不在范围内设为默认值为600，单位：像素点/秒
        speed = int(max(abs(startx - endx), abs(starty - endy)) / time_s)
        speed = 200 if speed < 200 else (15000 if speed > 15000 else speed)
        return self.req(
            {"action": "swipe", "startx": str(int(startx)), "starty": str(int(starty)), "endx": str(int(endx)), "endy": str(int(endy)),
             "speed": str(speed), "time_s": str(time_s)})["data"]

    def home(self):
        return self.req({"action": "home"})["data"]

    def back(self):
        return self.req({"action": "back"})["data"]

    def get_screen_size(self):
        resp = json.loads(self.req({"action": "screenSize"})["data"])
        return {"width": resp["x"], "height": resp["y"]}

    def get_current_bundle(self):
        return self.req({"action": "currentBundle"})["data"]

    def _get_screenshot_file(self):
        remote_path = "/data/local/tmp/aa.png"
        cap_cmd = f'hdc -t {self.device_id} shell "rm -rf {remote_path};sync;uitest screenCap -p {remote_path};sync"'
        cap_ret = os.popen(cap_cmd).read().strip()
        if not cap_ret.startswith("ScreenCap saved to"):
            raise Exception(f"screen shot failed! {cap_ret}")
        local_path = "aa.png"
        cmd = f"hdc -t {self.device_id} file recv {remote_path} {local_path}"
        # logging.info(f"recv: {cmd}")
        self.exec_cmd_backend(cmd)
        st = time.time()
        while time.time() - st < 5 and not os.path.exists(local_path):
            time.sleep(0.1)
        os.sync()
        # 远程删除
        cmd = f"hdc -t {self.device_id} shell rm -rf {remote_path}"
        self.exec_cmd_backend(cmd)

        return local_path

    def get_screenshot_png(self):
        local_path = self._get_screenshot_file()
        with open(local_path, "rb") as ff:
            png_bytes = ff.read()
        # 本地删除
        os.remove(local_path)

        return png_bytes

    def start_app(self, bundle, ability):
        ret = self.req({"action": "app", "cmd": "start", "bundle": bundle, "ability": ability})["data"]
        return ret

    def stop_app(self, bundle):
        ret = self.req({"action": "app", "cmd": "stop", "bundle": bundle})["data"]
        time.sleep(1)  # 连续stop+start，有一定概率的start失败，stop之后等一秒试试
        return ret

