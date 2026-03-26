// =============================================================================
// AboutPage.ets — About page for Simple Gallery (HarmonyOS)
// T-060: Shows app info, developer, GitHub link, license, and version
// =============================================================================

import { router } from '@kit.ArkUI'
import { bundleManager, common, Want } from '@kit.AbilityKit'

@Entry
@Component
struct AboutPage {
  @State versionName: string = ''

  aboutToAppear(): void {
    try {
      const bundleInfo: bundleManager.BundleInfo =
        bundleManager.getBundleInfoForSelfSync(bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION)
      this.versionName = bundleInfo.versionName
    } catch (e) {
      this.versionName = '1.0.0'
    }
  }

  build() {
    Column() {
      // Top toolbar
      Row() {
        Button() {
          SymbolGlyph($r('sys.symbol.chevron_left'))
            .fontSize(24)
            .fontColor([$r('sys.color.ohos_id_color_text_primary')])
        }
        .backgroundColor($r('sys.color.ohos_id_color_background_transparent'))
        .width(40)
        .height(40)
        .onClick(() => {
          router.back()
        })

        Text($r('app.string.about'))
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
          .margin({ left: 8 })
          .layoutWeight(1)
      }
      .width('100%')
      .height(56)
      .padding({ left: 8, right: 16 })
      .alignItems(VerticalAlign.Center)

      Scroll() {
        Column() {
          // App info header
          Column({ space: 8 }) {
            Image($r('app.media.foreground'))
              .width(72)
              .height(72)
              .borderRadius(16)
            Text($r('app.string.app_name'))
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('sys.color.ohos_id_color_text_primary'))
            Text('v' + this.versionName)
              .fontSize(14)
              .fontColor($r('sys.color.ohos_id_color_text_secondary'))
          }
          .width('100%')
          .padding({ top: 24, bottom: 24 })
          .alignItems(HorizontalAlign.Center)

          Divider()
            .color($r('sys.color.ohos_id_color_list_separator'))
            .margin({ left: 16, right: 16 })

          // =================================================================
          // Developer & License info
          // =================================================================
          this.infoRow($r('app.string.developer'), $r('app.string.developer_name'))
          this.infoRow($r('app.string.version_label'), this.versionName)
          this.infoRow($r('app.string.license_label'), $r('app.string.license_value'))

          Divider()
            .color($r('sys.color.ohos_id_color_list_separator'))
            .margin({ left: 16, right: 16 })

          // =================================================================
          // Links
          // =================================================================
          this.sectionHeader($r('app.string.social_networks_section'))

          Row() {
            Text('GitHub')
              .fontSize(16)
              .fontColor($r('sys.color.ohos_id_color_text_primary'))
              .layoutWeight(1)
            SymbolGlyph($r('sys.symbol.chevron_right'))
              .fontSize(16)
              .fontColor([$r('sys.color.ohos_id_color_text_secondary')])
          }
          .width('100%')
          .height(56)
          .padding({ left: 16, right: 16 })
          .onClick(() => {
            this.openLink('https://github.com/SimpleMobileTools/Simple-Gallery')
          })

          // Bottom padding
          Row()
            .height(32)
            .width('100%')
        }
        .width('100%')
      }
      .layoutWeight(1)
      .scrollBar(BarState.Auto)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_background'))
  }

  @Builder
  sectionHeader(title: string | Resource) {
    Text(title)
      .fontSize(14)
      .fontWeight(FontWeight.Medium)
      .fontColor($r('sys.color.ohos_id_color_text_secondary'))
      .width('100%')
      .padding({ left: 16, top: 24, bottom: 8 })
  }

  @Builder
  infoRow(label: string | Resource, value: string | Resource) {
    Row() {
      Text(label)
        .fontSize(16)
        .fontColor($r('sys.color.ohos_id_color_text_secondary'))
        .width(100)
      Text(value)
        .fontSize(16)
        .fontColor($r('sys.color.ohos_id_color_text_primary'))
        .layoutWeight(1)
    }
    .width('100%')
    .height(56)
    .padding({ left: 16, right: 16 })
    .alignItems(VerticalAlign.Center)
  }

  private openLink(url: string): void {
    try {
      const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext
      const want: Want = {
        action: 'ohos.want.action.viewData',
        uri: url
      }
      context.startAbility(want)
    } catch (e) {
      this.getUIContext()?.getPromptAction()?.showToast({ message: url })
    }
  }
}
