import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "wdleo.easytier"
  ipcTarget: "wdleo.easytier"
  manageIpc: false

  property var status: ({ service: "unknown", running: false, installed: true, peers: [] })
  property string errorText: ""
  readonly property bool busy: actionProc.running
  readonly property bool running: status.running === true
  readonly property var peers: status.peers || []
  readonly property int directCount: peers.filter(function(p) { return p.kind === "direct" }).length
  readonly property int relayCount: peers.length - directCount
  readonly property bool connected: running && status.rpc === true && peers.length > 0
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property string ctl: decodeURIComponent(String(Qt.resolvedUrl("scripts/easytierctl")).replace(/^file:\/\//, ""))
  readonly property int pollMs: Math.max(3, Math.min(60, Number(root.setting("pollSeconds", 5)) || 5)) * 1000
  readonly property string stateText: busy ? "正在切换…"
    : status.installed === false ? "服务未安装"
    : status.service === "failed" ? "服务异常"
    : status.service === "deactivating" ? "正在停止…"
    : !running ? "已关闭"
    : status.rpc !== true ? "正在连接管理接口…"
    : status.peers_ready === false ? "节点状态暂不可用"
    : peers.length === 0 ? "等待组网节点"
    : "已连接 · " + peers.length + " 个节点"

  function refresh() {
    if (!statusProc.running && !busy) statusProc.running = true
  }

  function run(verb) {
    if (busy || status.installed === false) return
    errorText = ""
    actionProc.command = [ctl, verb]
    actionProc.running = true
  }

  function toggleService() { run(running ? "stop" : "start") }
  function copyIp(ip) {
    if (!ip) return
    copyProc.command = ["wl-copy", "--", String(ip)]
    if (!copyProc.running) copyProc.running = true
  }
  function openLogs() {
    close()
    Quickshell.execDetached(["xdg-terminal-exec", "journalctl", "-u", "easytier.service", "-f", "--no-pager"])
  }
  function tooltip() {
    return "EasyTier · " + stateText + (status.ip ? "\n组网 IP：" + status.ip : "")
      + (connected ? "\n直连 " + directCount + " · 中继 " + relayCount : "")
      + "\n左键详情 · 右键开关 · 中键复制 IP"
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight
  Component.onCompleted: refresh()
  onOpenedChanged: if (opened) {
    refresh()
    Qt.callLater(function() { keys.forceActiveFocus() })
  }

  Timer { interval: root.opened ? 3000 : root.pollMs; repeat: true; running: true; onTriggered: root.refresh() }
  Timer { id: refreshSoon; interval: 250; onTriggered: root.refresh() }

  Process {
    id: statusProc
    command: [root.ctl, "status"]
    stdout: StdioCollector { id: statusOutput; waitForEnd: true }
    onExited: function(code) {
      try {
        if (code !== 0) throw new Error("status failed")
        root.status = JSON.parse(statusOutput.text)
      } catch (error) {
        root.status = { service: "unknown", running: false, installed: true, peers: [] }
        root.errorText = "暂时无法读取 EasyTier 状态，请刷新重试。"
      }
    }
  }

  Process {
    id: actionProc
    stdout: StdioCollector { id: actionOutput; waitForEnd: true }
    onExited: function(code) {
      try {
        var result = JSON.parse(actionOutput.text)
        if (!result.ok) root.errorText = result.error || "操作失败，请重试。"
      } catch (error) { root.errorText = "操作失败，请检查服务权限。" }
      refreshSoon.restart()
    }
  }

  Process { id: copyProc }

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): void { root.refresh() }
    function toggleService(): void { root.toggleService() }
    function current(): string { return JSON.stringify(root.status) }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰒍"
    dimmed: !root.running
    active: root.running && !root.connected
    tooltipText: root.tooltip()
    onPressed: function(b) {
      if (b === Qt.RightButton) root.toggleService()
      else if (b === Qt.MiddleButton) root.copyIp(root.status.ip)
      else root.toggle()
    }
  }

  component InfoPair: Row {
    id: info
    property string label: ""
    property string value: ""
    width: parent.width
    spacing: Style.space(8)
    Text {
      id: labelText
      text: info.label
      textFormat: Text.PlainText
      color: root.foreground
      opacity: 0.6
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
    }
    Item { width: Math.max(0, info.width - labelText.implicitWidth - valueText.implicitWidth - info.spacing * 2); height: 1 }
    Text {
      id: valueText
      text: info.value
      textFormat: Text.PlainText
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
    }
  }

  KeyboardPanel {
    id: popup
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keys
    contentWidth: popup.fittedContentWidth(Style.space(340))
    contentHeight: popup.fittedContentHeight(content.implicitHeight)

    PanelKeyCatcher {
      id: keys
      anchors.fill: parent
      blocked: root.busy
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        if (t === "r" || t === "R") root.refresh()
        else if (t === "t" || t === "T") root.toggleService()
        else if (t === "c" || t === "C") root.copyIp(root.status.ip)
      }

      Column {
        id: content
        width: parent.width
        spacing: Style.space(12)

        PanelHero {
          id: hero
          width: parent.width
          title: "EasyTier"
          meta: root.stateText
          detail: root.status.ip || "安全连接你的设备"
          foreground: root.foreground
          fontFamily: root.fontFamily
          iconOpacity: root.running ? 1 : 0.45
          iconComponent: Component {
            Text { text: "󰒍"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.display }
          }
          trailingControl: Component {
            ToggleSwitch {
              id: serviceSwitch
              checked: root.running
              busy: root.busy
              interactive: root.status.installed !== false
              foreground: root.foreground
              onToggled: root.toggleService()
              PanelToolTip {
                visible: serviceSwitch.containsMouse
                text: root.running ? "停止 EasyTier" : "启动 EasyTier"
                fontFamily: root.fontFamily
              }
            }
          }
        }

        Text {
          visible: root.errorText !== ""
          width: parent.width
          text: root.errorText
          textFormat: Text.PlainText
          color: root.urgent
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.Wrap
        }

        Column {
          width: parent.width
          spacing: Style.space(6)
          InfoPair { label: "组网 IP"; value: root.status.ip || "—" }
          InfoPair { label: "连接方式"; value: "直连 " + root.directCount + " · 中继 " + root.relayCount }
          InfoPair { label: "共享子网"; value: (root.status.shared || []).join(", ") || "—" }
          InfoPair { label: "开机自动启动"; value: root.status.autostart === true ? "已开启" : "未开启" }
        }

        PanelSeparator { foreground: root.foreground }
        PanelSectionHeader { text: "组网节点"; foreground: root.foreground; fontFamily: root.fontFamily }

        Text {
          visible: root.peers.length === 0
          width: parent.width
          text: root.running ? "等待其他节点连接…" : "启动 EasyTier 后显示节点。"
          color: root.foreground
          opacity: 0.6
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
        }

        Flickable {
          id: peerScroll
          visible: root.peers.length > 0
          width: parent.width
          height: Math.min(peerList.implicitHeight, Style.space(220))
          contentHeight: peerList.implicitHeight
          clip: true
          boundsBehavior: Flickable.StopAtBounds

          Column {
            id: peerList
            width: parent.width
            spacing: Style.space(4)
            Repeater {
              model: root.peers
              delegate: Rectangle {
                id: peerRow
                required property var modelData
                width: peerList.width
                height: Style.space(46)
                radius: Style.cornerRadius
                color: peerMouse.containsMouse ? Style.hoverFillFor(root.foreground, Color.accent) : "transparent"
                Column {
                  anchors.left: parent.left
                  anchors.leftMargin: Style.space(6)
                  anchors.verticalCenter: parent.verticalCenter
                  width: parent.width - latencyText.width - Style.space(22)
                  spacing: Style.space(2)
                  Text {
                    width: parent.width
                    text: peerRow.modelData.name
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.bodySmall
                  }
                  Text {
                    width: parent.width
                    text: (peerRow.modelData.ip || "无虚拟 IP") + " · " + (peerRow.modelData.kind === "direct" ? "直连" : "中继")
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    color: root.foreground
                    opacity: 0.6
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.bodySmall
                  }
                }
                Text {
                  id: latencyText
                  anchors.right: parent.right
                  anchors.rightMargin: Style.space(6)
                  anchors.verticalCenter: parent.verticalCenter
                  text: peerRow.modelData.latency === null ? "—" : Number(peerRow.modelData.latency).toFixed(1) + " ms"
                  color: root.foreground
                  opacity: 0.7
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                }
                MouseArea {
                  id: peerMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.copyIp(peerRow.modelData.ip)
                }
                PanelToolTip { visible: peerMouse.containsMouse; text: "点击复制节点 IP"; fontFamily: root.fontFamily }
              }
            }
          }
        }

        PanelSeparator { foreground: root.foreground }
        Row {
          spacing: Style.space(6)
          Button { text: "刷新"; iconText: "󰑓"; fontSize: Style.font.bodySmall; foreground: root.foreground; fontFamily: root.fontFamily; enabled: !root.busy; onClicked: root.refresh() }
          Button { text: "重连"; iconText: "󰜉"; fontSize: Style.font.bodySmall; foreground: root.foreground; fontFamily: root.fontFamily; enabled: root.running && !root.busy; onClicked: root.run("restart") }
          Button { text: "复制 IP"; fontSize: Style.font.bodySmall; foreground: root.foreground; fontFamily: root.fontFamily; enabled: !!root.status.ip; onClicked: root.copyIp(root.status.ip) }
          Button { text: "日志"; fontSize: Style.font.bodySmall; foreground: root.foreground; fontFamily: root.fontFamily; onClicked: root.openLogs() }
        }
        Text {
          width: parent.width
          text: "开关控制当前运行；开机自启设置保持不变。"
          color: root.foreground
          opacity: 0.5
          wrapMode: Text.Wrap
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
        }
      }
    }
  }
}
