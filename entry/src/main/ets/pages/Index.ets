import { router } from '@kit.ArkUI'
import { ConfigurationConstant, common } from '@kit.AbilityKit'
import { storageService } from '../services/StorageService'
import { ROUTES, DEFAULT_THEME_COLOR, STORAGE_KEYS } from '../common/Constants'
import { IMPORT_TRIGGER_KEY } from '../services/ImportService'
import { hilog } from '@kit.PerformanceAnalysisKit'

const TAG = 'Index'

/**
 * Index — 应用入口
 * 仅在应用启动时检查一次 API 配置，之后不再检查。
 */
@Preview({ title: '启动页', width: 390, height: 844, colorMode: 'light' })
@Entry
@Component
struct Index {
  @StorageLink('themeColor') themeColor: string = DEFAULT_THEME_COLOR

  aboutToAppear(): void {
    this.checkAndNavigate()
  }

  async checkAndNavigate(): Promise<void> {
    try {
      await storageService.init(getContext(this))
      const savedColor = await storageService.loadThemeColor()
      AppStorage.set('themeColor', savedColor.length > 0 ? savedColor : DEFAULT_THEME_COLOR)

      // 应用存储的颜色模式（0=跟随系统 1=浅色 2=深色），在路由之前设置
      const modeStr = await storageService.getString(STORAGE_KEYS.THEME_MODE, '0')
      const modeIndex: number = parseInt(modeStr)
      const ctx = getContext(this) as common.UIAbilityContext
      if (modeIndex === 1) {
        ctx.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT)
        AppStorage.setOrCreate('currentColorMode', ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT)
      } else if (modeIndex === 2) {
        ctx.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_DARK)
        AppStorage.setOrCreate('currentColorMode', ConfigurationConstant.ColorMode.COLOR_MODE_DARK)
      }

      const pendingUri = AppStorage.get<string>(IMPORT_TRIGGER_KEY)
      if (pendingUri) {
        AppStorage.setOrCreate('pendingImportUri', pendingUri)
        AppStorage.set(IMPORT_TRIGGER_KEY, '')
        router.replaceUrl({ url: ROUTES.MAIN })
        return
      }

      const configs = await storageService.loadApiConfigs()
      const target = configs.length > 0 ? ROUTES.MAIN : ROUTES.API_CONFIG
      router.replaceUrl({ url: target })
    } catch (err) {
      router.replaceUrl({ url: ROUTES.MAIN })
    }
  }

  build() {
    Column() {
      // 启动过渡页
      Column() {
        Image($r('app.media.WhaleChatLogoTransparency'))
          .width('50%')
          .objectFit(ImageFit.Contain)
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.start_window_background'))
  }
}