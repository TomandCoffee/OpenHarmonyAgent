import { router } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { RAGService } from '../services/RAGService';
import { KnowledgeItem } from '../models/Message';

const TAG = 'KnowledgeBase';

@Entry
@Component
struct KnowledgeBase {
  @State knowledgeItems: KnowledgeItem[] = [];
  @State searchQuery: string = '';
  @State isSearching: boolean = false;
  @State showAddDialog: boolean = false;
  
  private ragService: RAGService = new RAGService();

  aboutToAppear(): void {
    this.ragService.initialize();
    this.loadKnowledgeItems();
  }

  build() {
    Column() {
      // 顶部导航栏
      this.Header()

      // 搜索框
      this.SearchBar()

      // 知识库列表
      this.KnowledgeList()

      // 添加按钮
      this.AddButton()
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

      Text('知识库')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor('#333333')
        .margin({ left: 12 })

      Blank()

      // 统计信息
      Text(`${this.knowledgeItems.length} 条知识`)
        .fontSize(14)
        .fontColor('#666666')
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .backgroundColor('#FFFFFF')
    .shadow({ radius: 2, color: '#10000000', offsetY: 1 })
  }

  @Builder
  SearchBar() {
    Row() {
      Image($r('sys.media.ohos_ic_public_search'))
        .width(20)
        .height(20)
        .fillColor('#999999')
        .margin({ right: 8 })

      TextInput({ placeholder: '搜索知识库...', text: this.searchQuery })
        .layoutWeight(1)
        .height(40)
        .backgroundColor('#F5F5F5')
        .borderRadius(20)
        .padding({ left: 12, right: 12 })
        .onChange((value: string) => {
          this.searchQuery = value;
          this.performSearch();
        })

      if (this.searchQuery) {
        Button() {
          Image($r('sys.media.ohos_ic_public_cancel'))
            .width(16)
            .height(16)
            .fillColor('#999999')
        }
        .type(ButtonType.Circle)
        .backgroundColor('transparent')
        .onClick(() => {
          this.searchQuery = '';
          this.loadKnowledgeItems();
        })
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
  }

  @Builder
  KnowledgeList() {
    Scroll() {
      Column() {
        if (this.knowledgeItems.length === 0) {
          this.EmptyState()
        } else {
          ForEach(this.knowledgeItems, (item: KnowledgeItem) => {
            this.KnowledgeCard(item)
          }, (item: KnowledgeItem) => item.id)
        }
      }
      .width('100%')
      .padding(16)
    }
    .layoutWeight(1)
    .scrollBar(BarState.Off)
  }

  @Builder
  EmptyState() {
    Column() {
      Text('📚')
        .fontSize(64)
        .margin({ bottom: 16 })

      Text('知识库为空')
        .fontSize(18)
        .fontColor('#333333')
        .fontWeight(FontWeight.Medium)
        .margin({ bottom: 8 })

      Text('添加课程笔记、文献资料、会议纪要等内容\n构建你的个人知识库')
        .fontSize(14)
        .fontColor('#999999')
        .textAlign(TextAlign.Center)
        .margin({ bottom: 24 })

      Button('添加第一条知识')
        .fontSize(16)
        .fontColor('#FFFFFF')
        .backgroundColor('#007DFF')
        .borderRadius(25)
        .padding({ left: 24, right: 24, top: 12, bottom: 12 })
        .onClick(() => {
          this.showAddDialog = true;
        })
    }
    .width('100%')
    .padding({ top: 60, bottom: 60 })
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  KnowledgeCard(item: KnowledgeItem) {
    Column() {
      Row() {
        // 类型图标
        Column() {
          Text(this.getTypeIcon(item.type))
            .fontSize(24)
        }
        .width(40)
        .height(40)
        .backgroundColor(this.getTypeColor(item.type))
        .borderRadius(20)
        .justifyContent(FlexAlign.Center)
        .margin({ right: 12 })

        // 内容
        Column() {
          Text(item.content.substring(0, 50) + (item.content.length > 50 ? '...' : ''))
            .fontSize(15)
            .fontColor('#333333')
            .lineHeight(22)
            .width('100%')

          Row() {
            Text(this.formatType(item.type))
              .fontSize(12)
              .fontColor('#666666')

            Text('•')
              .fontSize(12)
              .fontColor('#CCCCCC')
              .margin({ left: 8, right: 8 })

            Text(this.formatTime(item.timestamp))
              .fontSize(12)
              .fontColor('#999999')
          }
          .margin({ top: 8 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        // 删除按钮
        Button() {
          Image($r('sys.media.ohos_ic_public_delete'))
            .width(18)
            .height(18)
            .fillColor('#FF4D4F')
        }
        .type(ButtonType.Circle)
        .backgroundColor('transparent')
        .onClick(() => {
          this.deleteKnowledge(item.id);
        })
      }
      .width('100%')
    }
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .margin({ bottom: 12 })
    .shadow({ radius: 2, color: '#05000000', offsetY: 1 })
  }

  @Builder
  AddButton() {
    Button() {
      Image($r('sys.media.ohos_ic_public_add'))
        .width(24)
        .height(24)
        .fillColor('#FFFFFF')
    }
    .type(ButtonType.Circle)
    .backgroundColor('#007DFF')
    .width(56)
    .height(56)
    .position({ x: '80%', y: '85%' })
    .shadow({ radius: 8, color: '#30007DFF', offsetY: 4 })
    .onClick(() => {
      this.showAddDialog = true;
    })
  }

  private async loadKnowledgeItems(): Promise<void> {
    // 从 RAG 服务加载知识
    // 实际实现需要查询所有知识
    this.knowledgeItems = [
      {
        id: '1',
        content: '机器学习是人工智能的一个分支，它使计算机能够从数据中学习而不需要显式编程。',
        type: '学习笔记',
        tags: ['AI', '机器学习'],
        timestamp: Date.now() - 86400000
      },
      {
        id: '2',
        content: '会议纪要：项目进度评审会，确定了下阶段的开发计划和里程碑。',
        type: '会议纪要',
        tags: ['工作', '会议'],
        timestamp: Date.now() - 172800000
      }
    ];
  }

  private async performSearch(): Promise<void> {
    if (!this.searchQuery) {
      this.loadKnowledgeItems();
      return;
    }

    this.isSearching = true;
    
    try {
      // 使用 RAG 进行语义搜索
      const results = await this.ragService.retrieve(this.searchQuery, 10);
      this.knowledgeItems = results;
    } catch (error) {
      hilog.error(0x0000, TAG, 'Search failed: %{public}s', JSON.stringify(error) ?? '');
    } finally {
      this.isSearching = false;
    }
  }

  private async deleteKnowledge(id: string): Promise<void> {
    await this.ragService.removeKnowledge(id);
    await this.loadKnowledgeItems();
  }

  private getTypeIcon(type: string): string {
    switch (type) {
      case '学习笔记': return '📚';
      case '会议纪要': return '📝';
      case '文献资料': return '📄';
      case 'conversation': return '💬';
      default: return '📋';
    }
  }

  private getTypeColor(type: string): string {
    switch (type) {
      case '学习笔记': return '#E6F4FF';
      case '会议纪要': return '#E6F7E6';
      case '文献资料': return '#F3E5F5';
      default: return '#F5F5F5';
    }
  }

  private formatType(type: string): string {
    return type;
  }

  private formatTime(timestamp: number): string {
    const date = new Date(timestamp);
    const month = (date.getMonth() + 1).toString().padStart(2, '0');
    const day = date.getDate().toString().padStart(2, '0');
    return `${month}-${day}`;
  }
}
