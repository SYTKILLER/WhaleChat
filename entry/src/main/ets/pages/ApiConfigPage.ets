/**
 * ApiConfigPage — API 配置页面
 *
 * 首次启动时显示，引导用户配置 API 密钥和平台。
 * 配置完成后跳转到主页面。
 */

import { router } from '@kit.ArkUI'
import { promptAction } from '@kit.ArkUI'
import {
  ApiConfig,
  CUSTOM_PROVIDER_ID,
  createDefaultApiConfig
} from '../models/ApiConfig'
import { storageService } from '../services/StorageService'
import { apiService } from '../services/ApiService'
import { ROUTES } from '../common/Constants'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { LucideIcon, LucideIcons } from '../components/LucideIcon'
const DOMAIN = 0x0003
const TAG = 'ApiConfigPage'

@Preview({ title: 'API配置页 - 浅色', width: 390, height: 844 })
@Preview({ title: 'API配置页 - 深色', width: 390, height: 844, colorMode: 'dark' })
@Entry
@Component
struct ApiConfigPage {
  @State config: ApiConfig = createDefaultApiConfig()
  @State showApiKey: boolean = false
  @State testingConnection: boolean = false
  @State testResult: string = ''
  @State customModelInput: string = ''
  @State customBaseUrlInput: string = 'https://api.deepseek.com'
  @State currentStep: number = 0 // 0-登录华为账号, 1-配置API
  @State showSkipWarning: boolean = false
  @StorageLink('currentColorMode') currentColorMode: number = 0
  @StorageLink('themeColor') themeColor: string = '#007DFF'
  @StorageLink('account_logged_in') accountLoggedIn: boolean = false
  @StorageLink('huaweiUnionId') huaweiUnionId: string = ''

  aboutToAppear(): void {
    // 加载已有配置（如果有）
    storageService.loadApiConfig().then((saved: ApiConfig | null) => {
      if (saved && saved.apiKey) {
        this.config = saved
        this.customModelInput = saved.customModel
        this.customBaseUrlInput = saved.customBaseUrl || 'https://api.deepseek.com'
      }
    })
  }

  build() {
    Column() {
      // 二级标题栏
      Row() {
        Button() {
          LucideIcon({
            icon: LucideIcons.ARROW_LEFT,
            color: this.currentColorMode === 1 ? '#333333' : '#CCCCCC',
            iconSize: 22
          })
        }
        .width(36).height(36).backgroundColor('#00000000')
        .onClick(() => { router.back() })

        Text('API 配置')
          .fontSize(19)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        Column().width(36)
      }
      .width('100%')
      .height(96)
      .backgroundColor(this.currentColorMode === 1 ?
        'rgba(250, 250, 250, 0.75)' : 'rgba(34, 34, 34, 0.75)')
      .backgroundBlurStyle(BlurStyle.Regular)
      .padding({ left: 8, right: 8, top: 40, bottom: 8 })
      .borderWidth({ bottom: 0.5 })
      .borderColor(this.currentColorMode === 1 ? '#E0E0E0' : '#444444')

      Text('配置 AI 服务以开始使用')
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
        .padding({ bottom: 32 })

      // 步骤指示器
      this.StepIndicator()

      // 步骤内容
      if (this.currentStep === 0) {
        this.VerificationStep()
      } else {
        this.ApiKeyStep()
      }

      Blank()

      // 底部按钮
      this.BottomButtons()

      // 跳过按钮
      Button('跳过，稍后配置')
        .fontSize(13)
        .fontColor($r('app.color.text_secondary'))
        .backgroundColor(Color.Transparent)
        .margin({ top: 8, bottom: 32 })
        .onClick(() => {
          this.showSkipWarning = true
        })
        .bindSheet($$this.showSkipWarning, this.SkipWarningSheet, {
          height: SheetSize.MEDIUM,
          showClose: false,
          backgroundColor: this.currentColorMode === 1 ? Color.White : '#2A2A2A'
        })
    }
    .width('100%')
    .height('100%')
    .padding({ left: 24, right: 24 })
    .backgroundColor(this.currentColorMode === 1 ? '#FFFFFF' : '#1A1A1A')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
  }

