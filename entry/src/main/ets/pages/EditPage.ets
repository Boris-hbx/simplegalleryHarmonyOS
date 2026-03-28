// =============================================================================
// EditPage.ets — Image editor page with crop, rotate, and flip (T-029)
// FR-029: Crop with free and preset aspect ratios
// FR-030: 90-degree rotation and horizontal/vertical flip
// FR-032: Save edited image to file
// =============================================================================

import { router } from '@kit.ArkUI'
import { image } from '@kit.ImageKit'
import { fileIo as fs } from '@kit.CoreFileKit'
import { common } from '@kit.AbilityKit'
import { CropOverlay, CropRect } from '../components/CropOverlay'
import { DrawCanvas } from '../components/DrawCanvas'
import { PaintOptions } from '../common/models/PaintOptions'
import { ConfigManager } from '../datastore/ConfigManager'
import {
  ASPECT_RATIO_FREE,
  ASPECT_RATIO_ONE_ONE,
  ASPECT_RATIO_FOUR_THREE,
  ASPECT_RATIO_SIXTEEN_NINE,
  ASPECT_RATIO_OTHER
} from '../common/constants/Constants'

// Edit mode tab identifiers
const MODE_CROP: string = 'crop'
const MODE_ROTATE: string = 'rotate'
const MODE_DRAW: string = 'draw'

// Toolbar icon size
const ICON_SIZE: number = 28
// Toolbar bar height
const TOOLBAR_HEIGHT: number = 56
// Control row height
const CONTROL_ROW_HEIGHT: number = 48
// Button font size
const BUTTON_FONT_SIZE: number = 13
// Title bar font size
const TITLE_FONT_SIZE: number = 16
// Brush size limits
const BRUSH_SIZE_MIN: number = 1
const BRUSH_SIZE_MAX: number = 50
// Color swatch size
const COLOR_SWATCH_SIZE: number = 28
// Draw control row height (taller to fit slider)
const DRAW_CONTROL_HEIGHT: number = 96
// Preset draw colors: black, red, green, blue, yellow, white
const PRESET_COLOR_BLACK: number = 0xFF000000
const PRESET_COLOR_RED: number = 0xFFFF0000
const PRESET_COLOR_GREEN: number = 0xFF00AA00
const PRESET_COLOR_BLUE: number = 0xFF0055FF
const PRESET_COLOR_YELLOW: number = 0xFFFFCC00
const PRESET_COLOR_WHITE: number = 0xFFFFFFFF

@Entry
@Component
struct EditPage {
  @State imagePath: string = ''
  @State currentMode: string = MODE_CROP
  @State rotation: number = 0
  @State flipH: boolean = false
  @State flipV: boolean = false
  @State cropRect: CropRect = new CropRect()
  @State aspectRatioType: number = ASPECT_RATIO_FREE
  @State imageWidth: number = 0
  @State imageHeight: number = 0
  @State isSaving: boolean = false
  @State customRatioX: number = 2
  @State customRatioY: number = 1

  // Custom ratio dialog state
  @State showCustomDialog: boolean = false
  @State dialogRatioX: string = '2'
  @State dialogRatioY: string = '1'

  // Draw mode state
  @State drawColor: number = PRESET_COLOR_BLACK
  @State brushSize: number = 5
  @State paintOptions: PaintOptions = new PaintOptions()

  private drawCanvasRef: DrawCanvas | null = null
  private configManager: ConfigManager = ConfigManager.getInstance()

