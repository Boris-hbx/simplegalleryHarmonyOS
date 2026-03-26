export class Widget {
  id: number
  widgetId: number
  folderPath: string

  constructor(
    id: number = 0,
    widgetId: number = 0,
    folderPath: string = ''
  ) {
    this.id = id
    this.widgetId = widgetId
    this.folderPath = folderPath
  }
}
