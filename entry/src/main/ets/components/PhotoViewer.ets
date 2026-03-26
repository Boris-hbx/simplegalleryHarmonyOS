// =============================================================================
// PhotoViewer.ets — Full-screen image viewer with pinch-zoom, pan, double-tap,
// rotation, and EXIF orientation correction (T-022)
// =============================================================================

import { Medium } from '../common/models/Medium'
import { ConfigManager } from '../datastore/ConfigManager'
import { display } from '@kit.ArkUI'
import { image } from '@kit.ImageKit'

// EXIF orientation constants
const EXIF_ORIENTATION_NORMAL: string = '1'
const EXIF_ORIENTATION_ROTATE_180: string = '3'
const EXIF_ORIENTATION_ROTATE_90: string = '6'
const EXIF_ORIENTATION_ROTATE_270: string = '8'

const MIN_SCALE: number = 1.0
const MAX_SCALE: number = 10.0
const DEFAULT_DOUBLE_TAP_SCALE: number = 2.0
const ZOOM_ANIMATION_DURATION: number = 300

@Component
export struct PhotoViewer {
  @Prop medium: Medium = new Medium()
  onScaleChange: (scale: number) => void = (scale: number) => {}
  onSingleTap: () => void = () => {}

  @State private zoomScale: number = 1.0
  @State private offsetX: number = 0
  @State private offsetY: number = 0
  @State private currentRotationDegrees: number = 0
  @State private exifRotation: number = 0
  @State private isZoomed: boolean = false
  private lastScale: number = 1.0
  private lastOffsetX: number = 0
  private lastOffsetY: number = 0
  private imageWidth: number = 0
  private imageHeight: number = 0
  private containerWidth: number = 0
  private containerHeight: number = 0

  aboutToAppear(): void {
    this.loadExifOrientation()
  }

