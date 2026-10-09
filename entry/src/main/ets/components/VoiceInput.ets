import { hilog } from '@kit.PerformanceAnalysisKit';
import { common } from '@kit.AbilityKit';
import { VoiceService } from '../services/VoiceService';

const TAG = 'VoiceInput';

/**
 * 语音输入组件属性
 */
interface VoiceInputProps {
  onResult: (text: string) => void;
  onStatusChange?: (isRecording: boolean) => void;
}

/**
 * 语音输入组件
 * 支持长按说话、实时识别
 */
@Component
export struct VoiceInput {
  // 回调函数不能用 @Prop 装饰（ArkTS 限制），直接作为普通成员传入
  onResult: (text: string) => void = () => {};
  onStatusChange?: (isRecording: boolean) => void;
  /** 录音过程中的实时文字，交给父组件显示 */
  onPartialText?: (text: string) => void;
  
  @State isRecording: boolean = false;
  @State recognizedText: string = '';
  @State recordingTime: number = 0;
  
  private voiceService: VoiceService = VoiceService.getInstance();
  private recordingTimer: number = -1;

  aboutToAppear(): void {
    // 提前把引擎建起来，首次按住说话时就不用等初始化
    // （initialize 内部做了并发保护，这里和 startRecording 里重复调用是安全的）
    this.voiceService.initialize();
  }

  aboutToDisappear(): void {
    if (this.isRecording) {
      this.stopRecording();
    }
    if (this.recordingTimer !== -1) {
      clearInterval(this.recordingTimer);
      this.recordingTimer = -1;
    }
    // 注意：这里不释放引擎 —— VoiceService 是全局单例，引擎跟着应用生命周期走。
    // 每次切页面都 shutdown 重建反而更慢，也更容易和 ASR 系统服务抢实例。
  }

  build() {
    Button() {
      if (this.isRecording) {
        // 录音中状态
        Column() {
          // 声波动画
          this.WaveAnimation()
          
          Text(`${this.recordingTime}s`)
            .fontSize(12)
            .fontColor('#FFFFFF')
            .margin({ top: 4 })
        }
      } else {
        // 正常状态
        Image($r('sys.media.ohos_ic_public_voice'))
          .width(24)
          .height(24)
          .fillColor('#FFFFFF')
      }
    }
    .type(ButtonType.Circle)
    .backgroundColor(this.isRecording ? '#FF4D4F' : '#007DFF')
    .width(40)
    .height(40)
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.startRecording();
      } else if (event.type === TouchType.Up) {
        this.stopRecording();
      }
    })
  }

  @Builder
  WaveAnimation() {
    Row({ space: 2 }) {
      ForEach([0, 1, 2, 3, 4], (index: number) => {
        Column()
          .width(3)
          .height(16 + index * 2)
          .backgroundColor('#FFFFFF')
          .borderRadius(2)
          .animation({
            duration: 500,
            iterations: -1,
            curve: Curve.EaseInOut
          })
      })
    }
  }

  /**
   * 开始录音
   */
  private async startRecording(): Promise<void> {
    if (this.isRecording) {
      return;
    }

    // 麦克风是敏感权限，必须在运行时弹窗申请 —— 光在 module.json5 里声明拿不到
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const granted: boolean = await this.voiceService.ensureMicrophonePermission(context);
    if (!granted) {
      hilog.warn(0x0000, TAG, 'microphone permission not granted');
      return;
    }

    try {
      const success = await this.voiceService.startRecording((text: string, isFinal: boolean) => {
        this.recognizedText = text;
        // 中间结果实时交给父组件展示，说话时就能看到字往外冒
        if (this.onPartialText) {
          this.onPartialText(text);
        }
      });

      if (success) {
        this.isRecording = true;
        this.recordingTime = 0;
        this.recognizedText = '';

        // 启动计时器
        this.recordingTimer = setInterval(() => {
          this.recordingTime++;
        }, 1000);

        if (this.onStatusChange) {
          this.onStatusChange(true);
        }

        hilog.info(0x0000, TAG, 'Recording started');
      }
    } catch (error) {
      const err = error as Error;
      hilog.error(0x0000, TAG, 'Failed to start recording: %{public}s', err.message);
    }
  }

  /**
   * 停止录音
   */
  private async stopRecording(): Promise<void> {
    if (!this.isRecording) {
      return;
    }

    try {
      // 停止计时器
      if (this.recordingTimer !== -1) {
        clearInterval(this.recordingTimer);
        this.recordingTimer = -1;
      }

      // 获取识别结果
      const result = await this.voiceService.stopRecording();

      this.isRecording = false;

      if (this.onStatusChange) {
        this.onStatusChange(false);
      }
      // 识别结束，清掉实时文字（没识别出内容时界面上不该留着上一次的）
      if (this.onPartialText) {
        this.onPartialText('');
      }

      // 回调识别结果
      if (result && this.onResult) {
        this.onResult(result);
      }

      hilog.info(0x0000, TAG, 'Recording stopped');
    } catch (error) {
      hilog.error(0x0000, TAG, 'Failed to stop recording: %{public}s', JSON.stringify(error) ?? '');
      this.isRecording = false;
    }
  }
}
