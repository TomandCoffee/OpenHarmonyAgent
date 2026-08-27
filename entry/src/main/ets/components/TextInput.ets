import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'TextInput';

/**
 * 文本输入组件属性
 */
interface TextInputProps {
  placeholder?: string;
  text: string;
  onChange: (value: string) => void;
  onSubmit?: () => void;
  maxLength?: number;
}

/**
 * 文本输入组件
 * 支持多行输入、快捷短语
 */
@Component
export struct TextInput {
  @Prop placeholder: string = '输入消息...';
  @Prop text: string;
  @Prop onChange: (value: string) => void;
  @Prop onSubmit?: () => void;
  @Prop maxLength: number = 1000;

  @State isFocused: boolean = false;
  @State showQuickPhrases: boolean = false;

  // 快捷短语
  private quickPhrases: string[] = [
    '帮我总结',
    '提取重点',
    '安排会议',
    '设置提醒',
    '这是什么意思',
    '添加到笔记'
  ];

  build() {
    Column() {
      // 输入框
      TextArea({
        placeholder: this.placeholder,
        text: this.text
      })
        .width('100%')
        .height(50)
        .backgroundColor('#F5F5F5')
        .borderRadius(25)
        .padding({ left: 16, right: 16, top: 10, bottom: 10 })
        .fontSize(16)
        .fontColor('#333333')
        .maxLength(this.maxLength)
        .onChange((value: string) => {
          this.text = value;
          this.onChange(value);
        })
        .onFocus(() => {
          this.isFocused = true;
        })
        .onBlur(() => {
          this.isFocused = false;
        })

      // 快捷短语
      if (this.showQuickPhrases) {
        this.QuickPhrasesPanel()
      }
    }
    .width('100%')
  }

  @Builder
  QuickPhrasesPanel() {
    Scroll() {
      Row() {
        ForEach(this.quickPhrases, (phrase: string) => {
          Button(phrase)
            .fontSize(13)
            .fontColor('#007DFF')
            .backgroundColor('#E6F4FF')
            .borderRadius(15)
            .padding({ left: 12, right: 12, top: 6, bottom: 6 })
            .margin({ right: 8 })
            .onClick(() => {
              this.text = phrase;
              this.onChange(phrase);
              this.showQuickPhrases = false;
            })
        }, (phrase: string) => phrase)
      }
      .width('100%')
    }
    .scrollBar(BarState.Off)
    .width('100%')
    .height(40)
    .margin({ top: 8 })
  }

  /**
   * 切换快捷短语面板
   */
  toggleQuickPhrases(): void {
    this.showQuickPhrases = !this.showQuickPhrases;
  }
}
