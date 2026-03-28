// =============================================================================
// CropOverlay.ets — Interactive crop rectangle with draggable handles (T-029)
// Semi-transparent mask, corner/edge handles, aspect ratio enforcement,
// rule-of-thirds grid lines
// =============================================================================

import {
  ASPECT_RATIO_FREE,
  ASPECT_RATIO_ONE_ONE,
  ASPECT_RATIO_FOUR_THREE,
  ASPECT_RATIO_SIXTEEN_NINE,
  ASPECT_RATIO_OTHER
} from '../common/constants/Constants'

// Normalized crop rectangle (0..1 coordinates relative to overlay area)
@Observed
export class CropRect {
  x: number = 0
  y: number = 0
  w: number = 1
  h: number = 1
  isActive: boolean = false
}

// Size of corner/edge drag handles in vp
const HANDLE_SIZE: number = 24
// Minimum crop dimension as fraction of total
const MIN_CROP_FRACTION: number = 0.05
// Mask colour outside crop area
const MASK_COLOR: string = '#80000000'
// Handle colour
const HANDLE_COLOR: string = '#FFFFFFFF'
// Grid line colour
const GRID_COLOR: string = '#40FFFFFF'
// Border colour
const BORDER_COLOR: string = '#FFFFFFFF'
// Border width
const BORDER_WIDTH: number = 2

// Which part of the crop rect is being dragged
const DRAG_NONE: number = 0
const DRAG_MOVE: number = 1
const DRAG_TOP_LEFT: number = 2
const DRAG_TOP: number = 3
const DRAG_TOP_RIGHT: number = 4
const DRAG_RIGHT: number = 5
const DRAG_BOTTOM_RIGHT: number = 6
const DRAG_BOTTOM: number = 7
const DRAG_BOTTOM_LEFT: number = 8
const DRAG_LEFT: number = 9

@Component
export struct CropOverlay {
  @Link cropRect: CropRect
  @Prop @Watch('onRatioChanged') cropRatio: number = ASPECT_RATIO_FREE
  @Prop customRatioX: number = 2
  @Prop customRatioY: number = 1

  // Overlay area dimensions in px (measured via onAreaChange)
  @State areaWidth: number = 1
  @State areaHeight: number = 1

  // Drag tracking
  private dragType: number = DRAG_NONE
  private dragStartX: number = 0
  private dragStartY: number = 0
  private startCropX: number = 0
  private startCropY: number = 0
  private startCropW: number = 0
  private startCropH: number = 0

  build() {
    Stack() {
      // Mask: 4 rectangles around the crop area
      // Top mask
      Column()
        .width('100%')
        .height(this.pxH(this.cropRect.y))
        .backgroundColor(MASK_COLOR)
        .position({ x: 0, y: 0 })
        .hitTestBehavior(HitTestMode.None)

      // Bottom mask
      Column()
        .width('100%')
        .height(this.pxH(1 - this.cropRect.y - this.cropRect.h))
        .backgroundColor(MASK_COLOR)
        .position({ x: 0, y: this.pxY(this.cropRect.y + this.cropRect.h) })
        .hitTestBehavior(HitTestMode.None)

      // Left mask
      Column()
        .width(this.pxW(this.cropRect.x))
        .height(this.pxH(this.cropRect.h))
        .backgroundColor(MASK_COLOR)
        .position({ x: 0, y: this.pxY(this.cropRect.y) })
        .hitTestBehavior(HitTestMode.None)

      // Right mask
      Column()
        .width(this.pxW(1 - this.cropRect.x - this.cropRect.w))
        .height(this.pxH(this.cropRect.h))
        .backgroundColor(MASK_COLOR)
        .position({
          x: this.pxX(this.cropRect.x + this.cropRect.w),
          y: this.pxY(this.cropRect.y)
        })
        .hitTestBehavior(HitTestMode.None)

      // Crop border
      Column()
        .width(this.pxW(this.cropRect.w))
        .height(this.pxH(this.cropRect.h))
        .position({ x: this.pxX(this.cropRect.x), y: this.pxY(this.cropRect.y) })
        .border({ width: BORDER_WIDTH, color: BORDER_COLOR })
        .hitTestBehavior(HitTestMode.None)

      // Rule of thirds grid lines (2 vertical + 2 horizontal)
      this.gridLine(true, 1)
      this.gridLine(true, 2)
      this.gridLine(false, 1)
      this.gridLine(false, 2)

      // Corner handles
      this.handleDot(DRAG_TOP_LEFT, this.cropRect.x, this.cropRect.y)
      this.handleDot(DRAG_TOP_RIGHT, this.cropRect.x + this.cropRect.w, this.cropRect.y)
      this.handleDot(DRAG_BOTTOM_LEFT, this.cropRect.x, this.cropRect.y + this.cropRect.h)
      this.handleDot(DRAG_BOTTOM_RIGHT, this.cropRect.x + this.cropRect.w, this.cropRect.y + this.cropRect.h)

      // Edge handles
      this.handleDot(DRAG_TOP, this.cropRect.x + this.cropRect.w / 2, this.cropRect.y)
      this.handleDot(DRAG_BOTTOM, this.cropRect.x + this.cropRect.w / 2, this.cropRect.y + this.cropRect.h)
      this.handleDot(DRAG_LEFT, this.cropRect.x, this.cropRect.y + this.cropRect.h / 2)
      this.handleDot(DRAG_RIGHT, this.cropRect.x + this.cropRect.w, this.cropRect.y + this.cropRect.h / 2)

      // Centre move area (invisible, for dragging the whole rect)
      Column()
        .width(this.pxW(this.cropRect.w) - HANDLE_SIZE)
        .height(this.pxH(this.cropRect.h) - HANDLE_SIZE)
        .position({
          x: this.pxX(this.cropRect.x) + HANDLE_SIZE / 2,
          y: this.pxY(this.cropRect.y) + HANDLE_SIZE / 2
        })
        .gesture(
          PanGesture()
            .onActionStart((event: GestureEvent) => {
              this.beginDrag(DRAG_MOVE, event)
            })
            .onActionUpdate((event: GestureEvent) => {
              this.updateDrag(event)
            })
            .onActionEnd(() => {
              this.endDrag()
            })
        )
    }
    .width('100%')
    .height('100%')
    .onAreaChange((_oldArea: Area, newArea: Area) => {
      this.areaWidth = newArea.width as number
      this.areaHeight = newArea.height as number
    })
  }

