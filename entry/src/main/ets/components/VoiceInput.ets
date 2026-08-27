import { hilog } from '@kit.PerformanceAnalysisKit';
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
  @Prop onResult: (text: string) => void;
  @Prop onStatusChange?: (isRecording: boolean) => void;
  
  @State isRecording: boolean = false;
  @State recognizedText: string = '';
  @State recordingTime: number = 0;
  
  private voiceService: VoiceService = new VoiceService();
  private recordingTimer: number = -1;

  aboutToAppear(): void {
    this.voiceService.initialize();
  }

  aboutToDisappear(): void {
    if (this.isRecording) {
      this.stopRecording();
    }
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
        Image($r('sys.media.ohos_ic_public_microphone'))
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
    Row() {
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
    .gap(2)
  }

  /**
   * 开始录音
   */
  private async startRecording(): Promise<void> {
    if (this.isRecording) {
      return;
    }

    try {
      const success = await this.voiceService.startRecording((result) => {
        this.recognizedText = result.text;
      });

      if (success) {
        this.isRecording = true;
        this.recordingTime = 0;
        this.recognizedText = '';
        
        // 启动计时器
        this.recordingTimer = setInterval(() => {
          this.recordingTime++;
        }, 1000) as any;

        if (this.onStatusChange) {
          this.onStatusChange(true);
        }

        hilog.info(0x0000, TAG, 'Recording started');
      }
    } catch (error) {
      hilog.error(0x0000, TAG, 'Failed to start recording: %{public}s', JSON.stringify(error) ?? '');
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
      
      // 回调识别结果
      if (result && this.onResult) {
        this.onResult(result);
      }

      if (this.onStatusChange) {
        this.onStatusChange(false);
      }

      hilog.info(0x0000, TAG, 'Recording stopped');
    } catch (error) {
      hilog.error(0x0000, TAG, 'Failed to stop recording: %{public}s', JSON.stringify(error) ?? '');
      this.isRecording = false;
    }
  }
}