  build() {
    Stack() {
      Image(this.medium.path)
        .objectFit(ImageFit.Contain)
        .width('100%')
        .height('100%')
        .scale({ x: this.zoomScale, y: this.zoomScale })
        .translate({ x: this.offsetX, y: this.offsetY })
        .rotate({ angle: this.currentRotationDegrees + this.exifRotation })
        .onComplete((event: ImageCompleteEvent) => {
          this.imageWidth = event.width
          this.imageHeight = event.height
        })
        .draggable(false)
        .onClick(() => {
          this.onSingleTap()
        })

      // BUG-029 fix: Pan gesture overlay — only present when zoomed in.
      // At zoomScale <= 1.05, this overlay does not exist, so Swiper freely
      // handles horizontal swipes. When zoomed, it captures pan to drag the image.
      if (this.zoomScale > 1.05) {
        Column()
          .width('100%')
          .height('100%')
          .hitTestBehavior(HitTestMode.Transparent)
          .gesture(
            PanGesture()
              .onActionStart(() => {
                this.lastOffsetX = this.offsetX
                this.lastOffsetY = this.offsetY
              })
              .onActionUpdate((event: GestureEvent) => {
                const newOffsetX: number = this.lastOffsetX + event.offsetX
                const newOffsetY: number = this.lastOffsetY + event.offsetY
                this.offsetX = this.clampOffsetX(newOffsetX)
                this.offsetY = this.clampOffsetY(newOffsetY)
              })
              .onActionEnd(() => {
                this.lastOffsetX = this.offsetX
                this.lastOffsetY = this.offsetY
                this.clampOffset()
              })
          )
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Black)
    .clip(true)
    .onAreaChange((_oldArea: Area, newArea: Area) => {
      this.containerWidth = newArea.width as number
      this.containerHeight = newArea.height as number
    })
    // BUG-026: Use priorityGesture with GestureGroup(Parallel) for double-tap
    // and pinch-zoom so they take priority over parent Swiper gestures.
    // Parallel mode allows pinch and double-tap to coexist (they use different
    // finger counts so only one fires per interaction).
    .priorityGesture(
      GestureGroup(GestureMode.Parallel,
        // Double-tap: toggle between 1x and 2.5x zoom
        TapGesture({ count: 2 })
          .onAction(() => {
            if (!this.isZoomingAllowed()) {
              return
            }
            if (this.zoomScale > 1.1) {
              // Zoomed in -> reset to 1x
              this.zoomScale = 1.0
              this.offsetX = 0
              this.offsetY = 0
              this.lastScale = 1.0
              this.isZoomed = false
              this.onScaleChange(1.0)
            } else {
              // At 1x -> zoom to 2.5x
              this.zoomScale = 2.5
              this.lastScale = 2.5
              this.isZoomed = true
              this.onScaleChange(2.5)
            }
          }),
        // Pinch-zoom
        PinchGesture({ fingers: 2 })
          .onActionStart(() => {
            this.lastScale = this.zoomScale
          })
          .onActionUpdate((event: GestureEvent) => {
            if (!this.isZoomingAllowed()) {
              return
            }
            let newScale: number = this.lastScale * event.scale
            newScale = Math.max(MIN_SCALE, Math.min(MAX_SCALE, newScale))
            this.zoomScale = newScale
            this.isZoomed = newScale > MIN_SCALE
            this.onScaleChange(newScale)
            if (newScale <= MIN_SCALE) {
              this.offsetX = 0
              this.offsetY = 0
            }
          })
          .onActionEnd(() => {
            this.lastScale = this.zoomScale
            if (this.zoomScale <= MIN_SCALE) {
              this.resetZoom()
            } else {
              this.clampOffset()
            }
          })
      )
    )
    // BUG-029 fix: Removed parallelGesture(PanGesture()) — even with an empty
    // handler at zoomScale=1.0, the gesture recognition competes with Swiper's
    // internal swipe handling, blocking left/right navigation. Pan is now handled
    // by a conditional overlay that only exists when zoomed in (see Stack body).
  }

  // ---------------------------------------------------------------------------
  // Zoom helpers
  // ---------------------------------------------------------------------------

  resetZoom(): void {
    this.zoomScale = MIN_SCALE
    this.offsetX = 0
    this.offsetY = 0
    this.lastScale = MIN_SCALE
    this.lastOffsetX = 0
    this.lastOffsetY = 0
    this.isZoomed = false
    this.onScaleChange(MIN_SCALE)
  }

  private isZoomingAllowed(): boolean {
    try {
      const config: ConfigManager = ConfigManager.getInstance()
      return config.allowZoomingImages
    } catch (e) {
      return true
    }
  }

  private getDoubleTapZoomScale(): number {
    if (this.imageWidth <= 0 || this.imageHeight <= 0) {
      return DEFAULT_DOUBLE_TAP_SCALE
    }

    try {
      const displayInfo: display.Display = display.getDefaultDisplaySync()
      const screenW: number = displayInfo.width
      const screenH: number = displayInfo.height

      if (screenW <= 0 || screenH <= 0) {
        return DEFAULT_DOUBLE_TAP_SCALE
      }

      const screenRatio: number = screenW / screenH
      const imgRatio: number = this.imageWidth / this.imageHeight

      if (Math.abs(screenRatio - imgRatio) < 0.01) {
        return DEFAULT_DOUBLE_TAP_SCALE
      }

      // Portrait mode
      if (screenH > screenW) {
        if (imgRatio > screenRatio) {
          return screenH / (this.imageWidth / imgRatio)
        } else {
          return screenW / this.imageWidth
        }
      }

      // Landscape mode
      if (imgRatio > screenRatio) {
        return screenW / this.imageWidth
      } else {
        return screenH / this.imageHeight
      }
    } catch (e) {
      return DEFAULT_DOUBLE_TAP_SCALE
    }
  }

  // ---------------------------------------------------------------------------
  // Pan boundary clamping
  // ---------------------------------------------------------------------------

  private clampOffset(): void {
    this.offsetX = this.clampOffsetX(this.offsetX)
    this.offsetY = this.clampOffsetY(this.offsetY)
    this.lastOffsetX = this.offsetX
    this.lastOffsetY = this.offsetY
  }

  private clampOffsetX(offset: number): number {
    if (this.containerWidth <= 0 || this.imageWidth <= 0) {
      return offset
    }
    const maxOffset: number = this.getMaxOffsetX()
    return Math.max(-maxOffset, Math.min(maxOffset, offset))
  }

  private clampOffsetY(offset: number): number {
    if (this.containerHeight <= 0 || this.imageHeight <= 0) {
      return offset
    }
    const maxOffset: number = this.getMaxOffsetY()
    return Math.max(-maxOffset, Math.min(maxOffset, offset))
  }

  private getMaxOffsetX(): number {
    // Calculate the displayed image width within the container
    const imgAspect: number = this.imageWidth / this.imageHeight
    const containerAspect: number = this.containerWidth / this.containerHeight
    let displayedWidth: number = this.containerWidth
    if (imgAspect < containerAspect) {
      // Image is narrower than container; height fills, width is smaller
      displayedWidth = this.containerHeight * imgAspect
    }
    const scaledWidth: number = displayedWidth * this.zoomScale
    const overflow: number = scaledWidth - this.containerWidth
    if (overflow <= 0) {
      return 0
    }
    return overflow / 2
  }

  private getMaxOffsetY(): number {
    // Calculate the displayed image height within the container
    const imgAspect: number = this.imageWidth / this.imageHeight
    const containerAspect: number = this.containerWidth / this.containerHeight
    let displayedHeight: number = this.containerHeight
    if (imgAspect > containerAspect) {
      // Image is wider than container; width fills, height is smaller
      displayedHeight = this.containerWidth / imgAspect
    }
    const scaledHeight: number = displayedHeight * this.zoomScale
    const overflow: number = scaledHeight - this.containerHeight
    if (overflow <= 0) {
      return 0
    }
    return overflow / 2
  }

  // ---------------------------------------------------------------------------
  // Rotation (FR-006)
  // ---------------------------------------------------------------------------

  rotate90(): void {
    this.currentRotationDegrees = (this.currentRotationDegrees + 90) % 360
  }

  getCurrentRotation(): number {
    return this.currentRotationDegrees
  }

  // ---------------------------------------------------------------------------
  // EXIF orientation (FR-007)
  // ---------------------------------------------------------------------------

  private loadExifOrientation(): void {
    if (this.medium.path.length === 0) {
      return
    }

    // Skip EXIF for non-JPEG/TIFF formats
    const lowerName: string = this.medium.name.toLowerCase()
    const isJpeg: boolean = lowerName.endsWith('.jpg') || lowerName.endsWith('.jpeg')
    const isTiff: boolean = lowerName.endsWith('.tif') || lowerName.endsWith('.tiff')
    if (!isJpeg && !isTiff) {
      return
    }

    try {
      const imageSource: image.ImageSource = image.createImageSource(this.medium.path)
      const orientation: string = imageSource.getImagePropertySync(image.PropertyKey.ORIENTATION)

      this.exifRotation = this.mapExifToRotation(orientation)
      imageSource.release()
    } catch (e) {
      this.exifRotation = 0
    }
  }

  private mapExifToRotation(orientation: string): number {
    if (orientation === EXIF_ORIENTATION_ROTATE_180) {
      return 180
    } else if (orientation === EXIF_ORIENTATION_ROTATE_90) {
      return 90
    } else if (orientation === EXIF_ORIENTATION_ROTATE_270) {
      return 270
    } else {
      return 0
    }
  }
}

// Type for Image onComplete event
interface ImageCompleteEvent {
  width: number
  height: number
  componentWidth: number
  componentHeight: number
  loadingStatus: number
}
