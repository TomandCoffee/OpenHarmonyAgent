import { hilog } from '@kit.PerformanceAnalysisKit';
import { AbilityConstant, Want } from '@kit.AbilityKit';
import { router } from '@kit.ArkUI';
import { BackupExtensionAbility, FileExtension, BackupConfig } from '@kit.CoreFileKit';

const TAG = 'EntryBackupAbility';

export default class EntryBackupAbility extends BackupExtensionAbility {
  onBackup(files: FileExtension.BackupFile[], config: BackupConfig): void {
    hilog.info(0x0000, TAG, 'onBackup');
  }

  onRestore(files: FileExtension.BackupFile[], config: BackupConfig): void {
    hilog.info(0x0000, TAG, 'onRestore');
  }
}
