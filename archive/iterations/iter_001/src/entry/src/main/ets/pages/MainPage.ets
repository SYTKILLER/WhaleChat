/**
 * MainPage — 主页面（底部 Tab 导航）
 *
 * Tab 1: 对话列表 (ConversationListPage)
 * Tab 2: 设置 (SettingsPage)
 */
import { ConversationListPage } from './ConversationListPage'
import { SettingsPage } from './SettingsPage'
import { storageService } from '../services/StorageService'
import { ROUTES } from '../common/Constants'
import { router } from '@kit.ArkUI'

@Entry
@Component
struct MainPage {
  @State currentTabIndex: number = 0
  @StorageLink('currentColorMode') currentColorMode: number = 0
  private tabTitles: string[] = ['对话', '设置']

  aboutToAppear(): void {
    // 检查是否已配置 API
    storageService.init(getContext(this)).then(() => {
      storageService.hasLaunched().then((launched) => {
        if (!launched) {
          router.replaceUrl({ url: ROUTES.API_CONFIG })
        }
      })
    })
  }

  build() {
    Tabs({ index: this.currentTabIndex }) {
      TabContent() {
        ConversationListPage()
      }
      .tabBar(this.TabBarBuilder(0))

      TabContent() {
        SettingsPage()
      }
      .tabBar(this.TabBarBuilder(1))
    }
    .barHeight(56)
    .barMode(BarMode.Fixed)
    .onChange((index: number) => {
      this.currentTabIndex = index
    })
    .width('100%')
    .height('100%')
    .backgroundColor(this.currentColorMode === 0 ? '#FFFFFF' : '#1A1A1A')
  }

  @Builder
  TabBarBuilder(index: number) {
    Column() {
      if (index === 0) {
        // 对话 Tab 图标
        Text('💬')
          .fontSize(20)
      } else {
        // 设置 Tab 图标
        Text('⚙️')
          .fontSize(20)
      }

      Text(this.tabTitles[index])
        .fontSize(10)
        .fontColor(this.currentTabIndex === index ? '#4A90D9' : '#999999')
        .margin({ top: 2 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .padding({ top: 4 })
    .opacity(this.currentTabIndex === index ? 1.0 : 0.5)
  }
}
