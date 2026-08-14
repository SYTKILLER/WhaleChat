/**
 * ApiConfigPage — API 配置页面
 *
 * 首次启动时显示，引导用户配置 API 密钥和平台。
 * 配置完成后跳转到主页面。
 */

import { router } from '@kit.ArkUI'
import {
  ApiConfig,
  PRESET_PROVIDERS,
  CUSTOM_PROVIDER_ID,
  createDefaultApiConfig,
  getProvider,
  getEffectiveModel
} from '../models/ApiConfig'
import { storageService } from '../services/StorageService'
import { apiService } from '../services/ApiService'
import { ROUTES } from '../common/Constants'
import { hilog } from '@kit.PerformanceAnalysisKit'

const DOMAIN = 0x0003
const TAG = 'ApiConfigPage'

@Entry
@Component
struct ApiConfigPage {
  @State config: ApiConfig = createDefaultApiConfig()
  @State showApiKey: boolean = false
  @State testingConnection: boolean = false
  @State testResult: string = ''
  @State customModelInput: string = ''
  @State customBaseUrlInput: string = ''
  @State currentStep: number = 0 // 0-选平台, 1-填Key, 2-选模型
  @StorageLink('currentColorMode') currentColorMode: number = 0

  aboutToAppear(): void {
    // 加载已有配置（如果有）
    storageService.loadApiConfig().then((saved) => {
      if (saved.apiKey) {
        this.config = saved
        this.customModelInput = saved.customModel
        this.customBaseUrlInput = saved.customBaseUrl
      }
    })
  }

  build() {
    Column() {
      // 顶部标题
      Row() {
        Text('DeepChat')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor('#4A90D9')
      }
      .width('100%')
      .padding({ top: 60, bottom: 8 })
      .justifyContent(FlexAlign.Center)

      Text('配置 AI 服务以开始使用')
        .fontSize(14)
        .fontColor('#999999')
        .padding({ bottom: 32 })

      // 步骤指示器
      this.StepIndicator()

      // 步骤内容
      if (this.currentStep === 0) {
        this.PlatformStep()
      } else if (this.currentStep === 1) {
        this.ApiKeyStep()
      } else {
        this.ModelStep()
      }

      Blank()

      // 底部按钮
      this.BottomButtons()
    }
    .width('100%')
    .height('100%')
    .padding({ left: 24, right: 24 })
    .backgroundColor(this.currentColorMode === 0 ? '#FFFFFF' : '#1A1A1A')
  }

