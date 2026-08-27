import { hilog } from '@kit.PerformanceAnalysisKit';
import { ImageService } from '../services/ImageService';

const TAG = 'ImageInput';

/**
 * 图像输入组件属性
 */
interface ImageInputProps {
  onImageSelected: (imagePath: string) => void;
  onAnalyzeComplete?: (result: string) => void;
}

/**
 * 图像输入组件
 * 支持拍照、选择图片、图像分析
 */
@Component
export struct ImageInput {
  @Prop onImageSelected: (imagePath: string) => void;
  @Prop onAnalyzeComplete?: (result: string) => void;

  @State selectedImage: string = '';
  @State isAnalyzing: boolean = false;
  @State analysisResult: string = '';
  @State showImagePicker: boolean = false;

  private imageService: ImageService = new ImageService();

  aboutToAppear(): void {
    this.imageService.initialize();
  }

  build() {
    Column() {
      // 图片预览区域
      if (this.selectedImage) {
        this.ImagePreview()
      } else {
        // 选择图片按钮
        this.ImageSelector()
      }

      // 分析结果
      if (this.analysisResult) {
        this.AnalysisResult()
      }
    }
    .width('100%')
  }

  @Builder
  ImageSelector() {
    Column() {
      Button() {
        Column() {
          Image($r('sys.media.ohos_ic_public_image'))
            .width(40)
            .height(40)
            .fillColor('#666666')
          
          Text('选择图片')
            .fontSize(14)
            .fontColor('#666666')
            .margin({ top: 8 })
        }
        .width(100)
        .height(80)
        .justifyContent(FlexAlign.Center)
      }
      .backgroundColor('#F5F5F5')
      .borderRadius(12)
      .border({ width: 1, color: '#E5E5E5', style: BorderStyle.Dashed })
      .onClick(() => {
        this.showImagePicker = true;
        this.selectImage();
      })
    }
    .width('100%')
    .padding(16)
  }

  @Builder
  ImagePreview() {
    Column() {
      Row() {
        // 图片预览
        Image(this.selectedImage)
          .width(100)
          .height(100)
          .objectFit(ImageFit.Cover)
          .borderRadius(8)

        Column() {
          // 分析按钮
          Button() {
            if (this.isAnalyzing) {
              Text('分析中...')
                .fontSize(14)
                .fontColor('#FFFFFF')
            } else {
              Text('智能分析')
                .fontSize(14)
                .fontColor('#FFFFFF')
            }
          }
          .backgroundColor('#007DFF')
          .borderRadius(20)
          .padding({ left: 16, right: 16, top: 8, bottom: 8 })
          .enabled(!this.isAnalyzing)
          .onClick(() => {
            this.analyzeImage();
          })
          .margin({ bottom: 8 })

          // 删除按钮
          Button() {
            Text('删除')
              .fontSize(14)
              .fontColor('#FF4D4F')
          }
          .backgroundColor('#FFF0F0')
          .borderRadius(20)
          .padding({ left: 16, right: 16, top: 8, bottom: 8 })
          .onClick(() => {
            this.selectedImage = '';
            this.analysisResult = '';
          })
        }
        .margin({ left: 12 })
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
    }
    .width('100%')
    .padding(12)
    .backgroundColor('#F5F5F5')
    .borderRadius(12)
  }

  @Builder
  AnalysisResult() {
    Column() {
      Text('分析结果')
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor('#333333')
        .margin({ bottom: 8 })

      Text(this.analysisResult)
        .fontSize(13)
        .fontColor('#666666')
        .lineHeight(20)
        .width('100%')
    }
    .width('100%')
    .padding(12)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .margin({ top: 8 })
  }

  /**
   * 选择图片
   */
  private async selectImage(): Promise<void> {
    // 实际实现需要使用 photoAccess 模块
    // 这里使用模拟路径
    this.selectedImage = 'temp_image_path';
    this.onImageSelected(this.selectedImage);
    
    hilog.info(0x0000, TAG, 'Image selected');
  }

  /**
   * 分析图片
   */
  private async analyzeImage(): Promise<void> {
    if (!this.selectedImage || this.isAnalyzing) {
      return;
    }

    this.isAnalyzing = true;

    try {
      const result = await this.imageService.analyzeImage(this.selectedImage);
      
      this.analysisResult = `📷 **图片分析**

类型：${result.description}
标签：${result.tags.join(', ')}

${result.text ? `📝 **识别文字**：\n${result.text}` : ''}

${result.objects ? `🔍 **检测到的物体**：\n${result.objects.join(', ')}` : ''}`;

      if (this.onAnalyzeComplete) {
        this.onAnalyzeComplete(this.analysisResult);
      }

      hilog.info(0x0000, TAG, 'Image analysis completed');
    } catch (error) {
      hilog.error(0x0000, TAG, 'Failed to analyze image: %{public}s', JSON.stringify(error) ?? '');
      this.analysisResult = '分析失败，请重试';
    } finally {
      this.isAnalyzing = false;
    }
  }
}
