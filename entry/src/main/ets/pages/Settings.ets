import { router } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'Settings';

@Entry
@Component
struct Settings {
  @State voiceEnabled: boolean = true;
  @State imageAnalysisEnabled: boolean = true;
  @State crossDeviceEnabled: boolean = true;
  @State autoSaveKnowledge: boolean = true;
  @State darkMode: boolean = false;
  @State notificationEnabled: boolean = true;

  build() {
    Column() {
      // 顶部导航栏
      this.Header()

      // 设置列表
      Scroll() {
        Column() {
          // 功能设置
          this.SettingSection('功能设置', [
            {
              title: '语音输入',
              subtitle: '启用语音识别功能',
              type: 'toggle',
              key: 'voiceEnabled'
            },
            {
              title: '图像分析',
              subtitle: '启用图片智能分析',
              type: 'toggle',
              key: 'imageAnalysisEnabled'
            },
            {
              title: '跨设备协同',
              subtitle: '允许任务在多设备间流转',
              type: 'toggle',
              key: 'crossDeviceEnabled'
            },
            {
              title: '自动保存知识',
              subtitle: '对话内容自动添加到知识库',
              type: 'toggle',
              key: 'autoSaveKnowledge'
            }
          ])

          // 外观设置
          this.SettingSection('外观设置', [
            {
              title: '深色模式',
              subtitle: '使用深色主题',
              type: 'toggle',
              key: 'darkMode'
            }
          ])

          // 通知设置
          this.SettingSection('通知设置', [
            {
              title: '日程提醒',
              subtitle: '接收日程和会议提醒',
              type: 'toggle',
              key: 'notificationEnabled'
            }
          ])

          // 关于
          this.SettingSection('关于', [
            {
              title: '应用版本',
              subtitle: 'v1.0.0 MVP',
              type: 'info'
            },
            {
              title: '开源协议',
              subtitle: 'MIT License',
              type: 'info'
            },
            {
              title: '用户协议',
              type: 'link'
            },
            {
              title: '隐私政策',
              type: 'link'
            }
          ])

          // 清除数据
          this.ClearDataSection()
        }
        .width('100%')
        .padding(16)
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }

  @Builder
  Header() {
    Row() {
      Button() {
        Image($r('sys.media.ohos_ic_public_back'))
          .width(24)
          .height(24)
          .fillColor('#333333')
      }
      .type(ButtonType.Circle)
      .backgroundColor('transparent')
      .onClick(() => {
        router.back();
      })

      Text('设置')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor('#333333')
        .margin({ left: 12 })

      Blank()
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .backgroundColor('#FFFFFF')
    .shadow({ radius: 2, color: '#10000000', offsetY: 1 })
  }

  @Builder
  SettingSection(title: string, items: any[]) {
    Column() {
      Text(title)
        .fontSize(14)
        .fontColor('#999999')
        .margin({ bottom: 8, left: 16 })

      ForEach(items, (item: any) => {
        this.SettingItem(item)
      }, (item: any) => item.title)
    }
    .width('100%')
    .margin({ bottom: 24 })
  }

  @Builder
  SettingItem(item: any) {
    Row() {
      Column() {
        Text(item.title)
          .fontSize(16)
          .fontColor('#333333')
          .margin({ bottom: 4 })

        if (item.subtitle) {
          Text(item.subtitle)
            .fontSize(13)
            .fontColor('#999999')
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      if (item.type === 'toggle') {
        Toggle({
          type: ToggleType.Switch,
          isOn: this[item.key]
        })
          .selectedColor('#007DFF')
          .onChange((isOn: boolean) => {
            this[item.key] = isOn;
            hilog.info(0x0000, TAG, '%{public}s changed to %{public}s', item.title, isOn.toString());
          })
      } else if (item.type === 'info') {
        Text(item.subtitle || '')
          .fontSize(14)
          .fontColor('#999999')
      } else if (item.type === 'link') {
        Image($r('sys.media.ohos_ic_public_arrow_right'))
          .width(16)
          .height(16)
          .fillColor('#CCCCCC')
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .margin({ bottom: 1 })
  }

  @Builder
  ClearDataSection() {
    Column() {
      Button() {
        Text('清除所有数据')
          .fontSize(16)
          .fontColor('#FF4D4F')
      }
      .backgroundColor('#FFF0F0')
      .borderRadius(12)
      .padding({ left: 24, right: 24, top: 12, bottom: 12 })
      .width('100%')
      .onClick(() => {
        // 清除数据逻辑
        hilog.info(0x0000, TAG, 'Clear all data');
      })
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
  }
}
