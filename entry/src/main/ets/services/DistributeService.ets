import { hilog } from '@kit.PerformanceAnalysisKit';
import { distributedDataObject } from '@kit.ArkData';
import { distributedDeviceManager } from '@kit.DistributedServiceKit';
import { common } from '@kit.AbilityKit';

const TAG = 'DistributeService';

/**
 * 需要跨设备同步的任务上下文。
 * 分布式数据对象的字段必须由显式声明的类承载。
 */
class TaskContext {
  sessionId: string = '';
  currentTask: string = '';
  contextData: string = '{}';
  targetDeviceId: string = '';
  lastUpdateTime: number = 0;
}

/**
 * 要流转的任务
 */
export interface TaskData {
  type: string;
  content: string;
  context?: string;
}

/**
 * 分布式服务
 * 实现跨设备协同和任务流转
 *
 * 说明：使用 ArkData 的 distributedDataObject 做数据同步，
 * 用 DistributedServiceKit 的 distributedDeviceManager 查询可信设备。
 */
export class DistributeService {
  private distributedObject: distributedDataObject.DataObject | null = null;
  private taskContext: TaskContext = new TaskContext();
  private deviceManager: distributedDeviceManager.DeviceManager | null = null;
  private connectedDevices: distributedDeviceManager.DeviceBasicInfo[] = [];
  private isInitialized: boolean = false;

  /**
   * 初始化分布式服务
   * @param context 应用上下文，分布式数据对象需要它来建立会话
   */
  async initialize(context: common.Context): Promise<void> {
    if (this.isInitialized) {
      return;
    }

    try {
      await this.initDeviceManager(context);
      await this.initDistributedObject(context);

      this.isInitialized = true;
      hilog.info(0x0000, TAG, 'DistributeService initialized');
    } catch (error) {
      const err = error as Error;
      hilog.error(0x0000, TAG, 'Failed to initialize DistributeService: %{public}s', err.message);
    }
  }

  /**
   * 初始化设备管理器
   */
  private async initDeviceManager(context: common.Context): Promise<void> {
    try {
      this.deviceManager = distributedDeviceManager.createDeviceManager(context.applicationInfo.name);
      this.connectedDevices = this.deviceManager.getAvailableDeviceListSync();

      hilog.info(0x0000, TAG, 'Available devices: %{public}d', this.connectedDevices.length);
    } catch (error) {
      const err = error as Error;
      hilog.error(0x0000, TAG, 'Failed to init device manager: %{public}s', err.message);
    }
  }

  /**
   * 初始化分布式数据对象
   */
  private async initDistributedObject(context: common.Context): Promise<void> {
    try {
      this.taskContext.sessionId = distributedDataObject.genSessionId();
      this.taskContext.lastUpdateTime = Date.now();

      const object = distributedDataObject.create(context, this.taskContext);
      this.distributedObject = object;

      // 监听远端数据变化
      object.on('change', (sessionId: string, fields: Array<string>) => {
        this.handleContextChange(sessionId, fields);
      });

      // 加入分布式会话
      await object.setSessionId(this.taskContext.sessionId);

      hilog.info(0x0000, TAG, 'Distributed object created');
    } catch (error) {
      const err = error as Error;
      hilog.error(0x0000, TAG, 'Failed to create distributed object: %{public}s', err.message);
    }
  }

  /**
   * 处理上下文变化
   */
  private handleContextChange(sessionId: string, fields: Array<string>): void {
    hilog.info(0x0000, TAG, 'Context changed from session: %{public}s', sessionId);
    hilog.info(0x0000, TAG, 'Current task: %{public}s', this.taskContext.currentTask);

    this.onContextUpdated(this.taskContext.currentTask, this.taskContext.contextData);
  }

  /**
   * 刷新可信设备列表
   */
  refreshDevices(): distributedDeviceManager.DeviceBasicInfo[] {
    if (this.deviceManager) {
      this.connectedDevices = this.deviceManager.getAvailableDeviceListSync();
    }
    return this.connectedDevices;
  }

  /**
   * 上下文更新回调
   */
  private onContextUpdated(task: string, contextData: string): void {
    // 可以在这里处理接收到的任务
    hilog.info(0x0000, TAG, 'Context updated');
  }

  /**
   * 流转任务到另一设备
   */
  async transferTask(taskData: TaskData, targetDeviceId: string): Promise<boolean> {
    if (!this.distributedObject) {
      return false;
    }

    try {
      this.taskContext.currentTask = JSON.stringify(taskData);
      this.taskContext.contextData = taskData.context ?? '{}';
      this.taskContext.targetDeviceId = targetDeviceId;
      this.taskContext.lastUpdateTime = Date.now();

      hilog.info(0x0000, TAG, 'Task transferred to device: %{public}s', targetDeviceId);
      return true;
    } catch (error) {
      const err = error as Error;
      hilog.error(0x0000, TAG, 'Failed to transfer task: %{public}s', err.message);
      return false;
    }
  }

  /**
   * 获取可用设备列表
   */
  getAvailableDevices(): distributedDeviceManager.DeviceBasicInfo[] {
    return this.connectedDevices;
  }

  /**
   * 同步上下文到所有设备
   */
  async syncContext(contextData: string): Promise<void> {
    if (!this.distributedObject) {
      return;
    }

    try {
      this.taskContext.contextData = contextData;
      this.taskContext.lastUpdateTime = Date.now();

      hilog.info(0x0000, TAG, 'Context synced to all devices');
    } catch (error) {
      const err = error as Error;
      hilog.error(0x0000, TAG, 'Failed to sync context: %{public}s', err.message);
    }
  }

  /**
   * 从另一设备接收任务
   */
  async receiveTask(): Promise<TaskData | null> {
    if (!this.distributedObject) {
      return null;
    }

    try {
      const taskData: string = this.taskContext.currentTask;
      if (taskData) {
        return JSON.parse(taskData) as TaskData;
      }
      return null;
    } catch (error) {
      const err = error as Error;
      hilog.error(0x0000, TAG, 'Failed to receive task: %{public}s', err.message);
      return null;
    }
  }

  /**
   * 清理分布式会话
   */
  async cleanup(): Promise<void> {
    if (this.distributedObject) {
      try {
        // 传空字符串即退出当前会话
        await this.distributedObject.setSessionId('');
        this.distributedObject.off('change');
        this.distributedObject = null;

        if (this.deviceManager) {
          distributedDeviceManager.releaseDeviceManager(this.deviceManager);
          this.deviceManager = null;
        }

        hilog.info(0x0000, TAG, 'Distributed session cleaned up');
      } catch (error) {
        const err = error as Error;
        hilog.error(0x0000, TAG, 'Failed to cleanup: %{public}s', err.message);
      }
    }
  }
}
