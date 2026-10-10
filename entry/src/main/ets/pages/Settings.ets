import { router } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { LLMService } from '../services/LLMService';
import { ApiKeyStore } from '../services/ApiKeyStore';
import { VoiceService, VoiceProbeResult } from '../services/VoiceService';
import { TTSService, TtsProbeResult } from '../services/TTSService';
import { SettingsStore, LANGUAGE_OPTIONS, LanguageOption } from '../services/SettingsStore';
import { Capability } from '../utils/Capability';
import { textToSpeech } from '@kit.CoreSpeechKit';
import { promptAction } from '@kit.ArkUI';

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

/** 音色选项（从设备查询而来） */
interface VoiceOption {
  person: number;
  label: string;
}

/**
 * 语言码归一化比对：引擎返回的是 zh_CN，设置里存的是 zh-CN
 */
function sameLanguage(a: string, b: string): boolean {
  return a.replace(/_/g, '-').toLowerCase() === b.replace(/_/g, '-').toLowerCase();
}

/**
 * 音色的显示名：优先用性别，拿不到就退回编号
 */
function voiceLabel(gender: string, person: number): string {
  const g: string = gender.length > 0 ? gender.toLowerCase() : '';
  if (g === 'female') {
    return '女声';
  }
  if (g === 'male') {
    return '男声';
  }
  return `音色${person}`;
}

/**
 * 语言选择行（语音识别 / 语音播报 / 回复语言共用）。
 *
 * 这里必须是独立的 @Component，**不能写成 @Builder**。
 *
 * @Builder 的参数是按值传递的，值变化时不保证重建那条 builder 链。实测：
 * 点「回复语言 → English」后存盘确实生效了（杀掉应用重进，页面正确显示 English），
 * 但当前页面上那排 chip 一动不动 —— 用户看到的就是「点了没反应」。
 * 同一个页面上「语音识别」那行当时恰好刷了，所以这个问题很隐蔽，只表现为偶发。
 *
 * @Prop 是单向同步：父组件的值一变，子组件必然重建。
 */
@Component
struct LanguageChipRow {
  @Prop label: string = '';
  @Prop current: string = '';
  @Prop which: string = '';
  // 回调不能加 @Prop（ArkTS 不允许函数类型），普通成员传入即可
  onPick: (which: string, code: string) => void = () => {};

