/**
 * MainPage — 主页面（HdsTabs 悬浮式底部 Tab 导航 + 系统材质 + 震动反馈）
 */
import { ConversationListPage } from './ConversationListPage'
import { SettingsPage } from './SettingsPage'
import { storageService } from '../services/StorageService'
import { vibrator } from '@kit.SensorServiceKit'
import { tryImportFromUri } from '../services/ImportService'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { HdsTabs, HdsTabsController, hdsMaterial } from '@kit.UIDesignKit'
import { SymbolGlyphModifier } from '@kit.ArkUI'

const TAG = 'MainPage'

@Preview({ title: '主页 - 浅色', width: 390, height: 844 })
@Preview({ title: '主页 - 深色', width: 390, height: 844, colorMode: 'dark' })
@Entry
@Component
struct MainPage {
  @State currentTabIndex: number = 0
  @StorageLink('themeColor') themeColor: string = '#007DFF'
  @StorageLink('currentColorMode') currentColorMode: number = 0
  private tabsController: HdsTabsController = new HdsTabsController()

  aboutToAppear(): void {
    storageService.init(getContext(this))
    this.handlePendingImport()
  }

  async handlePendingImport(): Promise<void> {
    const pendingUri = AppStorage.get<string>('pendingImportUri')
    if (!pendingUri) return
    AppStorage.set('pendingImportUri', '')
    try {
      const imported = await tryImportFromUri(getContext(this), pendingUri)
      if (imported.length > 0) {
        AppStorage.setOrCreate('convListRefreshKey', `import_${Date.now()}`)
        hilog.info(0x0000, TAG, `Imported ${imported.length} conversations via file open`)
      }
    } catch (err) {
      hilog.error(0x0000, TAG, `Import error: ${err}`)
    }
  }

  onPageShow(): void {
    AppStorage.setOrCreate<string>('convListRefreshKey', `${Date.now()}`)
  }

  /**
   * 选中态颜色：默认使用系统主色，自定义时使用用户选择的颜色
   */
  private selectedColor(): ResourceColor {
    if (this.themeColor === '#007DFF') {
      return $r('sys.color.ohos_id_color_activated')
    }
    return this.themeColor
  }

  build() {
    HdsTabs({ controller: this.tabsController, index: this.currentTabIndex }) {
      TabContent() {
        ConversationListPage()
      }
      .tabBar(
        new BottomTabBarStyle({
          normal: new SymbolGlyphModifier($r('sys.symbol.message'))
            .fontWeight(FontWeight.Normal)
            .fontColor([
              $r('sys.color.ohos_id_color_bottom_tab_icon_off'),
              $r('sys.color.ohos_id_color_bottom_tab_icon_auxcolor_off02')
            ]),
          selected: new SymbolGlyphModifier($r('sys.symbol.message'))
            .fontWeight(FontWeight.Medium)
            .fontColor([
              this.selectedColor(),
              $r('sys.color.ohos_id_color_primary_contrary')
            ])
        }, '对话')
      )

      TabContent() {
        SettingsPage()
      }
      .tabBar(
        new BottomTabBarStyle({
          normal: new SymbolGlyphModifier($r('sys.symbol.gearshape'))
            .fontWeight(FontWeight.Normal)
            .fontColor([
              $r('sys.color.ohos_id_color_bottom_tab_icon_off'),
              $r('sys.color.ohos_id_color_bottom_tab_icon_auxcolor_off02')
            ]),
          selected: new SymbolGlyphModifier($r('sys.symbol.gearshape'))
            .fontWeight(FontWeight.Medium)
            .fontColor([
              this.selectedColor(),
              $r('sys.color.ohos_id_color_primary_contrary')
            ])
        }, '设置')
      )
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_page'))
    .barOverlap(true)
    .barPosition(BarPosition.End)
    .vertical(false)
    .barFloatingStyle({
      barWidth: { smallWidth: 168, mediumWidth: 180, largeWidth: 240 },
      barBottomMargin: 16,
      gradientMask: {
        maskColor: this.currentColorMode === 1 ? '#66F1F3F5' : '#66121212',
        maskHeight: 80
      },
      systemMaterialEffect: {
        materialType: hdsMaterial.MaterialType.ADAPTIVE,
        materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
      }
    })
    .onChange((index: number) => {
      if (this.currentTabIndex !== index) {
        try {
          vibrator.startVibration({ type: 'time', duration: 15 }, { usage: 'touch' })
        } catch (_) {}
      }
      this.currentTabIndex = index
    })
  }
}
