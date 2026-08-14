import { router } from '@kit.ArkUI'
import { storageService } from '../services/StorageService'
import { ROUTES } from '../common/Constants'

/**
 * Index — 应用入口
 * 检查是否已完成 API 配置，自动跳转到对应页面
 */
@Entry
@Component
struct Index {
  aboutToAppear(): void {
    this.checkAndNavigate()
  }

  async checkAndNavigate(): Promise<void> {
    try {
      await storageService.init(getContext(this))
      const hasLaunched = await storageService.hasLaunched()

      if (hasLaunched) {
        // 已配置，跳转到主页面
        router.replaceUrl({ url: ROUTES.MAIN })
      } else {
        // 未配置，跳转到 API 配置页
        router.replaceUrl({ url: ROUTES.API_CONFIG })
      }
    } catch (err) {
      // 初始化失败，默认跳转配置页
      router.replaceUrl({ url: ROUTES.API_CONFIG })
    }
  }

  build() {
    Column() {
      // 启动过渡页
      Column() {
        Text('💬')
          .fontSize(48)
          .margin({ bottom: 16 })
        Text('DeepChat')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor('#4A90D9')
        LoadingProgress()
          .width(24)
          .height(24)
          .color('#4A90D9')
          .margin({ top: 24 })
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }
}