  build() {
    Column() {
      Text(this.label)
        .fontSize(15)
        .fontColor('#333333')
        .width('100%')

      Row() {
        ForEach(LANGUAGE_OPTIONS, (option: LanguageOption) => {
          Text(option.label)
            .fontSize(13)
            .fontColor(this.current === option.code ? '#FFFFFF' : '#007DFF')
            .backgroundColor(this.current === option.code ? '#007DFF' : '#E6F4FF')
            .borderRadius(14)
            .padding({ left: 14, right: 14, top: 6, bottom: 6 })
            .margin({ right: 8 })
            .onClick(() => {
              this.onPick(this.which, option.code);
            })
        }, (option: LanguageOption) => `${this.which}_${option.code}`)
      }
      .width('100%')
      .margin({ top: 8 })
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
  }
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

  // 语音自检
  @State voiceProbeResult: string = '';
  @State voiceProbeOk: boolean = false;
  @State isProbingVoice: boolean = false;

  // 语言设置
  @State recognizeLang: string = 'zh-CN';
  @State speakLang: string = 'zh-CN';
  @State speakPerson: number = 0;
  @State replyLang: string = 'zh-CN';
  /** 当前播报语言下可用的音色 */
  @State voiceOptions: VoiceOption[] = [];
  @State ttsProbeResult: string = '';
  @State isProbingTts: boolean = false;
  @State capabilitySummary: string = '';

  aboutToAppear(): void {
    const store: ApiKeyStore = ApiKeyStore.getInstance();
    this.savedKeyMask = store.hasKey() ? store.maskKey() : '';

    const settings: SettingsStore = SettingsStore.getInstance();
    this.recognizeLang = settings.getRecognizeLanguage();
    this.speakLang = settings.getSpeakLanguage();
    this.speakPerson = settings.getSpeakPerson();
    this.replyLang = settings.getReplyLanguage();
    this.capabilitySummary = Capability.summary();

    // 把设置同步给 TTS 引擎（它内部会在语言变化时重建引擎）
    TTSService.getInstance().setVoice(this.speakLang, this.speakPerson);

    // 查当前语言下有哪些音色可选
    this.loadVoices();

    // 识别语言也要自愈，理由见方法注释
    this.healRecognizeLanguage();
  }

  /**
   * 自愈：存盘的识别语言可能是本机做不到的 —— 历史坏数据，或者用户卸载了语言包。
   *
   * 不修的话麦克风「按下去有动画、却一个字都识别不出来」，界面上完全看不出原因。
   * 和播报语言的自愈是同一个道理，只是那边查的是音色列表、这边要真建一次引擎。
   */
  private async healRecognizeLanguage(): Promise<void> {
    const voice: VoiceService = VoiceService.getInstance();

    if (await voice.canRecognize(this.recognizeLang)) {
      return;
    }

    for (const option of LANGUAGE_OPTIONS) {
      if (option.code === this.recognizeLang) {
        continue;
      }
      if (await voice.canRecognize(option.code)) {
        hilog.warn(0x0000, TAG, 'recognize language %{public}s unusable, fall back to %{public}s',
          this.recognizeLang, option.code);
        this.recognizeLang = option.code;
        await SettingsStore.getInstance().setRecognizeLanguage(option.code);
        voice.invalidateEngine();
        return;
      }
    }
  }

  /**
   * 查询当前播报语言下的可用音色。
   * 如果当前选中的音色在这个语言下不存在（比如从中文切到英文），自动落到第一个。
   */
  private async loadVoices(): Promise<void> {
    const tts: TTSService = TTSService.getInstance();
    let all: textToSpeech.VoiceInfo[] = await tts.listVoicesFor(this.speakLang);

    // 自愈：存盘的语言可能是本机播不了的 —— 历史遗留的坏设置，或者用户把语音
    // 资源卸了。不修的话朗读永远没声音、音色列表永远是空的，界面上还看不出原因。
    if (all.length === 0) {
      for (const option of LANGUAGE_OPTIONS) {
        if (sameLanguage(option.code, this.speakLang)) {
          continue;
        }
        const other: textToSpeech.VoiceInfo[] = await tts.listVoicesFor(option.code);
        if (other.length > 0) {
          hilog.warn(0x0000, TAG, 'speak language %{public}s unusable, fall back to %{public}s',
            this.speakLang, option.code);
          this.speakLang = option.code;
          this.speakPerson = 0;
          await SettingsStore.getInstance().setSpeakVoice(option.code, 0);
          tts.setVoice(option.code, 0);
          all = other;
          break;
        }
      }
    }

    // listVoicesFor 已经按语言筛过了，这里只需要转成界面用的结构
    const opts: VoiceOption[] = [];
    for (const v of all) {
      opts.push({ person: v.person, label: voiceLabel(v.gender, v.person) });
    }
    this.voiceOptions = opts;

    let currentStillValid: boolean = false;
    for (const o of opts) {
      if (o.person === this.speakPerson) {
        currentStillValid = true;
        break;
      }
    }
    if (!currentStillValid && opts.length > 0) {
      await this.pickVoice(opts[0].person);
    }
    hilog.info(0x0000, TAG, 'voices for %{public}s: %{public}d 个', this.speakLang, opts.length);
  }

  private async pickVoice(person: number): Promise<void> {
    this.speakPerson = person;
    const store: SettingsStore = SettingsStore.getInstance();
    await store.setSpeakVoice(this.speakLang, person);

    const tts: TTSService = TTSService.getInstance();
    tts.setVoice(this.speakLang, person);

    // 音色在列表里不代表资源装了 —— 实际建一次引擎才知道能不能用。
    // 建不起来时 TTSService 会回退到默认音色，这里据此提示用户。
    const ok: boolean = await tts.initialize(this.speakLang, person);
    if (!ok || tts.getEffectivePerson() !== person) {
      promptAction.showToast({ message: '这个音色在本机不可用，已用默认音色' });
    }
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

          // 语音能力自检
          this.VoiceCheckSection()

          // 语言设置
          this.LanguageSection()

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
   * 语言设置：识别语言 / 播报语言 / 回复语言
   *
   * 三者分开而不是合成一个「界面语言」开关 —— 实际使用中组合很常见，
   * 比如「用英文听、用中文答」，或者一边练听力一边要中文解释。
   */
  @Builder
  LanguageSection() {
    Column() {
      Text('语言与音色')
        .fontSize(14)
        .fontColor('#999999')
        .margin({ bottom: 8, left: 16 })

      Column() {
        // 语音识别语言
        LanguageChipRow({
          label: '语音识别',
          current: this.recognizeLang,
          which: 'recognize',
          onPick: (which: string, code: string): void => {
            this.pickLanguage(which, code);
          }
        })

        Divider().color('#F0F0F0').margin({ top: 4, bottom: 4 })

        // 播报语言 + 音色
        LanguageChipRow({
          label: '语音播报',
          current: this.speakLang,
          which: 'speak',
          onPick: (which: string, code: string): void => {
            this.pickLanguage(which, code);
          }
        })

        Divider().color('#F0F0F0').margin({ top: 4, bottom: 4 })

        this.VoiceRow()

        Divider().color('#F0F0F0').margin({ top: 4, bottom: 4 })

        // 回复语言
        LanguageChipRow({
          label: '回复语言',
          current: this.replyLang,
          which: 'reply',
          onPick: (which: string, code: string): void => {
            this.pickLanguage(which, code);
          }
        })

        // 播报自检
        Row() {
          Text('播报自检')
            .fontSize(15)
            .fontColor('#333333')
          Blank()
          Button(this.isProbingTts ? '检测中…' : '检测')
            .fontSize(13)
            .height(32)
            .enabled(!this.isProbingTts)
            .onClick(() => {
              this.runTtsProbe();
            })
        }
        .width('100%')
        .margin({ top: 12 })

        if (this.ttsProbeResult.length > 0) {
          Text(this.ttsProbeResult)
            .fontSize(12)
            .fontColor('#666666')
            .width('100%')
            .margin({ top: 6 })
        }

        // 设备能力汇总
        if (this.capabilitySummary.length > 0) {
          Text(this.capabilitySummary)
            .fontSize(11)
            .fontColor('#999999')
            .width('100%')
            .margin({ top: 12 })
        }
      }
      .padding(16)
      .backgroundColor('#FFFFFF')
      .borderRadius(12)
    }
    .width('100%')
    .margin({ bottom: 24 })
  }

  /**
   * 播报音色选择。
   *
   * 音色列表不是写死的 —— 数量和性别都由设备决定（实测这台平板是
   * 中文女声/中文男声/英文女声三个），所以从 TTSService.listVoicesFor() 现查。
   * 列表按当前播报语言过滤，切语言时会自动重查。
   */
  @Builder
  VoiceRow() {
    Column() {
      Row() {
        Text('播报音色')
          .fontSize(15)
          .fontColor('#333333')

        Blank()

        if (this.voiceOptions.length === 0) {
          // 走到这里说明所有语言都试过了、一个能用的音色都没有 ——
          // 不是「还没查」，是设备确实没有装好的语音资源
          Text('本机无可用音色')
            .fontSize(13)
            .fontColor('#FF4D4F')
        }
      }
      .width('100%')

      if (this.voiceOptions.length > 0) {
        Row() {
          ForEach(this.voiceOptions, (option: VoiceOption) => {
            Text(option.label)
              .fontSize(13)
              .fontColor(this.speakPerson === option.person ? '#FFFFFF' : '#007DFF')
              .backgroundColor(this.speakPerson === option.person ? '#007DFF' : '#E6F4FF')
              .borderRadius(14)
              .padding({ left: 14, right: 14, top: 6, bottom: 6 })
              .margin({ right: 8 })
              .onClick(() => {
                this.pickVoice(option.person);
              })
          }, (option: VoiceOption) => `${option.person}`)
        }
        .width('100%')
        .margin({ top: 8 })
      }
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
  }

  private async pickLanguage(which: string, code: string): Promise<void> {
    hilog.info(0x0000, TAG, 'pickLanguage(%{public}s, %{public}s) entered', which, code);
    const store: SettingsStore = SettingsStore.getInstance();

    if (which === 'recognize') {
      const voice: VoiceService = VoiceService.getInstance();

      // 和播报语言同一个道理：设备的语音资源是按语言装的，存之前必须先试。
      // 选了本机做不到的语言，麦克风会变成「按下去有动画、却一个字都识别不出来」，
      // 界面上完全看不出原因 —— 用户只会觉得语音按钮坏了。
      if (!await voice.canRecognize(code)) {
        promptAction.showToast({ message: '本机没有这个语言的识别资源，保持原设置' });
        hilog.warn(0x0000, TAG, 'recognize language %{public}s unusable', code);
        return;
      }

      this.recognizeLang = code;
      store.setRecognizeLanguage(code);
      // 识别语言变了要让 ASR 引擎重建，否则还在用旧语言识别
      voice.invalidateEngine();
      return;
    }

    if (which === 'speak') {
      const tts: TTSService = TTSService.getInstance();

      // 先验证本机能不能用这个语言播报，**能播才存**。
      //
      // 设备的语音资源是按音色单独下载的：实测这台平板的英文音色 status 是 GA
      // （资源没装），拿它建引擎直接失败。一旦存进去，朗读会彻底没声音、音色列表
      // 也是空的，而界面上完全看不出原因 —— 用户只会觉得「按钮坏了」。
      const voices: textToSpeech.VoiceInfo[] = await tts.listVoicesFor(code);
      if (voices.length === 0) {
        // 探测本身会把服务的语言改成 code（initialize 先 release 再赋值），
        // 失败时得还原，否则内存状态和存盘状态对不上
        tts.setVoice(this.speakLang, this.speakPerson);
        promptAction.showToast({ message: '本机没有这个语言的语音资源，保持原设置' });
        hilog.warn(0x0000, TAG, 'speak language %{public}s has no usable voice', code);
        return;
      }

      this.speakLang = code;
      store.setSpeakVoice(code, this.speakPerson);
      tts.setVoice(code, this.speakPerson);
      // 音色是按语言分的，切换语言后要重新查；当前音色在新语言下不存在会自动落到第一个
      this.loadVoices();
      return;
    }

    if (which === 'reply') {
      this.replyLang = code;
      store.setReplyLanguage(code);
    }
  }

  private async runTtsProbe(): Promise<void> {
    this.isProbingTts = true;
    this.ttsProbeResult = '';
    try {
      const probe: TtsProbeResult = await TTSService.getInstance().probe();
      if (probe.available) {
        this.ttsProbeResult = probe.voices.length > 0
          ? `可用。${probe.detail}：\n${probe.voices.slice(0, 6).join('\n')}`
          : `可用。${probe.detail}`;
      } else {
        this.ttsProbeResult = `不可用：${probe.detail}`;
      }
    } catch (error) {
      const err = error as Error;
      this.ttsProbeResult = `检测失败：${err.message}`;
    }
    this.isProbingTts = false;
  }

  /**
   * 语音能力自检
   *
   * 离线语音识别依赖设备上预装的中文语言包，这个没法从代码推断，
   * 只能实际建一次引擎才知道。所以这里做成一个可点的自检。
   */
  @Builder
  VoiceCheckSection() {
    Column() {
      Text('语音识别')
        .fontSize(14)
        .fontColor('#999999')
        .margin({ bottom: 8, left: 16 })

      Column() {
        Row() {
          Text('系统语音引擎')
            .fontSize(16)
            .fontColor('#333333')

          Blank()

          Text(this.voiceProbeResult.length > 0
            ? (this.voiceProbeOk ? '可用' : '不可用')
            : '未检测')
            .fontSize(13)
            .fontColor(this.voiceProbeResult.length === 0 ? '#999999'
              : (this.voiceProbeOk ? '#52C41A' : '#FF4D4F'))
        }
        .width('100%')

        Text('使用系统自带的 Core Speech Kit，不需要第三方服务')
          .fontSize(13)
          .fontColor('#999999')
          .width('100%')
          .margin({ top: 4 })

        Button(this.isProbingVoice ? '检测中…' : '检测语音引擎')
          .fontSize(14)
          .enabled(!this.isProbingVoice)
          .margin({ top: 12 })
          .onClick(() => {
            this.runVoiceProbe();
          })

        if (this.voiceProbeResult.length > 0) {
          Text(this.voiceProbeResult)
            .fontSize(13)
            .fontColor(this.voiceProbeOk ? '#52C41A' : '#FF4D4F')
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

  private async runVoiceProbe(): Promise<void> {
    this.isProbingVoice = true;
    this.voiceProbeResult = '';
    try {
      const probe = VoiceService.getInstance();
      const result: VoiceProbeResult = await probe.probe();

      if (result.offlineOk) {
        this.voiceProbeOk = true;
        this.voiceProbeResult = '离线识别可用（推荐，不依赖网络）';
      } else if (result.onlineOk) {
        this.voiceProbeOk = true;
        this.voiceProbeResult = '仅在线识别可用（需要联网）';
      } else {
        this.voiceProbeOk = false;
        this.voiceProbeResult = `两种模式都不可用：\n${result.detail}`;
      }
    } catch (error) {
      const err = error as Error;
      this.voiceProbeOk = false;
      this.voiceProbeResult = `检测失败：${err.message}`;
    }
    this.isProbingVoice = false;
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
