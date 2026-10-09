import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { distributedDataObject } from '@kit.ArkData';
import { deviceInfo } from '@kit.BasicServicesKit';
import { ApiKeyStore } from '../services/ApiKeyStore';
import { SettingsStore } from '../services/SettingsStore';

const TAG = 'EntryAbility';

/**
 * 跨设备流转的共享上下文。
 * 分布式数据对象的字段必须由显式声明的类承载，ArkTS 不允许无类型对象字面量。
 */
class SharedContext {
  sessionId: string = '';
  deviceId: string = '';
  deviceType: string = '';
  currentTask: string = '';
  contextData: string = '{}';
  lastUpdateTime: number = 0;
}

export default class EntryAbility extends UIAbility {
  private distributedObject: distributedDataObject.DataObject | null = null;
  private sharedContext: SharedContext = new SharedContext();

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(0x0000, TAG, '%{public}s', 'Ability onCreate');

    // 注入 Context 给本地存储（服务层拿不到组件上下文）
    ApiKeyStore.getInstance().init(this.context).catch((err: Error) => {
      hilog.error(0x0000, TAG, 'ApiKeyStore init failed: %{public}s', err.message);
    });
    SettingsStore.getInstance().init(this.context).catch((err: Error) => {
      hilog.error(0x0000, TAG, 'SettingsStore init failed: %{public}s', err.message);
    });

    // 初始化分布式数据对象
    this.initDistributedObject();
  }

  onDestroy(): void {
    hilog.info(0x0000, TAG, '%{public}s', 'Ability onDestroy');

    // 释放分布式对象
    if (this.distributedObject) {
      this.distributedObject.off('change');
      this.distributedObject = null;
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
      this.sharedContext.sessionId = distributedDataObject.genSessionId();
      // 不用 udid / serial —— 它们需要 ohos.permission.sec.ACCESS_UDID（系统权限，应用申请不到）
      this.sharedContext.deviceId = `${deviceInfo.productModel}-${deviceInfo.deviceType}`;
      this.sharedContext.deviceType = deviceInfo.deviceType;
      this.sharedContext.lastUpdateTime = Date.now();

      const object = distributedDataObject.create(this.context, this.sharedContext);
      this.distributedObject = object;

      // 监听分布式对象变化
      object.on('change', (sessionId: string, fields: Array<string>) => {
        hilog.info(0x0000, TAG, 'Distributed object changed, sessionId: %{public}s', sessionId);
        this.handleDistributedChange(fields);
      });

      // 加入分布式会话
      object.setSessionId(this.sharedContext.sessionId);

      hilog.info(0x0000, TAG, 'Distributed object initialized successfully');
    } catch (error) {
      const err = error as Error;
      hilog.error(0x0000, TAG, 'Failed to init distributed object: %{public}s', err.message);
    }
  }

  /**
   * 处理分布式数据变化
   */
  private handleDistributedChange(fields: Array<string>): void {
    // 可以在这里处理跨设备任务流转逻辑
    hilog.info(0x0000, TAG, 'Task transferred: %{public}s', this.sharedContext.currentTask);
  }

  /**
   * 获取分布式对象实例
   */
  getDistributedObject(): distributedDataObject.DataObject | null {
    return this.distributedObject;
  }
}
