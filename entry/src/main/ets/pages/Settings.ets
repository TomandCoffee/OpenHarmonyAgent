import { router } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { LLMService } from '../services/LLMService';
import { ApiKeyStore } from '../services/ApiKeyStore';

const TAG = 'Settings';

/**
 * 设置项配置
 */
interface SettingItemConfig {
  title: string;
  subtitle?: string;
  type: string;
  key?: string;
}

@Entry
@Component
struct Settings {
  @State voiceEnabled: boolean = true;
  @State imageAnalysisEnabled: boolean = true;
  @State crossDeviceEnabled: boolean = true;
  @State autoSaveKnowledge: boolean = true;
  @State darkMode: boolean = false;
  @State notificationEnabled: boolean = true;

  // 模型设置
  @State apiKeyInput: string = '';
  @State savedKeyMask: string = '';
  @State keyTestResult: string = '';
  @State keyTestOk: boolean = false;
  @State isTestingKey: boolean = false;

  aboutToAppear(): void {
    const store: ApiKeyStore = ApiKeyStore.getInstance();
    this.savedKeyMask = store.hasKey() ? store.maskKey() : '';
  }

  build() {
    Column() {
      // 顶部导航栏
      this.Header()

      // 设置列表
      Scroll() {
        Column() {
          // 模型设置（放最前，这是整个应用能否工作的前提）
          this.ModelSettingsSection()

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
        Image($r('sys.media.ohos_ic_public_arrow_left'))
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
  SettingSection(title: string, items: SettingItemConfig[]) {
    Column() {
      Text(title)
        .fontSize(14)
        .fontColor('#999999')
        .margin({ bottom: 8, left: 16 })

      ForEach(items, (item: SettingItemConfig) => {
        this.SettingItem(item)
      }, (item: SettingItemConfig) => item.title)
    }
    .width('100%')
    .margin({ bottom: 24 })
  }

  @Builder
  SettingItem(item: SettingItemConfig) {
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
          isOn: this.getToggleValue(item.key ?? '')
        })
          .selectedColor('#007DFF')
          .onChange((isOn: boolean) => {
            this.setToggleValue(item.key ?? '', isOn);
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

  /**
   * 模型设置：DeepSeek API Key
   */
  @Builder
  ModelSettingsSection() {
    Column() {
      Text('AI 模型')
        .fontSize(14)
        .fontColor('#999999')
        .margin({ bottom: 8, left: 16 })

      Column() {
        Row() {
          Text('DeepSeek API Key')
            .fontSize(16)
            .fontColor('#333333')

          Blank()

          Text(this.savedKeyMask.length > 0 ? `已保存 ${this.savedKeyMask}` : '未配置')
            .fontSize(13)
            .fontColor(this.savedKeyMask.length > 0 ? '#52C41A' : '#FF4D4F')
        }
        .width('100%')

        TextInput({ placeholder: 'sk-...', text: this.apiKeyInput })
          .type(InputType.Password)
          .height(44)
          .width('100%')
          .margin({ top: 8 })
          .onChange((value: string) => {
            this.apiKeyInput = value;
            this.keyTestResult = '';
          })

        Row() {
          Button('保存')
            .fontSize(14)
            .onClick(() => {
              this.saveApiKey();
            })
            .margin({ right: 8 })

          Button(this.isTestingKey ? '测试中…' : '测试连接')
            .fontSize(14)
            .enabled(!this.isTestingKey)
            .onClick(() => {
              this.testApiKey();
            })
            .margin({ right: 8 })

          Button('清除')
            .fontSize(14)
            .backgroundColor('#FFF0F0')
            .fontColor('#FF4D4F')
            .onClick(() => {
              this.clearApiKey();
            })
        }
        .margin({ top: 12 })

        if (this.keyTestResult.length > 0) {
          Text(this.keyTestResult)
            .fontSize(13)
            .fontColor(this.keyTestOk ? '#52C41A' : '#FF4D4F')
            .width('100%')
            .margin({ top: 8 })
        }
      }
      .padding(16)
      .backgroundColor('#FFFFFF')
      .borderRadius(12)
    }
    .width('100%')
    .margin({ bottom: 24 })
  }

  private async saveApiKey(): Promise<void> {
    const key: string = this.apiKeyInput.trim();
    if (key.length === 0) {
      this.keyTestOk = false;
      this.keyTestResult = '请先输入 API Key。';
      return;
    }

    const store: ApiKeyStore = ApiKeyStore.getInstance();
    await store.setApiKey(key);
    this.savedKeyMask = store.maskKey();
    this.apiKeyInput = '';
    this.keyTestOk = true;
    this.keyTestResult = '已保存，现在可以回首页对话了。';
  }

  private async testApiKey(): Promise<void> {
    const typed: string = this.apiKeyInput.trim();
    const key: string = typed.length > 0 ? typed : ApiKeyStore.getInstance().getApiKey();
    if (key.length === 0) {
      this.keyTestOk = false;
      this.keyTestResult = '请先输入 API Key。';
      return;
    }

    this.isTestingKey = true;
    this.keyTestOk = false;
    this.keyTestResult = '测试中…';

    const message: string = await LLMService.getInstance().ping(key);
    if (message.length === 0) {
      this.keyTestOk = true;
      this.keyTestResult = '连接成功，Key 可用。';
    } else {
      this.keyTestOk = false;
      this.keyTestResult = message;
    }
    this.isTestingKey = false;
  }

  private async clearApiKey(): Promise<void> {
    await ApiKeyStore.getInstance().clearApiKey();
    this.savedKeyMask = '';
    this.apiKeyInput = '';
    this.keyTestOk = true;
    this.keyTestResult = '已清除。';
  }

  /**
   * 按配置项的 key 读取开关状态
   * （ArkTS 不支持 this[动态属性名] 这种索引访问，只能显式枚举）
   */
  private getToggleValue(key: string): boolean {
    switch (key) {
      case 'voiceEnabled': return this.voiceEnabled;
      case 'imageAnalysisEnabled': return this.imageAnalysisEnabled;
      case 'crossDeviceEnabled': return this.crossDeviceEnabled;
      case 'autoSaveKnowledge': return this.autoSaveKnowledge;
      case 'darkMode': return this.darkMode;
      case 'notificationEnabled': return this.notificationEnabled;
      default: return false;
    }
  }

  /**
   * 按配置项的 key 写入开关状态
   */
  private setToggleValue(key: string, value: boolean): void {
    switch (key) {
      case 'voiceEnabled': this.voiceEnabled = value; break;
      case 'imageAnalysisEnabled': this.imageAnalysisEnabled = value; break;
      case 'crossDeviceEnabled': this.crossDeviceEnabled = value; break;
      case 'autoSaveKnowledge': this.autoSaveKnowledge = value; break;
      case 'darkMode': this.darkMode = value; break;
      case 'notificationEnabled': this.notificationEnabled = value; break;
      default: break;
    }
  }
}
