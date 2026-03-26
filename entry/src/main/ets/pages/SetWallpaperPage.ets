// =============================================================================
// SetWallpaperPage.ets — Set image as device wallpaper (T-034)
// FR-048: Preview image before setting as wallpaper
// FR-049: Set image as home screen wallpaper
// FR-050: Set image as lock screen wallpaper
// FR-051: Set image as both home and lock screen wallpaper
// =============================================================================

import { router } from '@kit.ArkUI'
import { wallpaper, BusinessError } from '@kit.BasicServicesKit'
import { image } from '@kit.ImageKit'
import { fileIo } from '@kit.CoreFileKit'

// Wallpaper target constants
const TARGET_HOME: number = 0
const TARGET_LOCK: number = 1
const TARGET_BOTH: number = 2

// Layout constants
const TITLE_BAR_HEIGHT: number = 56
const BACK_ICON_SIZE: number = 24
const TITLE_FONT_SIZE: number = 20
const LABEL_FONT_SIZE: number = 16
const RADIO_LABEL_MARGIN: number = 8
const RADIO_ROW_MARGIN: number = 8
const SELECTOR_PADDING: number = 16
const BUTTON_WIDTH: string = '80%'
const BUTTON_BOTTOM_MARGIN: number = 32
const TITLE_BAR_PADDING_H: number = 16
const TITLE_LEFT_MARGIN: number = 16

interface WallpaperParams {
  imagePath: string
}

@Entry
@Component
struct SetWallpaperPage {
  @State imagePath: string = ''
  @State isSetting: boolean = false
  @State selectedTarget: number = TARGET_HOME
  // BUG-030: Use PixelMap for preview instead of direct URI
  // Image(photoAccessHelper URI) may show wrong content on some devices
  @State previewPixelMap: image.PixelMap | undefined = undefined

  aboutToAppear(): void {
    const params: WallpaperParams = router.getParams() as WallpaperParams
    if (params !== null && params !== undefined) {
      this.imagePath = params.imagePath
    }
    this.loadPreview()
  }

  private loadPreview(): void {
    if (this.imagePath.length === 0) {
      return
    }
    try {
      const file: fileIo.File = fileIo.openSync(this.imagePath, fileIo.OpenMode.READ_ONLY)
      const imageSource: image.ImageSource = image.createImageSource(file.fd)
      imageSource.createPixelMap().then((pixelMap: image.PixelMap): void => {
        this.previewPixelMap = pixelMap
        imageSource.release()
        fileIo.closeSync(file)
      }).catch((): void => {
        imageSource.release()
        fileIo.closeSync(file)
      })
    } catch (e) {
      console.error('[Wallpaper] loadPreview failed: ' + (e as Error).message)
    }
  }

