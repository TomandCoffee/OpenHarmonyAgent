import { router } from '@kit.ArkUI';
import { Agent, AgentType } from '../models/Message';
import { AgentService } from '../services/AgentService';

@Entry
@Component
struct Agents {
  @State agents: Agent[] = [];
  @State selectedAgent: string = '';
  
  private agentService: AgentService = new AgentService();

  aboutToAppear(): void {
    this.agentService.initialize();
    this.agents = this.agentService.getAgentsStatus();
  }

  build() {
    Column() {
      // 顶部导航栏
      this.Header()

      // 智能体列表
      Scroll() {
        Column() {
          // 说明卡片
          this.IntroCard()

          // 智能体卡片列表
          ForEach(this.agents, (agent: Agent) => {
            this.AgentCard(agent)
          }, (agent: Agent) => agent.id)

          // 多智能体协作说明
          this.CollaborationCard()
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

      Text('智能体')
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
  IntroCard() {
    Column() {
      Text('🤖 智能体团队')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#333333')
        .margin({ bottom: 8 })

      Text('每个智能体都有专长，它们可以独立工作或协作完成复杂任务。')
        .fontSize(14)
        .fontColor('#666666')
        .lineHeight(20)
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .margin({ bottom: 16 })
  }

  @Builder
  AgentCard(agent: Agent) {
    Column() {
      Row() {
        // 图标
        Column() {
          Text(agent.icon)
            .fontSize(32)
        }
        .width(56)
        .height(56)
        .backgroundColor(agent.color + '20')
        .borderRadius(28)
        .justifyContent(FlexAlign.Center)
        .margin({ right: 12 })

        // 信息
        Column() {
          Row() {
            Text(agent.name)
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor('#333333')

            if (agent.isActive) {
              Text('工作中')
                .fontSize(12)
                .fontColor('#FFFFFF')
                .backgroundColor('#52C41A')
                .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                .borderRadius(10)
                .margin({ left: 8 })
            }
          }

          Text(agent.description)
            .fontSize(14)
            .fontColor('#666666')
            .margin({ top: 4 })
            .lineHeight(20)

          // 能力标签
          Flex() {
            ForEach(agent.capabilities, (capability: string) => {
              Text(capability)
                .fontSize(12)
                .fontColor(agent.color)
                .backgroundColor(agent.color + '15')
                .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                .borderRadius(12)
                .margin({ right: 6, top: 8 })
            }, (capability: string) => capability)
          }
          .width('100%')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        // 开关
        Toggle({ type: ToggleType.Switch, isOn: agent.isActive })
          .selectedColor(agent.color)
          .onChange((isOn: boolean) => {
            agent.isActive = isOn;
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
  CollaborationCard() {
    Column() {
      Text('🔄 多智能体协作')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#333333')
        .margin({ bottom: 8 })

      Text('当你发出复杂指令时，多个智能体会自动协作：')
        .fontSize(14)
        .fontColor('#666666')
        .margin({ bottom: 12 })

      // 协作示例
      Column() {
        Row() {
          Text('1')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
            .backgroundColor('#007DFF')
            .width(24)
            .height(24)
            .borderRadius(12)
            .textAlign(TextAlign.Center)
            .margin({ right: 8 })

          Text('任务识别：系统分析你的指令')
            .fontSize(14)
            .fontColor('#333333')
        }
        .width('100%')
        .margin({ bottom: 12 })

        Row() {
          Text('2')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
            .backgroundColor('#52C41A')
            .width(24)
            .height(24)
            .borderRadius(12)
            .textAlign(TextAlign.Center)
            .margin({ right: 8 })

          Text('任务分解：拆分为子任务')
            .fontSize(14)
            .fontColor('#333333')
        }
        .width('100%')
        .margin({ bottom: 12 })

        Row() {
          Text('3')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
            .backgroundColor('#722ED1')
            .width(24)
            .height(24)
            .borderRadius(12)
            .textAlign(TextAlign.Center)
            .margin({ right: 8 })

          Text('并行处理：各智能体同时工作')
            .fontSize(14)
            .fontColor('#333333')
        }
        .width('100%')
        .margin({ bottom: 12 })

        Row() {
          Text('4')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
            .backgroundColor('#FAAD14')
            .width(24)
            .height(24)
            .borderRadius(12)
            .textAlign(TextAlign.Center)
            .margin({ right: 8 })

          Text('结果整合：汇总并呈现最终结果')
            .fontSize(14)
            .fontColor('#333333')
        }
        .width('100%')
      }
      .width('100%')
      .padding(12)
      .backgroundColor('#FAFAFA')
      .borderRadius(8)
    }
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .shadow({ radius: 2, color: '#05000000', offsetY: 1 })
  }
}
