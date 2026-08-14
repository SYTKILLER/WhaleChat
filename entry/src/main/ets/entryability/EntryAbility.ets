import { AbilityConstant, Configuration, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { setPendingImportUri } from '../services/ImportService';
import { dbHelper } from '../services/DatabaseHelper';
import { migrationService } from '../services/MigrationService';
import auth from '@hw-agconnect/auth';
import { util } from '@kit.ArkTS';

const DOMAIN = 0x0000;
const TAG = 'EntryAbility'

export default class EntryAbility extends UIAbility {
  private mainWindow: window.Window | null = null;

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }

    // 初始化 AppStorage 中的 currentColorMode，从系统当前色彩模式读取
    try {
      const config = this.context.config;
      if (config && config.colorMode !== undefined) {
        AppStorage.setOrCreate('currentColorMode', config.colorMode);
        hilog.info(DOMAIN, TAG, 'Initialized currentColorMode: %{public}d', config.colorMode);
      } else {
        AppStorage.setOrCreate('currentColorMode', ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
      }
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'Failed to read system color mode, defaulting to light');
      AppStorage.setOrCreate('currentColorMode', ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
    }

    // 通过打开文件启动时处理导入
    if (want?.uri) {
      setPendingImportUri(want.uri)
    }

    // 初始化 Cloud Kit RdbStore（端云同步数据库），异步不阻塞启动
    dbHelper.init(this.context).then(() => {
      // 从旧 Preferences 迁移数据到 RdbStore（首次启动时执行）
      return migrationService.run(this.context)
    }).catch((err: Error) => {
      hilog.error(DOMAIN, TAG, 'Database init failed: %{public}s', (err?.message) ?? '')
    })

    hilog.info(DOMAIN, TAG, 'Ability onCreate');
  }

  onConfigurationUpdate(newConfig: Configuration): void {
    hilog.info(DOMAIN, TAG, 'onConfigurationUpdate, colorMode: %{public}d', newConfig.colorMode);
    // 当系统色彩模式变更时（如跟随日落/日出自动切换），同步更新 AppStorage
    if (newConfig && newConfig.colorMode !== undefined) {
      AppStorage.setOrCreate('currentColorMode', newConfig.colorMode);
    }
    // 同步更新系统栏内容颜色
    this.updateSystemBarColors();
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, TAG, 'onNewWant: %{public}s', JSON.stringify(want));

    // 处理其他应用分享/打开的文件
    if (want?.uri) {
      setPendingImportUri(want.uri)
    }
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    // 沉浸式全屏窗口：内容延伸到系统栏背后
    this.initImmersiveWindow(windowStage);

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
    });
  }

  private async initImmersiveWindow(windowStage: window.WindowStage): Promise<void> {
    try {
      this.mainWindow = await windowStage.getMainWindow();
      await this.mainWindow.setWindowLayoutFullScreen(true);
      // 根据当前色彩模式设置系统栏内容颜色
      this.updateSystemBarColors();
    } catch (err) {
      hilog.warn(DOMAIN, 'testTag', 'Immersive window init failed');
    }
  }

  /**
   * 根据当前系统色彩模式更新状态栏与导航栏内容颜色
   */
  private async updateSystemBarColors(): Promise<void> {
    try {
      if (!this.mainWindow) return;
      const colorMode = this.context.config?.colorMode;
      const barContentColor = (colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK) ? '#FFFFFF' : '#000000';
      await this.mainWindow.setWindowSystemBarProperties({
        statusBarColor: '#00000000',
        navigationBarColor: '#00000000',
        statusBarContentColor: barContentColor,
        navigationBarContentColor: barContentColor
      });
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'Failed to update system bar colors');
    }
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}