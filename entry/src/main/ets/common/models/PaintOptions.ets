// Drawing options for the image editor's brush tool
export class PaintOptions {
  color: number
  strokeWidth: number

  constructor(color: number = 0xFF000000, strokeWidth: number = 5) {
    this.color = color
    this.strokeWidth = strokeWidth
  }
}
