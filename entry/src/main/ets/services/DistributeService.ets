import { hilog } from '@kit.PerformanceAnalysisKit';
import { distributedDataObject } from '@kit.CoreFileKit';
import { deviceManager } from '@kit.DeviceManagerKit';

const TAG = 'DistributeService';

/**
 * 分布式服务
 * 实现跨设备协同和任务流转
 */
export class DistributeService {
  private distributedObject: distributedDataObject.DistributedObject | null = null;
  private connectedDevices: deviceManager.DeviceInfo[] = [];
  private isInitialized: boolean = false;

  /**
   * 初始化分布式服务
   */
  async initialize(): Promise<void> {
    if (this.isInitialized) {
      return;
    }

    try {
      // 初始化设备管理器
      await this.initDeviceManager();

      // 创建分布式数据对象
      await this.initDistributedObject();

      this.isInitialized = true;
      hilog.info(0x0000, TAG, 'DistributeService initialized');
    } catch (error) {
      hilog.error(0x0000, TAG, 'Failed to initialize DistributeService: %{public}s', JSON.stringify(error) ?? '');
    }
  }

  /**
   * 初始化设备管理器
   */
  private async initDeviceManager(): Promise<void> {
    try {
      // 订阅设备状态变化
      deviceManager.on('deviceChange', (devices: deviceManager.DeviceInfo[]) => {
        this.connectedDevices = devices;
        hilog.info(0x0000, TAG, 'Devices changed: %{public}d', devices.length);
        this.onDevicesChanged(devices);
      });

      // 获取已连接设备
      this.connectedDevices = deviceManager.getTrustedDeviceList();
      
      hilog.info(0x0000, TAG, 'Connected devices: %{public}d', this.connectedDevices.length);
    } catch (error) {
      hilog.error(0x0000, TAG, 'Failed to init device manager: %{public}s', JSON.stringify(error) ?? '');
    }
  }

  /**
   * 初始化分布式数据对象
   */
  private async initDistributedObject(): Promise<void> {
    try {
      this.distributedObject = distributedDataObject.create({
        name: 'OpenHarmonyAgent_Context',
        context: undefined as any // 需要传入 Ability context
      });

      // 设置初始数据
      this.distributedObject.currentTask = '';
      this.distributedObject.contextData = '{}';
      this.distributedObject.lastUpdateTime = Date.now();

      // 监听变化
      this.distributedObject.on('change', (sessionId: string) => {
        this.handleContextChange(sessionId);
      });

      // 加入会话
      this.distributedObject.join('OpenHarmonyAgent_Session');

      hilog.info(0x0000, TAG, 'Distributed object created');
    } catch (error) {
      hilog.error(0x0000, TAG, 'Failed to create distributed object: %{public}s', JSON.stringify(error) ?? '');
    }
  }

  /**
   * 处理上下文变化
   */
  private handleContextChange(sessionId: string): void {
    if (!this.distributedObject) return;

    const currentTask = this.distributedObject.currentTask;
    const contextData = this.distributedObject.contextData;

    hilog.info(0x0000, TAG, 'Context changed from session: %{public}s', sessionId);
    hilog.info(0x0000, TAG, 'Current task: %{public}s', currentTask);

    // 触发上下文更新回调
    this.onContextUpdated(currentTask, contextData);
  }

  /**
   * 设备列表变化回调
   */
  private onDevicesChanged(devices: deviceManager.DeviceInfo[]): void {
    // 可以在这里更新 UI 显示可用设备
    hilog.info(0x0000, TAG, 'Available devices updated');
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
  async transferTask(taskData: {
    type: string;
    content: string;
    context?: any;
  }, targetDeviceId: string): Promise<boolean> {
    if (!this.distributedObject) {
      return false;
    }

    try {
      // 更新分布式对象
      this.distributedObject.currentTask = JSON.stringify(taskData);
      this.distributedObject.contextData = JSON.stringify(taskData.context || {});
      this.distributedObject.lastUpdateTime = Date.now();
      this.distributedObject.targetDeviceId = targetDeviceId;

      hilog.info(0x0000, TAG, 'Task transferred to device: %{public}s', targetDeviceId);
      return true;
    } catch (error) {
      hilog.error(0x0000, TAG, 'Failed to transfer task: %{public}s', JSON.stringify(error) ?? '');
      return false;
    }
  }

  /**
   * 获取可用设备列表
   */
  getAvailableDevices(): deviceManager.DeviceInfo[] {
    return this.connectedDevices;
  }

  /**
   * 同步上下文到所有设备
   */
  async syncContext(contextData: any): Promise<void> {
    if (!this.distributedObject) {
      return;
    }

    try {
      this.distributedObject.contextData = JSON.stringify(contextData);
      this.distributedObject.lastUpdateTime = Date.now();

      hilog.info(0x0000, TAG, 'Context synced to all devices');
    } catch (error) {
      hilog.error(0x0000, TAG, 'Failed to sync context: %{public}s', JSON.stringify(error) ?? '');
    }
  }

  /**
   * 从另一设备接收任务
   */
  async receiveTask(): Promise<any> {
    if (!this.distributedObject) {
      return null;
    }

    try {
      const taskData = this.distributedObject.currentTask;
      if (taskData) {
        return JSON.parse(taskData);
      }
      return null;
    } catch (error) {
      hilog.error(0x0000, TAG, 'Failed to receive task: %{public}s', JSON.stringify(error) ?? '');
      return null;
    }
  }

  /**
   * 清理分布式会话
   */
  async cleanup(): Promise<void> {
    if (this.distributedObject) {
      try {
        this.distributedObject.leave('OpenHarmonyAgent_Session');
        this.distributedObject.stop();
        this.distributedObject = null;
        hilog.info(0x0000, TAG, 'Distributed session cleaned up');
      } catch (error) {
        hilog.error(0x0000, TAG, 'Failed to cleanup: %{public}s', JSON.stringify(error) ?? '');
      }
    }
  }
}