  @Builder
  StepIndicator() {
    Row() {
      ForEach(['选择平台', '配置密钥', '选择模型'], (step: string, index: number) => {
        Row() {
          Column() {
            Text(`${index + 1}`)
              .fontSize(12)
              .fontColor(index <= this.currentStep ? Color.White : '#999999')
          }
          .width(24)
          .height(24)
          .borderRadius(12)
          .backgroundColor(index <= this.currentStep ? '#4A90D9' : '#DDDDDD')
          .justifyContent(FlexAlign.Center)

          Text(step)
            .fontSize(12)
            .fontColor(index <= this.currentStep ? '#333333' : '#999999')
            .margin({ left: 6 })
        }
        if (index < 2) {
          Divider()
            .width(30)
            .height(1)
            .color(index < this.currentStep ? '#4A90D9' : '#DDDDDD')
            .margin({ left: 4, right: 4 })
        }
      })
    }
    .width('100%')
    .padding({ bottom: 24 })
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  PlatformStep() {
    Column() {
      Text('选择 AI 平台')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .width('100%')
        .padding({ bottom: 16 })

      // 预设平台列表
      ForEach(PRESET_PROVIDERS, (provider) => {
        Row() {
          Column() {
            Text(provider.name)
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
            Text(provider.baseUrl)
              .fontSize(12)
              .fontColor('#999999')
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          Radio({ value: provider.id, group: 'platform' })
            .checked(this.config.providerId === provider.id)
            .onClick(() => {
              this.config.providerId = provider.id
              this.config.selectedModel = provider.defaultModels[0] ?? ''
            })
        }
        .width('100%')
        .padding(14)
        .margin({ bottom: 8 })
        .borderRadius(10)
        .backgroundColor(this.config.providerId === provider.id ? '#E8F0FE' : '#F5F5F5')
        .border({
          width: 2,
          color: this.config.providerId === provider.id ? '#4A90D9' : '#E0E0E0'
        })
        .onClick(() => {
          this.config.providerId = provider.id
          this.config.selectedModel = provider.defaultModels[0] ?? ''
        })
      })

      // 自定义平台
      Row() {
        Text('自定义')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
        Blank()
        Radio({ value: CUSTOM_PROVIDER_ID, group: 'platform' })
          .checked(this.config.providerId === CUSTOM_PROVIDER_ID)
          .onClick(() => {
            this.config.providerId = CUSTOM_PROVIDER_ID
          })
      }
      .width('100%')
      .padding(14)
      .borderRadius(10)
      .backgroundColor(this.config.providerId === CUSTOM_PROVIDER_ID ? '#E8F0FE' : '#F5F5F5')
      .border({
        width: 2,
        color: this.config.providerId === CUSTOM_PROVIDER_ID ? '#4A90D9' : '#E0E0E0'
      })
      .margin({ bottom: 8 })
      .onClick(() => {
        this.config.providerId = CUSTOM_PROVIDER_ID
      })
    }
  }

  @Builder
  ApiKeyStep() {
    Column() {
      Text('输入 API 密钥')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .width('100%')
        .padding({ bottom: 8 })

      const provider = getProvider(this.config.providerId)
      Text(provider ? `平台: ${provider.name}` : '平台: 自定义')
        .fontSize(13)
        .fontColor('#999999')
        .width('100%')
        .padding({ bottom: 16 })

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
          Image(this.showApiKey ? $r('sys.media.ohos_ic_public_eye_opened') : $r('sys.media.ohos_ic_public_eye_closed'))
            .width(20)
            .height(20)
            .fillColor('#999999')
        }
        .width(44)
        .height(44)
        .backgroundColor('#F5F5F5')
        .borderRadius(8)
        .onClick(() => {
          this.showApiKey = !this.showApiKey
        })
      }
      .width('100%')
      .padding(12)
      .backgroundColor('#F5F5F5')
      .borderRadius(10)
      .margin({ bottom: 8 })

      // 自定义 Base URL（仅自定义平台时显示）
      if (this.config.providerId === CUSTOM_PROVIDER_ID) {
        TextInput({ text: this.customBaseUrlInput, placeholder: 'API Base URL (例如 https://api.deepseek.com)' })
          .fontSize(14)
          .width('100%')
          .height(48)
          .backgroundColor('#F5F5F5')
          .borderRadius(10)
          .padding(12)
          .margin({ bottom: 8 })
          .onChange((value: string) => {
            this.customBaseUrlInput = value
            this.config.customBaseUrl = value
          })
      }

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
            .margin({ left: 6 })
        }
      }
      .width('100%')
      .height(40)
      .backgroundColor(this.config.apiKey ? '#999999' : '#CCCCCC')
      .borderRadius(8)
      .enabled(this.config.apiKey.length > 0 && !this.testingConnection)
      .onClick(() => {
        this.testConnection()
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
  ModelStep() {
    Column() {
      Text('选择模型')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .width('100%')
        .padding({ bottom: 16 })

      const provider = getProvider(this.config.providerId)

      if (this.config.providerId === CUSTOM_PROVIDER_ID) {
        TextInput({ text: this.customModelInput, placeholder: '输入模型名称' })
          .fontSize(15)
          .width('100%')
          .height(48)
          .backgroundColor('#F5F5F5')
          .borderRadius(10)
          .padding(12)
          .onChange((value: string) => {
            this.customModelInput = value
            this.config.customModel = value
          })
      } else if (provider && provider.defaultModels.length > 0) {
        ForEach(provider.defaultModels, (modelName: string) => {
          Row() {
            Text(modelName)
              .fontSize(15)
              .layoutWeight(1)
            Radio({ value: modelName, group: 'model' })
              .checked(modelName === this.config.selectedModel)
              .onClick(() => {
                this.config.selectedModel = modelName
              })
          }
          .width('100%')
          .padding(14)
          .margin({ bottom: 6 })
          .borderRadius(10)
          .backgroundColor(this.config.selectedModel === modelName ? '#E8F0FE' : '#F5F5F5')
          .onClick(() => {
            this.config.selectedModel = modelName
          })
        })
      }

      // 高级参数
      Text('高级参数（可选）')
        .fontSize(13)
        .fontColor('#999999')
        .width('100%')
        .padding({ top: 16, bottom: 8 })

      Row() {
        Text('Temperature')
          .fontSize(13)
          .width(100)
        Slider({
          value: this.config.temperature,
          min: 0,
          max: 2,
          step: 0.1
        })
        .layoutWeight(1)
        .onChange((value: number) => {
          this.config.temperature = value
        })
        Text(this.config.temperature.toFixed(1))
          .fontSize(13)
          .width(30)
          .textAlign(TextAlign.Center)
      }
      .width('100%')
      .padding({ top: 4, bottom: 4 })
    }
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
          .backgroundColor('#F0F0F0')
          .fontColor('#333333')
          .borderRadius(10)
          .margin({ right: 8 })
          .onClick(() => {
            this.currentStep--
          })
      }

      // 下一步/完成
      Button(this.currentStep < 2 ? '下一步' : '完成配置')
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .height(44)
        .layoutWeight(1)
        .backgroundColor('#4A90D9')
        .fontColor(Color.White)
        .borderRadius(10)
        .margin({ left: this.currentStep > 0 ? 0 : 0 })
        .onClick(() => {
          this.handleNext()
        })
    }
    .width('100%')
    .padding({ bottom: 40 })
  }

  /**
   * 处理下一步/完成
   */
  private async handleNext(): Promise<void> {
    if (this.currentStep < 2) {
      // 验证当前步骤
      if (this.currentStep === 1 && !this.config.apiKey) {
        this.testResult = '请输入 API Key'
        return
      }
      this.currentStep++
    } else {
      // 保存并跳转
      this.config.isConfigured = true
      await storageService.init(getContext(this))
      await storageService.saveApiConfig(this.config)
      await storageService.setHasLaunched(true)

      router.replaceUrl({
        url: ROUTES.MAIN
      })
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
      // 测试成功后可以自动跳到下一步
      // this.currentStep++
    }
  }
}
