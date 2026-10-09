import { hilog } from '@kit.PerformanceAnalysisKit';
import { BackupExtensionAbility, BundleVersion } from '@kit.CoreFileKit';

const TAG = 'EntryBackupAbility';

export default class EntryBackupAbility extends BackupExtensionAbility {
  onBackup(): void {
    hilog.info(0x0000, TAG, 'onBackup');
  }

  onRestore(bundleVersion: BundleVersion): void {
    hilog.info(0x0000, TAG, 'onRestore');
  }
}