  @Builder
  handleDot(type: number, normX: number, normY: number) {
    Column()
      .width(HANDLE_SIZE)
      .height(HANDLE_SIZE)
      .borderRadius(HANDLE_SIZE / 2)
      .backgroundColor(HANDLE_COLOR)
      .position({
        x: this.pxX(normX) - HANDLE_SIZE / 2,
        y: this.pxY(normY) - HANDLE_SIZE / 2
      })
      .gesture(
        PanGesture()
          .onActionStart((event: GestureEvent) => {
            this.beginDrag(type, event)
          })
          .onActionUpdate((event: GestureEvent) => {
            this.updateDrag(event)
          })
          .onActionEnd(() => {
            this.endDrag()
          })
      )
  }

  @Builder
  gridLine(horizontal: boolean, index: number) {
    if (horizontal) {
      Column()
        .width(this.pxW(this.cropRect.w))
        .height(1)
        .backgroundColor(GRID_COLOR)
        .position({
          x: this.pxX(this.cropRect.x),
          y: this.pxY(this.cropRect.y + this.cropRect.h * index / 3)
        })
        .hitTestBehavior(HitTestMode.None)
    } else {
      Column()
        .width(1)
        .height(this.pxH(this.cropRect.h))
        .backgroundColor(GRID_COLOR)
        .position({
          x: this.pxX(this.cropRect.x + this.cropRect.w * index / 3),
          y: this.pxY(this.cropRect.y)
        })
        .hitTestBehavior(HitTestMode.None)
    }
  }

  // Coordinate helpers: normalized (0..1) to vp
  private pxX(norm: number): number {
    return norm * this.areaWidth
  }

  private pxY(norm: number): number {
    return norm * this.areaHeight
  }

  private pxW(norm: number): number {
    return norm * this.areaWidth
  }

  private pxH(norm: number): number {
    return norm * this.areaHeight
  }

  // Drag helpers
  private beginDrag(type: number, event: GestureEvent): void {
    this.dragType = type
    this.dragStartX = event.offsetX
    this.dragStartY = event.offsetY
    this.startCropX = this.cropRect.x
    this.startCropY = this.cropRect.y
    this.startCropW = this.cropRect.w
    this.startCropH = this.cropRect.h
    this.cropRect.isActive = true
  }

  private updateDrag(event: GestureEvent): void {
    const dx: number = (event.offsetX - this.dragStartX) / this.areaWidth
    const dy: number = (event.offsetY - this.dragStartY) / this.areaHeight

    if (this.dragType === DRAG_MOVE) {
      this.moveRect(dx, dy)
    } else {
      this.resizeRect(dx, dy)
    }
  }

  private endDrag(): void {
    this.dragType = DRAG_NONE
  }

  private moveRect(dx: number, dy: number): void {
    let newX: number = this.startCropX + dx
    let newY: number = this.startCropY + dy
    // Clamp to bounds
    newX = Math.max(0, Math.min(newX, 1 - this.cropRect.w))
    newY = Math.max(0, Math.min(newY, 1 - this.cropRect.h))
    this.cropRect.x = newX
    this.cropRect.y = newY
  }

