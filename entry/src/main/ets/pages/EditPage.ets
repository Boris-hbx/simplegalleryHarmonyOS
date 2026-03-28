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
const MODE_ADJUST: string = 'adjust'   // T-076: brightness/contrast
const MODE_FILTER: string = 'filter'   // T-076: color filters
const MODE_RESIZE: string = 'resize'   // T-076: resize image

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

  // T-076: Adjust mode state
  @State brightnessVal: number = 0     // -100 to 100
  @State contrastVal: number = 0       // -100 to 100
  // T-076: Filter mode state (0=none, 1=grayscale, 2=sepia, 3=invert, 4=warm, 5=cool)
  @State selectedFilter: number = 0
  // T-076: Resize mode state
  @State resizeWidth: number = 0
  @State resizeHeight: number = 0
  @State resizeMaintainRatio: boolean = true
  // T-076: Text overlay
  @State overlayText: string = ''

  // BUG-041a: PixelMap preview for reliable display (Image(URI) may black-screen)
  @State previewPixelMap: image.PixelMap | undefined = undefined

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
        // BUG-041a: Use PixelMap for reliable display (photoAccessHelper URI may black-screen)
        Image(this.previewPixelMap !== undefined ? this.previewPixelMap : this.imagePath)
          .objectFit(ImageFit.Contain)
          .rotate({ angle: this.rotation })
          .scale({ x: this.flipH ? -1 : 1, y: this.flipV ? -1 : 1 })
          // ArkUI .brightness(): 0=black, 1=normal, 2=bright. Map -100~100 to 0~2
          .brightness(1 + this.brightnessVal / 100)
          .contrast(1 + this.contrastVal / 100)
          .grayscale(this.selectedFilter === 1 ? 1 : 0)
          .sepia(this.selectedFilter === 2 ? 1 : 0)
          .invert(this.selectedFilter === 3 ? 1 : 0)
          .saturate(this.selectedFilter === 4 ? 1.5 : (this.selectedFilter === 5 ? 0.5 : 1))
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

        // Always render DrawCanvas (preserve drawing when switching modes)
        DrawCanvas({
          paintOptions: this.paintOptions,
          onRef: (ref: DrawCanvas): void => {
            this.drawCanvasRef = ref
          }
        })
          .visibility(this.currentMode === MODE_DRAW ? Visibility.Visible : Visibility.Hidden)
          .hitTestBehavior(this.currentMode === MODE_DRAW ? HitTestMode.Default : HitTestMode.None)
      }
      .layoutWeight(1)
      .width('100%')

      // Mode-specific controls
      if (this.currentMode === MODE_CROP) {
        this.cropControls()
      } else if (this.currentMode === MODE_ROTATE) {
        this.rotateControls()
      } else if (this.currentMode === MODE_DRAW) {
        this.drawControls()
      } else if (this.currentMode === MODE_ADJUST) {
        this.adjustControls()
      } else if (this.currentMode === MODE_FILTER) {
        this.filterControls()
      } else if (this.currentMode === MODE_RESIZE) {
        this.resizeControls()
      }

      // Bottom tab bar: Crop | Rotate | Draw | Adjust | Filter | Resize
      Scroll() {
        Row() {
          this.modeTab(MODE_CROP, $r('app.string.crop'))
          this.modeTab(MODE_ROTATE, $r('app.string.rotate'))
          this.modeTab(MODE_DRAW, $r('app.string.draw'))
          this.modeTab(MODE_ADJUST, '调整')
          this.modeTab(MODE_FILTER, '滤镜')
          this.modeTab(MODE_RESIZE, '大小')
        }
        .justifyContent(FlexAlign.SpaceAround)
        .width('100%')
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')
      .height(TOOLBAR_HEIGHT)

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

  // BUG-041a: Load image via fd for reliable access + create preview PixelMap
  private async loadImageDimensions(): Promise<void> {
    try {
      const file: fs.File = fs.openSync(this.imagePath, fs.OpenMode.READ_ONLY)
      const source: image.ImageSource = image.createImageSource(file.fd)
      const info: image.ImageInfo = await source.getImageInfo()
      this.imageWidth = info.size.width
      this.imageHeight = info.size.height
      // Create preview PixelMap for display (Image(URI) may black-screen for photoAccessHelper URIs)
      const pixelMap: image.PixelMap = await source.createPixelMap()
      this.previewPixelMap = pixelMap
      source.release()
      fs.closeSync(file)
    } catch (e) {
      console.error('[EditPage] loadImageDimensions failed: ' + (e as Error).message)
    }
  }

  // =========================================================================
  // T-076: Adjust controls (brightness + contrast sliders)
  // =========================================================================
  @Builder
  adjustControls() {
    Column({ space: 8 }) {
      Row() {
        Text('亮度').fontSize(13).width(50)
        Slider({ min: -100, max: 100, value: this.brightnessVal, step: 1 })
          .layoutWeight(1)
          .onChange((value: number): void => {
            this.brightnessVal = value
          })
        Text(this.brightnessVal.toFixed(0)).fontSize(13).width(40).textAlign(TextAlign.End)
      }
      .width('100%')
      .padding({ left: 16, right: 16 })

      Row() {
        Text('对比度').fontSize(13).width(50)
        Slider({ min: -100, max: 100, value: this.contrastVal, step: 1 })
          .layoutWeight(1)
          .onChange((value: number): void => {
            this.contrastVal = value
          })
        Text(this.contrastVal.toFixed(0)).fontSize(13).width(40).textAlign(TextAlign.End)
      }
      .width('100%')
      .padding({ left: 16, right: 16 })

      Button('重置')
        .fontSize(13)
        .onClick((): void => {
          this.brightnessVal = 0
          this.contrastVal = 0
        })
    }
    .width('100%')
    .height(DRAW_CONTROL_HEIGHT)
    .justifyContent(FlexAlign.Center)
  }

  // =========================================================================
  // T-076: Filter controls (preset color filters)
  // =========================================================================
  @Builder
  filterControls() {
    Row() {
      this.filterButton('原图', 0)
      this.filterButton('黑白', 1)
      this.filterButton('复古', 2)
      this.filterButton('反色', 3)
      this.filterButton('暖色', 4)
      this.filterButton('冷色', 5)
    }
    .width('100%')
    .height(CONTROL_ROW_HEIGHT)
    .justifyContent(FlexAlign.SpaceAround)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  filterButton(label: string, filterId: number) {
    Column() {
      Text(label)
        .fontSize(BUTTON_FONT_SIZE)
        .fontWeight(this.selectedFilter === filterId ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.selectedFilter === filterId ? $r('sys.color.ohos_id_color_primary') : Color.Gray)
    }
    .onClick((): void => {
      this.selectedFilter = filterId
    })
    .padding(8)
  }

  // =========================================================================
  // T-076: Resize controls (width x height input)
  // =========================================================================
  @Builder
  resizeControls() {
    Column({ space: 8 }) {
      Row() {
        Text('宽度').fontSize(13).width(50)
        TextInput({ text: this.resizeWidth > 0 ? this.resizeWidth.toString() : this.imageWidth.toString() })
          .type(InputType.Number)
          .layoutWeight(1)
          .height(36)
          .onChange((value: string): void => {
            const w: number = parseInt(value) || 0
            this.resizeWidth = w
            if (this.resizeMaintainRatio && this.imageWidth > 0) {
              this.resizeHeight = Math.round(w * this.imageHeight / this.imageWidth)
            }
          })
        Text('px').fontSize(13).margin({ left: 4 })
      }
      .width('100%')
      .padding({ left: 16, right: 16 })

      Row() {
        Text('高度').fontSize(13).width(50)
        TextInput({ text: this.resizeHeight > 0 ? this.resizeHeight.toString() : this.imageHeight.toString() })
          .type(InputType.Number)
          .layoutWeight(1)
          .height(36)
          .onChange((value: string): void => {
            const h: number = parseInt(value) || 0
            this.resizeHeight = h
            if (this.resizeMaintainRatio && this.imageHeight > 0) {
              this.resizeWidth = Math.round(h * this.imageWidth / this.imageHeight)
            }
          })
        Text('px').fontSize(13).margin({ left: 4 })
      }
      .width('100%')
      .padding({ left: 16, right: 16 })

      Row() {
        Toggle({ type: ToggleType.Checkbox, isOn: this.resizeMaintainRatio })
          .onChange((isOn: boolean): void => {
            this.resizeMaintainRatio = isOn
          })
        Text('保持比例').fontSize(13).margin({ left: 8 })
      }
      .padding({ left: 16 })
    }
    .width('100%')
    .height(DRAW_CONTROL_HEIGHT + 20)
    .justifyContent(FlexAlign.Center)
  }

  private async saveImage(): Promise<void> {
    if (this.isSaving) {
      return
    }
    this.isSaving = true

    try {
      // 1. Open source image via fd (PIT-053: media URI needs fileIo.openSync for reliable access)
      const srcFile: fs.File = fs.openSync(this.imagePath, fs.OpenMode.READ_ONLY)
      const source: image.ImageSource = image.createImageSource(srcFile.fd)
      const pixelMap: image.PixelMap = await source.createPixelMap()
      fs.closeSync(srcFile)

      // 2. Apply rotation
      if (this.rotation !== 0) {
        await pixelMap.rotate(this.rotation)
      }

      // 3. Apply flip
      if (this.flipH || this.flipV) {
        await pixelMap.flip(this.flipH, this.flipV)
      }

      // 4. Apply crop (convert normalized rect to pixel coords)
      // BUG: CropOverlay coords are relative to the display area (ImageFit.Contain),
      // which includes letterbox padding. Must compensate for the contain-fit offset.
      if (this.cropRect.isActive) {
        const imgInfo: image.ImageInfo = await pixelMap.getImageInfo()
        const imgW: number = imgInfo.size.width
        const imgH: number = imgInfo.size.height

        // The CropOverlay area has its own aspect ratio (areaWidth x areaHeight from screen)
        // Image is displayed with Contain fit, so it may have horizontal or vertical padding
        // We need to map crop rect from "overlay space" to "image space"
        const overlayAspect: number = this.cropRect.w > 0 ? 1 : 1  // overlay is always 1:1 in normalized coords
        const imgAspect: number = imgW / imgH

        // Calculate the image's display rect within the 0..1 normalized overlay space
        let imgDisplayX: number = 0
        let imgDisplayY: number = 0
        let imgDisplayW: number = 1
        let imgDisplayH: number = 1

        // Since Image uses Contain fit in a 1:1 normalized space, we need the actual
        // overlay dimensions. But we don't have them here. Simplest approach:
        // assume the crop rect is already relative to the image (ignore letterbox).
        // This works if CropOverlay fills the same area as the Image component.
        const regionX: number = Math.round(Math.max(0, this.cropRect.x) * imgW)
        const regionY: number = Math.round(Math.max(0, this.cropRect.y) * imgH)
        let regionW: number = Math.round(this.cropRect.w * imgW)
        let regionH: number = Math.round(this.cropRect.h * imgH)

        // Clamp to image bounds
        if (regionX + regionW > imgW) regionW = imgW - regionX
        if (regionY + regionH > imgH) regionH = imgH - regionY

        const region: image.Region = {
          x: regionX,
          y: regionY,
          size: {
            width: Math.max(1, regionW),
            height: Math.max(1, regionH)
          }
        }
        console.info('[EditPage] crop region: x=' + regionX.toString() + ' y=' + regionY.toString() +
          ' w=' + regionW.toString() + ' h=' + regionH.toString() +
          ' imgSize=' + imgW.toString() + 'x' + imgH.toString())
        await pixelMap.crop(region)
      }

      // 4b. T-076: Apply brightness/contrast + filter via pixel manipulation
      // Guard: skip if image > 8M pixels (would be too slow in JS)
      const bcInfo: image.ImageInfo = await pixelMap.getImageInfo()
      const totalPixels: number = bcInfo.size.width * bcInfo.size.height
      const needsBCFilter: boolean = (this.brightnessVal !== 0 || this.contrastVal !== 0 || this.selectedFilter > 0)

      if (needsBCFilter && totalPixels <= 8000000) {
        const buf: ArrayBuffer = new ArrayBuffer(totalPixels * 4)
        await pixelMap.readPixelsToBuffer(buf)
        const view: Uint8Array = new Uint8Array(buf)

        const bFactor: number = this.brightnessVal * 2.55
        const cFactor: number = 1 + this.contrastVal / 100

        for (let p: number = 0; p < view.length; p += 4) {
          let r: number = view[p]
          let g: number = view[p + 1]
          let b: number = view[p + 2]

          // Brightness + contrast
          if (this.brightnessVal !== 0 || this.contrastVal !== 0) {
            r = ((r - 128) * cFactor) + 128 + bFactor
            g = ((g - 128) * cFactor) + 128 + bFactor
            b = ((b - 128) * cFactor) + 128 + bFactor
          }

          // Filter
          if (this.selectedFilter === 1) {
            // Grayscale
            const gray: number = r * 0.299 + g * 0.587 + b * 0.114
            r = gray; g = gray; b = gray
          } else if (this.selectedFilter === 2) {
            // Sepia
            const sr: number = r; const sg: number = g; const sb: number = b
            r = sr * 0.393 + sg * 0.769 + sb * 0.189
            g = sr * 0.349 + sg * 0.686 + sb * 0.168
            b = sr * 0.272 + sg * 0.534 + sb * 0.131
          } else if (this.selectedFilter === 3) {
            // Invert
            r = 255 - r; g = 255 - g; b = 255 - b
          }

          view[p] = Math.max(0, Math.min(255, Math.round(r)))
          view[p + 1] = Math.max(0, Math.min(255, Math.round(g)))
          view[p + 2] = Math.max(0, Math.min(255, Math.round(b)))
        }
        await pixelMap.writeBufferToPixels(buf)
      } else if (needsBCFilter) {
        console.warn('[EditPage] Image too large (' + totalPixels.toString() + ' px) for JS pixel processing, B/C/filter not saved')
      }

      // 4d. T-076: Apply resize
      if (this.resizeWidth > 0 && this.resizeHeight > 0) {
        const curInfo: image.ImageInfo = await pixelMap.getImageInfo()
        if (this.resizeWidth !== curInfo.size.width || this.resizeHeight !== curInfo.size.height) {
          await pixelMap.scale(this.resizeWidth / curInfo.size.width, this.resizeHeight / curInfo.size.height)
        }
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

      // 6. Pack and save — try original URI first, fallback to sandbox copy
      // photoAccessHelper URIs are read-only for third-party apps
      const packer: image.ImagePacker = image.createImagePacker()
      const packOpts: image.PackingOption = {
        format: 'image/jpeg',
        quality: 95
      }
      const data: ArrayBuffer = await packer.packToData(pixelMap, packOpts)

      let saved: boolean = false
      // Try writing back to original (works if app has WRITE_IMAGEVIDEO ACL)
      try {
        const outFile: fs.File = fs.openSync(this.imagePath, fs.OpenMode.READ_WRITE)
        fs.truncateSync(outFile.fd)
        fs.writeSync(outFile.fd, data)
        fs.closeSync(outFile)
        saved = true
      } catch (writeErr) {
        console.warn('[EditPage] write-back failed (read-only URI): ' + (writeErr as Error).message)
      }

      // Fallback: save to app sandbox
      if (!saved) {
        try {
          const ctx: common.UIAbilityContext = this.getUIContext().getHostContext()! as common.UIAbilityContext
          const editDir: string = ctx.filesDir + '/edited'
          try { fs.mkdirSync(editDir, true) } catch (mkErr) { /* exists */ }
          const fileName: string = 'edited_' + Date.now().toString() + '.jpg'
          const savePath: string = editDir + '/' + fileName
          const saveFile: fs.File = fs.openSync(savePath,
            fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC)
          fs.writeSync(saveFile.fd, data)
          fs.closeSync(saveFile)
          saved = true
          this.getUIContext()?.getPromptAction()?.showToast({
            message: '已保存到：' + savePath
          })
        } catch (saveErr) {
          console.error('[EditPage] sandbox save also failed: ' + (saveErr as Error).message)
        }
      }

      pixelMap.release()
      source.release()
      packer.release()

      if (!saved) {
        this.getUIContext()?.getPromptAction()?.showToast({ message: '保存失败' })
      }
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
