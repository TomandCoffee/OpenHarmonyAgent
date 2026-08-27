import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { distributedDataObject } from '@kit.CoreFileKit';

const TAG = 'EntryAbility';

export default class EntryAbility extends UIAbility {
  private distributedObject: distributedDataObject.DistributedObject | null = null;

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(0x0000, TAG, '%{public}s', 'Ability onCreate');
    
    // 初始化分布式数据对象
    this.initDistributedObject();
  }

  onDestroy(): void {
    hilog.info(0x0000, TAG, '%{public}s', 'Ability onDestroy');
    
    // 释放分布式对象
    if (this.distributedObject) {
      this.distributedObject.stop();
    }
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(0x0000, TAG, '%{public}s', 'Ability onWindowStageCreate');

    windowStage.loadContent('pages/Index', (err, data) => {
      if (err.code) {
        hilog.error(0x0000, TAG, 'Failed to load content. Cause: %{public}s', JSON.stringify(err) ?? '');
        return;
      }
      hilog.info(0x0000, TAG, 'Succeeded in loading content. Data: %{public}s', JSON.stringify(data) ?? '');
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(0x0000, TAG, '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(0x0000, TAG, '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    hilog.info(0x0000, TAG, '%{public}s', 'Ability onBackground');
  }

  /**
   * 初始化分布式数据对象，用于跨设备协同
   */
  private initDistributedObject(): void {
    try {
      // 创建分布式数据对象
      const object = distributedDataObject.create({
        name: 'OpenHarmonyAgent_SharedContext',
        context: this.context
      });
      
      this.distributedObject = object;
      
      // 设置初始数据
      object.sessionId = Date.now().toString();
      object.deviceId = this.context.deviceInfo.id;
      object.deviceType = this.context.deviceInfo.deviceType;
      object.currentTask = '';
      object.contextData = '{}';
      
      // 监听分布式对象变化
      object.on('change', (sessionId: string) => {
        hilog.info(0x0000, TAG, 'Distributed object changed, sessionId: %{public}s', sessionId);
        // 处理跨设备数据同步
        this.handleDistributedChange(object);
      });
      
      // 加入分布式会话
      object.join('OpenHarmonyAgent_Session');
      
      hilog.info(0x0000, TAG, 'Distributed object initialized successfully');
    } catch (error) {
      hilog.error(0x0000, TAG, 'Failed to init distributed object: %{public}s', JSON.stringify(error) ?? '');
    }
  }

  /**
   * 处理分布式数据变化
   */
  private handleDistributedChange(object: distributedDataObject.DistributedObject): void {
    // 可以在这里处理跨设备任务流转逻辑
    const currentTask = object.currentTask;
    const contextData = object.contextData;
    
    hilog.info(0x0000, TAG, 'Task transferred: %{public}s', currentTask);
  }

  /**
   * 获取分布式对象实例
   */
  getDistributedObject(): distributedDataObject.DistributedObject | null {
    return this.distributedObject;
  }
}