  build() {
    Column() {
      // Title bar
      Row() {
        Image($r('sys.media.ohos_ic_back'))
          .width(BACK_ICON_SIZE)
          .height(BACK_ICON_SIZE)
          .onClick(() => {
            router.back()
          })
        Text($r('app.string.set_wallpaper_title'))
          .fontSize(TITLE_FONT_SIZE)
          .fontWeight(FontWeight.Bold)
          .margin({ left: TITLE_LEFT_MARGIN })
          .layoutWeight(1)
      }
      .width('100%')
      .height(TITLE_BAR_HEIGHT)
      .padding({ left: TITLE_BAR_PADDING_H, right: TITLE_BAR_PADDING_H })

      // Image preview — BUG-030: use PixelMap for reliable preview
      if (this.previewPixelMap !== undefined) {
        Image(this.previewPixelMap)
          .objectFit(ImageFit.Contain)
          .width('100%')
          .layoutWeight(1)
      } else {
        Column() {
          LoadingProgress().width(48).height(48)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      }

      // Target selector
      Column() {
        Row() {
          Radio({ value: 'home', group: 'target' })
            .checked(this.selectedTarget === TARGET_HOME)
            .onChange((isChecked: boolean) => {
              if (isChecked) {
                this.selectedTarget = TARGET_HOME
              }
            })
          Text($r('app.string.home_screen'))
            .fontSize(LABEL_FONT_SIZE)
            .margin({ left: RADIO_LABEL_MARGIN })
        }
        .margin({ bottom: RADIO_ROW_MARGIN })

        Row() {
          Radio({ value: 'lock', group: 'target' })
            .checked(this.selectedTarget === TARGET_LOCK)
            .onChange((isChecked: boolean) => {
              if (isChecked) {
                this.selectedTarget = TARGET_LOCK
              }
            })
          Text($r('app.string.lock_screen'))
            .fontSize(LABEL_FONT_SIZE)
            .margin({ left: RADIO_LABEL_MARGIN })
        }
        .margin({ bottom: RADIO_ROW_MARGIN })

        Row() {
          Radio({ value: 'both', group: 'target' })
            .checked(this.selectedTarget === TARGET_BOTH)
            .onChange((isChecked: boolean) => {
              if (isChecked) {
                this.selectedTarget = TARGET_BOTH
              }
            })
          Text($r('app.string.both_screens'))
            .fontSize(LABEL_FONT_SIZE)
            .margin({ left: RADIO_LABEL_MARGIN })
        }
      }
      .padding(SELECTOR_PADDING)

      // Set button
      Button(this.isSetting ? $r('app.string.setting_wallpaper') : $r('app.string.set_as_wallpaper'))
        .width(BUTTON_WIDTH)
        .margin({ bottom: BUTTON_BOTTOM_MARGIN })
        .enabled(!this.isSetting)
        .onClick(() => {
          this.setWallpaper()
        })
    }
    .width('100%')
    .height('100%')
  }

  async setWallpaper(): Promise<void> {
    this.isSetting = true
    let file: fileIo.File | null = null
    try {
      // URI must be opened via fileIo to get fd (PIT-053: photoAccessHelper URI not a file path)
      console.info('[Wallpaper] imagePath: ' + this.imagePath)
      file = fileIo.openSync(this.imagePath, fileIo.OpenMode.READ_ONLY)
      console.info('[Wallpaper] fd: ' + file.fd.toString())

      const imageSource: image.ImageSource = image.createImageSource(file.fd)
      const pixelMap: image.PixelMap = await imageSource.createPixelMap()
      const imageInfo: image.ImageInfo = await pixelMap.getImageInfo()
      console.info('[Wallpaper] PixelMap size: ' + imageInfo.size.width.toString() + 'x' + imageInfo.size.height.toString())

      if (this.selectedTarget === TARGET_HOME || this.selectedTarget === TARGET_BOTH) {
        console.info('[Wallpaper] Setting SYSTEM wallpaper...')
        await wallpaper.setWallpaper(pixelMap, wallpaper.WallpaperType.WALLPAPER_SYSTEM)
        console.info('[Wallpaper] SYSTEM wallpaper set OK')
      }
      if (this.selectedTarget === TARGET_LOCK || this.selectedTarget === TARGET_BOTH) {
        console.info('[Wallpaper] Setting LOCKSCREEN wallpaper...')
        await wallpaper.setWallpaper(pixelMap, wallpaper.WallpaperType.WALLPAPER_LOCKSCREEN)
        console.info('[Wallpaper] LOCKSCREEN wallpaper set OK')
      }

      pixelMap.release()
      imageSource.release()

      this.getUIContext()?.getPromptAction()?.showToast({ message: $r('app.string.wallpaper_set_successfully') })
      router.back()
    } catch (e) {
      const errMsg: string = (e as BusinessError).message || 'unknown'
      const errCode: string = (e as BusinessError).code !== undefined ? (e as BusinessError).code.toString() : 'N/A'
      console.error('[Wallpaper] FAILED code=' + errCode + ' msg=' + errMsg)
      this.getUIContext()?.getPromptAction()?.showToast({ message: $r('app.string.failed_to_set_wallpaper') })
    } finally {
      if (file !== null) {
        fileIo.closeSync(file)
      }
    }
    this.isSetting = false
  }
}