  aboutToAppear(): void {
    const params: Record<string, Object> = router.getParams() as Record<string, Object>
    if (params !== null && params !== undefined) {
      this.imagePath = (params['path'] as string) || ''
    }

    // Restore last aspect ratio from preferences
    this.aspectRatioType = this.configManager.lastEditorCropAspectRatio
    this.customRatioX = this.configManager.lastEditorCropOtherAspectRatioX
    this.customRatioY = this.configManager.lastEditorCropOtherAspectRatioY
    this.dialogRatioX = this.customRatioX.toString()
    this.dialogRatioY = this.customRatioY.toString()

    // Restore last draw color and brush size from preferences
    this.drawColor = this.configManager.lastEditorDrawColor
    this.brushSize = Math.max(BRUSH_SIZE_MIN,
      Math.min(BRUSH_SIZE_MAX, Math.round(this.configManager.editorBrushSize * 100)))
    this.paintOptions = new PaintOptions(this.drawColor, this.brushSize)

    this.loadImageDimensions()
  }

  build() {
    Column() {
      // Top bar: Back + Save
      Row() {
        Image($r('sys.media.ohos_ic_public_arrow_left'))
          .width(ICON_SIZE)
          .height(ICON_SIZE)
          .onClick(() => {
            router.back()
          })

        Blank()

        Button($r('app.string.save'))
          .fontSize(BUTTON_FONT_SIZE)
          .enabled(!this.isSaving)
          .onClick(() => {
            this.saveImage()
          })
      }
      .width('100%')
      .height(TOOLBAR_HEIGHT)
      .padding({ left: 16, right: 16 })
      .alignItems(VerticalAlign.Center)

      // Image area with overlays
      Stack() {
        Image(this.imagePath)
          .objectFit(ImageFit.Contain)
          .rotate({ angle: this.rotation })
          .scale({ x: this.flipH ? -1 : 1, y: this.flipV ? -1 : 1 })
          .width('100%')
          .height('100%')

        if (this.currentMode === MODE_CROP) {
          CropOverlay({
            cropRect: this.cropRect,
            cropRatio: this.aspectRatioType,
            customRatioX: this.customRatioX,
            customRatioY: this.customRatioY
          })
        }

        if (this.currentMode === MODE_DRAW) {
          DrawCanvas({
            paintOptions: this.paintOptions
          })
        }
      }
      .layoutWeight(1)
      .width('100%')

      // Mode-specific controls
      if (this.currentMode === MODE_CROP) {
        this.cropControls()
      } else if (this.currentMode === MODE_ROTATE) {
        this.rotateControls()
      } else {
        // Draw mode controls
        this.drawControls()
      }

      // Bottom tab bar: Crop | Rotate | Draw
      Row() {
        this.modeTab(MODE_CROP, $r('app.string.crop'))
        this.modeTab(MODE_ROTATE, $r('app.string.rotate'))
        this.modeTab(MODE_DRAW, $r('app.string.draw'))
      }
      .width('100%')
      .height(TOOLBAR_HEIGHT)
      .justifyContent(FlexAlign.SpaceAround)
      .alignItems(VerticalAlign.Center)

      // Custom aspect ratio dialog
      if (this.showCustomDialog) {
        this.customRatioDialog()
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  modeTab(mode: string, label: string | Resource) {
    Column() {
      Text(label)
        .fontSize(TITLE_FONT_SIZE)
        .fontWeight(this.currentMode === mode ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.currentMode === mode ? $r('sys.color.ohos_id_color_primary') : Color.Gray)
    }
    .onClick(() => {
      this.currentMode = mode
    })
    .padding(8)
  }

  @Builder
  cropControls() {
    Row() {
      this.ratioButton($r('app.string.free_aspect_ratio'), ASPECT_RATIO_FREE)
      this.ratioButton('1:1', ASPECT_RATIO_ONE_ONE)
      this.ratioButton('4:3', ASPECT_RATIO_FOUR_THREE)
      this.ratioButton('16:9', ASPECT_RATIO_SIXTEEN_NINE)
      this.ratioButton($r('app.string.other_aspect_ratio'), ASPECT_RATIO_OTHER)
    }
    .width('100%')
    .height(CONTROL_ROW_HEIGHT)
    .justifyContent(FlexAlign.SpaceAround)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  ratioButton(label: string | Resource, ratio: number) {
    Text(label)
      .fontSize(BUTTON_FONT_SIZE)
      .fontWeight(this.aspectRatioType === ratio ? FontWeight.Bold : FontWeight.Normal)
      .fontColor(this.aspectRatioType === ratio ? $r('sys.color.ohos_id_color_primary') : Color.Gray)
      .padding(8)
      .onClick(() => {
        if (ratio === ASPECT_RATIO_OTHER) {
          this.showCustomDialog = true
        } else {
          this.aspectRatioType = ratio
          this.configManager.lastEditorCropAspectRatio = ratio
        }
      })
  }

  @Builder
  rotateControls() {
    Row() {
      Button($r('app.string.rotate_left'))
        .fontSize(BUTTON_FONT_SIZE)
        .onClick(() => {
          this.rotation = (this.rotation - 90 + 360) % 360
        })

      Button($r('app.string.rotate_right'))
        .fontSize(BUTTON_FONT_SIZE)
        .onClick(() => {
          this.rotation = (this.rotation + 90) % 360
        })

      Button($r('app.string.flip_h'))
        .fontSize(BUTTON_FONT_SIZE)
        .onClick(() => {
          this.flipH = !this.flipH
        })

      Button($r('app.string.flip_v'))
        .fontSize(BUTTON_FONT_SIZE)
        .onClick(() => {
          this.flipV = !this.flipV
        })
    }
    .width('100%')
    .height(CONTROL_ROW_HEIGHT)
    .justifyContent(FlexAlign.SpaceAround)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  customRatioDialog() {
    Column() {
      // Backdrop
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#80000000')
        .position({ x: 0, y: 0 })
        .onClick(() => {
          this.showCustomDialog = false
        })

      // Dialog card
      Column() {
        Text($r('app.string.custom_aspect_ratio'))
          .fontSize(TITLE_FONT_SIZE)
          .fontWeight(FontWeight.Bold)
          .margin({ bottom: 16 })

        Row() {
          Text($r('app.string.width_label'))
            .fontSize(BUTTON_FONT_SIZE)
          TextInput({ text: this.dialogRatioX })
            .type(InputType.Number)
            .width(60)
            .onChange((value: string) => {
              this.dialogRatioX = value
            })
        }
        .margin({ bottom: 8 })

        Row() {
          Text($r('app.string.height_label'))
            .fontSize(BUTTON_FONT_SIZE)
          TextInput({ text: this.dialogRatioY })
            .type(InputType.Number)
            .width(60)
            .onChange((value: string) => {
              this.dialogRatioY = value
            })
        }
        .margin({ bottom: 16 })

        Row() {
          Button($r('app.string.cancel'))
            .fontSize(BUTTON_FONT_SIZE)
            .onClick(() => {
              this.showCustomDialog = false
            })

          Blank().width(16)

          Button($r('app.string.apply'))
            .fontSize(BUTTON_FONT_SIZE)
            .onClick(() => {
              const rx: number = Number.parseFloat(this.dialogRatioX)
              const ry: number = Number.parseFloat(this.dialogRatioY)
              if (rx > 0 && ry > 0) {
                this.customRatioX = rx
                this.customRatioY = ry
                this.aspectRatioType = ASPECT_RATIO_OTHER
                this.configManager.lastEditorCropAspectRatio = ASPECT_RATIO_OTHER
                this.configManager.lastEditorCropOtherAspectRatioX = rx
                this.configManager.lastEditorCropOtherAspectRatioY = ry
              }
              this.showCustomDialog = false
            })
        }
      }
      .width(280)
      .padding(24)
      .borderRadius(12)
      .backgroundColor($r('sys.color.ohos_id_color_background'))
      .position({ x: '50%', y: '50%' })
      .translate({ x: -140, y: -100 })
    }
    .width('100%')
    .height('100%')
    .position({ x: 0, y: 0 })
  }

  @Builder
  drawControls() {
    Column() {
      // Color presets row
      Row() {
        this.colorSwatch(PRESET_COLOR_BLACK)
        this.colorSwatch(PRESET_COLOR_RED)
        this.colorSwatch(PRESET_COLOR_GREEN)
        this.colorSwatch(PRESET_COLOR_BLUE)
        this.colorSwatch(PRESET_COLOR_YELLOW)
        this.colorSwatch(PRESET_COLOR_WHITE)

        Blank().width(16)

        // Undo button
        Button($r('app.string.undo_action'))
          .fontSize(BUTTON_FONT_SIZE)
          .onClick(() => {
            if (this.drawCanvasRef !== null) {
              this.drawCanvasRef.undoLast()
            }
          })

        // Clear button
        Button($r('app.string.clear'))
          .fontSize(BUTTON_FONT_SIZE)
          .onClick(() => {
            if (this.drawCanvasRef !== null) {
              this.drawCanvasRef.clearAll()
            }
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .padding({ left: 8, right: 8 })

      // Brush size slider row
      Row() {
        Text($r('app.string.size_label'))
          .fontSize(BUTTON_FONT_SIZE)
          .margin({ right: 8 })

        Slider({
          value: this.brushSize,
          min: BRUSH_SIZE_MIN,
          max: BRUSH_SIZE_MAX,
          step: 1
        })
          .layoutWeight(1)
          .onChange((value: number) => {
            this.brushSize = Math.round(value)
            this.updatePaintOptions()
          })

        Text(this.brushSize.toString())
          .fontSize(BUTTON_FONT_SIZE)
          .width(30)
          .textAlign(TextAlign.Center)
      }
      .width('100%')
      .padding({ left: 16, right: 16 })
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height(DRAW_CONTROL_HEIGHT)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  colorSwatch(color: number) {
    Column()
      .width(COLOR_SWATCH_SIZE)
      .height(COLOR_SWATCH_SIZE)
      .borderRadius(COLOR_SWATCH_SIZE / 2)
      .backgroundColor(this.colorNumberToResourceStr(color))
      .border({
        width: this.drawColor === color ? 3 : 1,
        color: this.drawColor === color ? $r('sys.color.ohos_id_color_primary') : $r('sys.color.ohos_id_color_text_secondary')
      })
      .margin(4)
      .onClick(() => {
        this.drawColor = color
        this.updatePaintOptions()
        this.configManager.lastEditorDrawColor = color
      })
  }

  private updatePaintOptions(): void {
    this.paintOptions = new PaintOptions(this.drawColor, this.brushSize)
    this.configManager.editorBrushSize = this.brushSize / 100.0
  }

  private colorNumberToResourceStr(color: number): string {
    const r: number = (color >> 16) & 0xFF
    const g: number = (color >> 8) & 0xFF
    const b: number = color & 0xFF
    const rStr: string = r.toString(16).padStart(2, '0')
    const gStr: string = g.toString(16).padStart(2, '0')
    const bStr: string = b.toString(16).padStart(2, '0')
    return '#' + rStr + gStr + bStr
  }

  private async loadImageDimensions(): Promise<void> {
    try {
      const source: image.ImageSource = image.createImageSource(this.imagePath)
      const info: image.ImageInfo = await source.getImageInfo()
      this.imageWidth = info.size.width
      this.imageHeight = info.size.height
      source.release()
    } catch (e) {
      console.error('EditPage: failed to load image dimensions')
    }
  }

  private async saveImage(): Promise<void> {
    if (this.isSaving) {
      return
    }
    this.isSaving = true

    try {
      // 1. Open source image and create pixel map
      const source: image.ImageSource = image.createImageSource(this.imagePath)
      const pixelMap: image.PixelMap = await source.createPixelMap()

      // 2. Apply rotation
      if (this.rotation !== 0) {
        await pixelMap.rotate(this.rotation)
      }

      // 3. Apply flip
      if (this.flipH || this.flipV) {
        await pixelMap.flip(this.flipH, this.flipV)
      }

      // 4. Apply crop (convert normalized rect to pixel coords)
      if (this.cropRect.isActive) {
        const imgInfo: image.ImageInfo = await pixelMap.getImageInfo()
        const regionX: number = Math.round(this.cropRect.x * imgInfo.size.width)
        const regionY: number = Math.round(this.cropRect.y * imgInfo.size.height)
        const regionW: number = Math.round(this.cropRect.w * imgInfo.size.width)
        const regionH: number = Math.round(this.cropRect.h * imgInfo.size.height)
        const region: image.Region = {
          x: regionX,
          y: regionY,
          size: {
            width: Math.max(1, regionW),
            height: Math.max(1, regionH)
          }
        }
        await pixelMap.crop(region)
      }

      // 5. Composite drawing overlay if present
      if (this.drawCanvasRef !== null && this.drawCanvasRef.hasDrawing()) {
        const finalInfo: image.ImageInfo = await pixelMap.getImageInfo()
        const drawPixelMap: image.PixelMap =
          await this.drawCanvasRef.getDrawnPixelMap(finalInfo.size.width, finalInfo.size.height)
        // Read drawing pixels
        const drawBuf: ArrayBuffer = new ArrayBuffer(finalInfo.size.width * finalInfo.size.height * 4)
        await drawPixelMap.readPixelsToBuffer(drawBuf)
        // Read base image pixels
        const baseBuf: ArrayBuffer = new ArrayBuffer(finalInfo.size.width * finalInfo.size.height * 4)
        await pixelMap.readPixelsToBuffer(baseBuf)
        // Alpha-blend drawing onto base
        const baseView: Uint8Array = new Uint8Array(baseBuf)
        const drawView: Uint8Array = new Uint8Array(drawBuf)
        for (let px: number = 0; px < baseView.length; px += 4) {
          const da: number = drawView[px + 3]
          if (da === 0) {
            continue
          }
          if (da === 255) {
            baseView[px] = drawView[px]
            baseView[px + 1] = drawView[px + 1]
            baseView[px + 2] = drawView[px + 2]
            baseView[px + 3] = 255
          } else {
            const alpha: number = da / 255.0
            const invAlpha: number = 1.0 - alpha
            baseView[px] = Math.round(drawView[px] * alpha + baseView[px] * invAlpha)
            baseView[px + 1] = Math.round(drawView[px + 1] * alpha + baseView[px + 1] * invAlpha)
            baseView[px + 2] = Math.round(drawView[px + 2] * alpha + baseView[px + 2] * invAlpha)
            baseView[px + 3] = Math.min(255, baseView[px + 3] + da)
          }
        }
        await pixelMap.writeBufferToPixels(baseBuf)
        drawPixelMap.release()
      }

      // 6. Pack and save to sandbox (PIT-056: cannot write back to media URI directly)
      const packer: image.ImagePacker = image.createImagePacker()
      const packOpts: image.PackingOption = {
        format: 'image/jpeg',
        quality: 95
      }
      const data: ArrayBuffer = await packer.packToData(pixelMap, packOpts)

      const ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext
      const fileName: string = 'edited_' + Date.now().toString() + '.jpg'
      const savePath: string = ctx.filesDir + '/' + fileName
      const file: fs.File = fs.openSync(savePath,
        fs.OpenMode.WRITE_ONLY | fs.OpenMode.CREATE | fs.OpenMode.TRUNC)
      fs.writeSync(file.fd, data)
      fs.closeSync(file.fd)

      pixelMap.release()
      source.release()
      packer.release()

      this.getUIContext()?.getPromptAction()?.showToast({
        message: $r('app.string.file_saved')
      })
      router.back()
    } catch (e) {
      console.error('EditPage: save failed: ' + (e as Error).message)
      this.getUIContext()?.getPromptAction()?.showToast({
        message: $r('app.string.saving_failed')
      })
    }

    this.isSaving = false
  }
}
