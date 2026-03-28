// =============================================================================
// DrawCanvas.ets — Freehand drawing canvas overlay for EditPage (T-030)
// FR-030: Drawing overlay on images with color, brush size, undo, clear
// =============================================================================

import { PaintOptions } from '../common/models/PaintOptions'
import { image } from '@kit.ImageKit'

interface DrawPath {
  points: number[][]  // Array of [x, y] pairs
  color: number
  strokeWidth: number
}

@Component
export struct DrawCanvas {
  @Prop paintOptions: PaintOptions = new PaintOptions()
  // Callback to expose this component's instance to parent (for save)
  onRef: (ref: DrawCanvas) => void = (_ref: DrawCanvas) => {}
  @State paths: DrawPath[] = []
  @State currentPath: number[][] = []

  private canvasSettings: RenderingContextSettings = new RenderingContextSettings(true)
  private canvasContext: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.canvasSettings)
  private canvasWidth: number = 0
  private canvasHeight: number = 0

  aboutToAppear(): void {
    this.onRef(this)
  }

  build() {
    Canvas(this.canvasContext)
      .width('100%')
      .height('100%')
      .backgroundColor(Color.Transparent)
      .onReady(() => {
        this.canvasWidth = this.canvasContext.width
        this.canvasHeight = this.canvasContext.height
        this.redrawAll()
      })
      .onAreaChange((_oldArea: Area, newArea: Area) => {
        this.canvasWidth = newArea.width as number
        this.canvasHeight = newArea.height as number
      })
      .gesture(
        PanGesture()
          .onActionStart((event: GestureEvent) => {
            const finger: FingerInfo = event.fingerList[0]
            this.currentPath = []
            this.currentPath.push([finger.localX, finger.localY])
          })
          .onActionUpdate((event: GestureEvent) => {
            const finger: FingerInfo = event.fingerList[0]
            this.currentPath.push([finger.localX, finger.localY])
            this.drawCurrentSegment()
          })
          .onActionEnd(() => {
            if (this.currentPath.length > 1) {
              const newPath: DrawPath = {
                points: this.currentPath.slice(),
                color: this.paintOptions.color,
                strokeWidth: this.paintOptions.strokeWidth
              } as DrawPath
              this.paths.push(newPath)
            }
            this.currentPath = []
          })
      )
  }

  /**
   * Draws only the last segment of the current stroke for performance.
   */
  private drawCurrentSegment(): void {
    if (this.currentPath.length < 2) {
      return
    }
    const ctx: CanvasRenderingContext2D = this.canvasContext
    const prevIdx: number = this.currentPath.length - 2
    const currIdx: number = this.currentPath.length - 1
    const prevX: number = this.currentPath[prevIdx][0]
    const prevY: number = this.currentPath[prevIdx][1]
    const currX: number = this.currentPath[currIdx][0]
    const currY: number = this.currentPath[currIdx][1]

    ctx.beginPath()
    ctx.strokeStyle = this.colorToHex(this.paintOptions.color)
    ctx.lineWidth = this.paintOptions.strokeWidth
    ctx.lineCap = 'round'
    ctx.lineJoin = 'round'
    ctx.moveTo(prevX, prevY)
    ctx.lineTo(currX, currY)
    ctx.stroke()
  }

  /**
   * Clears the canvas and redraws all completed paths from scratch.
   */
  redrawAll(): void {
    const ctx: CanvasRenderingContext2D = this.canvasContext
    ctx.clearRect(0, 0, this.canvasWidth, this.canvasHeight)

    for (let i: number = 0; i < this.paths.length; i++) {
      const path: DrawPath = this.paths[i]
      if (path.points.length < 2) {
        continue
      }
      ctx.beginPath()
      ctx.strokeStyle = this.colorToHex(path.color)
      ctx.lineWidth = path.strokeWidth
      ctx.lineCap = 'round'
      ctx.lineJoin = 'round'
      ctx.moveTo(path.points[0][0], path.points[0][1])
      for (let j: number = 1; j < path.points.length; j++) {
        ctx.lineTo(path.points[j][0], path.points[j][1])
      }
      ctx.stroke()
    }
  }

  /**
   * Removes the last completed path and redraws.
   */
  undoLast(): void {
    if (this.paths.length > 0) {
      this.paths.pop()
      this.redrawAll()
    }
  }

  /**
   * Clears all paths and the canvas.
   */
  clearAll(): void {
    this.paths = []
    const ctx: CanvasRenderingContext2D = this.canvasContext
    ctx.clearRect(0, 0, this.canvasWidth, this.canvasHeight)
  }

  /**
   * Returns true if there are any drawn paths.
   */
  hasDrawing(): boolean {
    return this.paths.length > 0
  }

  /**
   * Exports the current drawing as a PixelMap for compositing onto the image.
   * The caller must release the returned PixelMap when done.
   */
  async getDrawnPixelMap(targetWidth: number, targetHeight: number): Promise<image.PixelMap> {
    // Create an offscreen canvas at the target image resolution
    const offSettings: RenderingContextSettings = new RenderingContextSettings(true)
    const offCanvas: OffscreenCanvasRenderingContext2D =
      new OffscreenCanvasRenderingContext2D(targetWidth, targetHeight, offSettings)

    // Scale factor from display canvas to target pixel dimensions
    const scaleX: number = targetWidth / this.canvasWidth
    const scaleY: number = targetHeight / this.canvasHeight

    // Redraw all paths at scaled coordinates
    for (let i: number = 0; i < this.paths.length; i++) {
      const path: DrawPath = this.paths[i]
      if (path.points.length < 2) {
        continue
      }
      offCanvas.beginPath()
      offCanvas.strokeStyle = this.colorToHex(path.color)
      offCanvas.lineWidth = path.strokeWidth * Math.min(scaleX, scaleY)
      offCanvas.lineCap = 'round'
      offCanvas.lineJoin = 'round'
      offCanvas.moveTo(path.points[0][0] * scaleX, path.points[0][1] * scaleY)
      for (let j: number = 1; j < path.points.length; j++) {
        offCanvas.lineTo(path.points[j][0] * scaleX, path.points[j][1] * scaleY)
      }
      offCanvas.stroke()
    }

    // Transfer offscreen canvas content to a PixelMap
    const imageData: ImageData = offCanvas.getImageData(0, 0, targetWidth, targetHeight)
    const opts: image.InitializationOptions = {
      size: { width: targetWidth, height: targetHeight },
      pixelFormat: image.PixelMapFormat.RGBA_8888,
      editable: true
    }
    const pixelMap: image.PixelMap = await image.createPixelMap(imageData.data.buffer, opts)
    return pixelMap
  }

  /**
   * Converts an integer color (0xAARRGGBB or 0xRRGGBB) to a hex string.
   */
  private colorToHex(color: number): string {
    const r: number = (color >> 16) & 0xFF
    const g: number = (color >> 8) & 0xFF
    const b: number = color & 0xFF
    const a: number = (color >> 24) & 0xFF
    const rStr: string = r.toString(16).padStart(2, '0')
    const gStr: string = g.toString(16).padStart(2, '0')
    const bStr: string = b.toString(16).padStart(2, '0')
    if (a > 0 && a < 0xFF) {
      const aFraction: number = a / 255.0
      return 'rgba(' + r.toString() + ',' + g.toString() + ',' + b.toString() + ',' + aFraction.toFixed(2) + ')'
    }
    return '#' + rStr + gStr + bStr
  }
}
