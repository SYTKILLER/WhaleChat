import { hilog } from '@kit.PerformanceAnalysisKit';
import { BackupExtensionAbility, BundleVersion } from '@kit.CoreFileKit';

const DOMAIN = 0x0000;
const TAG = 'EntryBackupAbility'

export default class EntryBackupAbility extends BackupExtensionAbility {
  async onBackup(): Promise<void> {
    hilog.info(DOMAIN, TAG, 'Cloud backup started');
    // 系统自动备份 /data/storage/el2/base/preferences/ 下的数据
    // 无需手动序列化，系统处理文件级备份
    await Promise.resolve();
    hilog.info(DOMAIN, TAG, 'Cloud backup completed');
  }

  async onRestore(bundleVersion: BundleVersion): Promise<void> {
    hilog.info(DOMAIN, TAG, 'Cloud restore started, bundleVersion: %{public}s',
      JSON.stringify(bundleVersion));
    // 系统自动恢复 Preferences 文件
    await Promise.resolve();
    hilog.info(DOMAIN, TAG, 'Cloud restore completed');
  }
}