  @Builder
  StepIndicator() {
    Row() {
      ForEach(['登录华为账号', '配置api密钥'], (step: string, index: number) => {
        Row() {
          Column() {
            Text(`${index + 1}`)
              .fontSize(12)
              .fontColor(index <= this.currentStep ? Color.White : (this.currentColorMode === 1 ? '#6B6B6B' : '#CCCCCC'))
          }
          .width(24)
          .height(24)
          .borderRadius(12)
          .backgroundColor(index <= this.currentStep ? this.themeColor :
            (this.currentColorMode === 1 ? '#DDDDDD' : '#808080'))
          .justifyContent(FlexAlign.Center)

          Text(step)
            .fontSize(12)
            .fontColor(index <= this.currentStep ? this.themeColor :
              (this.currentColorMode === 1 ? '#6B6B6B' : '#EEEEEE'))
            .margin({ left: 6 })
        }
        if (index < 1) {
          Divider()
            .width(30)
            .height(1)
            .color(index < this.currentStep ? this.themeColor :
              (this.currentColorMode === 1 ? '#DDDDDD' : '#808080'))
            .margin({ left: 4, right: 4 })
        }
      })
    }
    .width('100%')
    .padding({ bottom: 24 })
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  ApiKeyStep() {
    Column() {
      Text('输入 API 密钥')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .width('100%')
        .padding({ bottom: 8 })

      // API 地址文本框（始终显示，默认 DeepSeek，可改为任意 OpenAI 兼容地址）
      TextInput({ text: this.customBaseUrlInput, placeholder: 'API Base URL (例如 https://api.deepseek.com)' })
        .fontSize(14)
        .width('100%')
        .height(48)
        .backgroundColor($r('app.color.bg_input'))
        .borderRadius(10)
        .padding(12)
        .margin({ bottom: 8 })
        .onChange((value: string) => {
          this.customBaseUrlInput = value
          this.config.customBaseUrl = value
        })

      // API Key 输入
      Row() {
        TextInput({ text: this.config.apiKey, placeholder: '请输入 API Key' })
          .type(this.showApiKey ? InputType.Normal : InputType.Password)
          .fontSize(15)
          .layoutWeight(1)
          .height(48)
          .onChange((value: string) => {
            this.config.apiKey = value
          })

        Button() {
          Text(this.showApiKey ? '隐藏' : '显示')
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
        }
        .width(44)
        .height(44)
        .backgroundColor($r('app.color.bg_input'))
        .borderRadius(8)
        .onClick(() => {
          this.showApiKey = !this.showApiKey
        })
      }
      .width('100%')
      .padding(12)
      .backgroundColor($r('app.color.bg_input'))
      .borderRadius(10)
      .margin({ bottom: 8 })

      // 连接测试按钮
      Button() {
        Row() {
          if (this.testingConnection) {
            LoadingProgress()
              .width(16)
              .height(16)
              .color(Color.White)
          }
          Text(this.testingConnection ? '测试中…' : '测试连接')
            .fontSize(14)
            .fontColor(this.config.apiKey ? Color.White :
              (this.currentColorMode === 1 ? '#000000' : '#EEEEEE'))
            .margin({ left: 6 })
        }
      }
      .width('100%')
      .height(40)
      .backgroundColor(this.config.apiKey ? this.themeColor :
        (this.currentColorMode === 1 ? '#E5E5E5' : '#555555'))
      .borderRadius(8)
      .onClick(() => {
        if (this.config.apiKey.length > 0 && !this.testingConnection) {
          this.testConnection()
        }
      })

      if (this.testResult) {
        Text(this.testResult)
          .fontSize(13)
          .fontColor(this.testResult.includes('成功') ? '#34C759' : '#FF3B30')
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({ top: 8 })
      }
    }
  }

  @Builder
  VerificationStep() {
    Column() {
      Text('身份认证')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .width('100%')
        .padding({ bottom: 8 })

      Text('根据相关规定，使用 AI 服务需要验证您的真实身份。请登录华为账号完成身份认证。')
        .fontSize(13)
        .fontColor($r('app.color.text_secondary'))
        .width('100%')
        .padding({ bottom: 24 })

      if (this.accountLoggedIn && this.huaweiUnionId) {
        SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
          .fontSize(48)
          .fontColor(['#34C759'])
          .margin({ bottom: 12 })
        Text('身份认证已完成')
          .fontSize(16).fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .margin({ bottom: 24 })
        Button('下一步')
          .fontSize(15).fontWeight(FontWeight.Medium)
          .width('80%').height(44)
          .backgroundColor(this.themeColor).fontColor(Color.White)
          .borderRadius(10)
          .onClick(() => { this.currentStep = 1 })
      } else {
        SymbolGlyph($r('sys.symbol.exclamationmark_triangle'))
          .fontSize(48).fontColor(['#FF9500']).margin({ bottom: 12 })
        Text('需要登录华为账号')
          .fontSize(16).fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary')).margin({ bottom: 4 })
        Text('登录华为账号以完成身份认证')
          .fontSize(13).fontColor($r('app.color.text_secondary'))
          .width('80%').textAlign(TextAlign.Center).margin({ bottom: 20 })
        Button('登录华为账号')
          .fontSize(15).fontWeight(FontWeight.Medium)
          .width('80%').height(44)
          .backgroundColor('#CF0A2C').fontColor(Color.White)
          .borderRadius(10)
          .onClick(() => { router.pushUrl({ url: 'pages/LoginPage' }) })
      }
    }
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  BottomButtons() {
    Row() {
      // 上一步
      if (this.currentStep > 0) {
        Button('上一步')
          .fontSize(14)
          .height(44)
          .layoutWeight(1)
          .backgroundColor(this.currentColorMode === 1 ? '#F0F0F0' : '#505050')
          .fontColor(this.currentColorMode === 1 ? '#333333' : '#DDDDDD')
          .borderRadius(10)
          .margin({ right: 8 })
          .onClick(() => {
            this.currentStep--
          })
      }

      // 下一步（仅步骤0显示，认证完成后进入配置）
      if (this.currentStep < 1) {
        Button('下一步')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .height(44)
          .layoutWeight(1)
          .backgroundColor(this.themeColor)
          .fontColor(Color.White)
          .borderRadius(10)
          .onClick(() => {
            this.handleNext()
          })
      }
    }
    .width('100%')
    .padding({ bottom: 40 })
  }

  /**
   * 跳过警告半模态面板
   */
  @Builder
  SkipWarningSheet() {
    Column() {
      SymbolGlyph($r('sys.symbol.exclamationmark_triangle'))
        .fontSize(40)
        .fontColor(['#FF9500'])
        .margin({ top: 24, bottom: 16 })

      Text('需要配置 API 才可以对话')
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.currentColorMode === 1 ? '#333333' : '#EEEEEE')
        .margin({ bottom: 8 })

      Text('跳过后可在「设置 → API 平台配置」中添加 API 密钥，之后即可正常对话。')
        .fontSize(13)
        .fontColor($r('app.color.text_secondary'))
        .textAlign(TextAlign.Center)
        .width('80%')
        .margin({ bottom: 24 })

      Button('确定')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .width('80%')
        .height(44)
        .backgroundColor(this.themeColor)
        .fontColor(Color.White)
        .borderRadius(10)
        .onClick(() => {
          this.showSkipWarning = false
          router.replaceUrl({ url: ROUTES.MAIN })
        })

      Button('返回配置')
        .fontSize(14)
        .width('80%')
        .height(40)
        .backgroundColor(Color.Transparent)
        .fontColor(this.themeColor)
        .margin({ top: 8, bottom: 24 })
        .onClick(() => {
          this.showSkipWarning = false
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }

  /**
   * 处理下一步
   */
  private async handleNext(): Promise<void> {
    if (this.currentStep === 0) {
      // 未认证时不允许进入配置步骤
      if (!this.accountLoggedIn || !this.huaweiUnionId) {
        promptAction.showToast({ message: '请先登录华为账号', duration: 1500 })
        return
      }
      this.currentStep = 1
    }
  }

  /**
   * 测试 API 连接
   */
  private async testConnection(): Promise<void> {
    this.testingConnection = true
    this.testResult = ''

    // 临时应用自定义 Base URL
    if (this.config.providerId === CUSTOM_PROVIDER_ID) {
      this.config.customBaseUrl = this.customBaseUrlInput
    }

    const result = await apiService.testConnection(this.config)
    this.testResult = result.message
    this.testingConnection = false

    if (result.success && this.currentStep === 1) {
      // 测试成功：保存配置并进入主页面
      this.config.isConfigured = true
      await storageService.init(getContext(this))
      await storageService.saveApiConfig(this.config)
      router.replaceUrl({ url: ROUTES.MAIN })
    }
  }
}