  private resizeRect(dx: number, dy: number): void {
    let newX: number = this.startCropX
    let newY: number = this.startCropY
    let newW: number = this.startCropW
    let newH: number = this.startCropH

    // Apply delta based on drag type
    const affectsLeft: boolean = this.dragType === DRAG_TOP_LEFT ||
      this.dragType === DRAG_LEFT || this.dragType === DRAG_BOTTOM_LEFT
    const affectsRight: boolean = this.dragType === DRAG_TOP_RIGHT ||
      this.dragType === DRAG_RIGHT || this.dragType === DRAG_BOTTOM_RIGHT
    const affectsTop: boolean = this.dragType === DRAG_TOP_LEFT ||
      this.dragType === DRAG_TOP || this.dragType === DRAG_TOP_RIGHT
    const affectsBottom: boolean = this.dragType === DRAG_BOTTOM_LEFT ||
      this.dragType === DRAG_BOTTOM || this.dragType === DRAG_BOTTOM_RIGHT

    if (affectsLeft) {
      newX = this.startCropX + dx
      newW = this.startCropW - dx
    }
    if (affectsRight) {
      newW = this.startCropW + dx
    }
    if (affectsTop) {
      newY = this.startCropY + dy
      newH = this.startCropH - dy
    }
    if (affectsBottom) {
      newH = this.startCropH + dy
    }

    // Enforce minimum size
    if (newW < MIN_CROP_FRACTION) {
      if (affectsLeft) {
        newX = this.startCropX + this.startCropW - MIN_CROP_FRACTION
      }
      newW = MIN_CROP_FRACTION
    }
    if (newH < MIN_CROP_FRACTION) {
      if (affectsTop) {
        newY = this.startCropY + this.startCropH - MIN_CROP_FRACTION
      }
      newH = MIN_CROP_FRACTION
    }

    // Enforce aspect ratio if not free
    const ratio: number = this.getEffectiveRatio()
    if (ratio > 0) {
      // Use the width as the leading dimension and adjust height
      const desiredH: number = (newW * this.areaWidth) / (ratio * this.areaHeight)
      if (affectsTop) {
        newY = newY + newH - desiredH
      }
      newH = desiredH
      // If height is now too small, re-derive width
      if (newH < MIN_CROP_FRACTION) {
        newH = MIN_CROP_FRACTION
        newW = (newH * ratio * this.areaHeight) / this.areaWidth
        if (affectsTop) {
          newY = this.startCropY + this.startCropH - newH
        }
        if (affectsLeft) {
          newX = this.startCropX + this.startCropW - newW
        }
      }
    }

    // Clamp to bounds
    newX = Math.max(0, newX)
    newY = Math.max(0, newY)
    if (newX + newW > 1) {
      newW = 1 - newX
    }
    if (newY + newH > 1) {
      newH = 1 - newY
    }

    this.cropRect.x = newX
    this.cropRect.y = newY
    this.cropRect.w = newW
    this.cropRect.h = newH
  }

  // BUG-040 TC-11: When ratio changes, always compute from FULL image (1x1), not current crop
  private onRatioChanged(): void {
    const ratio: number = this.getEffectiveRatio()
    if (ratio <= 0) {
      // Free ratio — reset to full image
      this.cropRect.x = 0
      this.cropRect.y = 0
      this.cropRect.w = 1
      this.cropRect.h = 1
      this.cropRect.isActive = false
      return
    }
    // Calculate the largest rect with given ratio that fits within 1x1 normalized space
    // ratio = pixelW / pixelH = (w * areaWidth) / (h * areaHeight)
    // So in normalized coords: w / h = ratio * areaHeight / areaWidth
    const normalizedRatio: number = this.areaWidth > 0 && this.areaHeight > 0
      ? (ratio * this.areaHeight / this.areaWidth) : ratio
    let newW: number = 1
    let newH: number = 1
    // Start from full width, compute height
    newH = newW / normalizedRatio
    if (newH > 1) {
      // Height overflows — start from full height instead
      newH = 1
      newW = newH * normalizedRatio
    }
    // Center in the 1x1 space
    const newX: number = (1 - newW) / 2
    const newY: number = (1 - newH) / 2

    this.cropRect.x = newX
    this.cropRect.y = newY
    this.cropRect.w = newW
    this.cropRect.h = newH
    this.cropRect.isActive = true
  }

  private getEffectiveRatio(): number {
    if (this.cropRatio === ASPECT_RATIO_FREE) {
      return -1
    } else if (this.cropRatio === ASPECT_RATIO_ONE_ONE) {
      return 1
    } else if (this.cropRatio === ASPECT_RATIO_FOUR_THREE) {
      return 4 / 3
    } else if (this.cropRatio === ASPECT_RATIO_SIXTEEN_NINE) {
      return 16 / 9
    } else if (this.cropRatio === ASPECT_RATIO_OTHER) {
      if (this.customRatioY > 0) {
        return this.customRatioX / this.customRatioY
      }
      return 1
    }
    return -1
  }
}
