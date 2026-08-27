import { hilog } from '@kit.PerformanceAnalysisKit';

const LOG_DOMAIN = 'OpenHarmonyAgent';

/**
 * 日志工具类
 */
export class Logger {
  private static domain: string = LOG_DOMAIN;

  /**
   * 信息日志
   */
  static info(tag: string, message: string): void {
    hilog.info(0x0000, `${this.domain}.${tag}`, '%{public}s', message);
  }

  /**
   * 警告日志
   */
  static warn(tag: string, message: string): void {
    hilog.warn(0x0000, `${this.domain}.${tag}`, '%{public}s', message);
  }

  /**
   * 错误日志
   */
  static error(tag: string, message: string): void {
    hilog.error(0x0000, `${this.domain}.${tag}`, '%{public}s', message);
  }

  /**
   * 调试日志
   */
  static debug(tag: string, message: string): void {
    hilog.debug(0x0000, `${this.domain}.${tag}`, '%{public}s', message);
  }

  /**
   * 带格式的日志
   */
  static format(tag: string, level: 'info' | 'warn' | 'error' | 'debug', message: string, ...args: any[]): void {
    const formattedMessage = message.replace(/%s/g, () => args.shift() || '');
    const logFunc = this[level].bind(this);
    logFunc(tag, formattedMessage);
  }

  /**
   * 性能日志
   */
  static performance(tag: string, operation: string, startTime: number): void {
    const duration = Date.now() - startTime;
    this.info(tag, `${operation} completed in ${duration}ms`);
  }
}
