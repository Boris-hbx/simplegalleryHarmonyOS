export class DateTaken {
  id: number
  fullPath: string
  filename: string
  parentPath: string
  dateTaken: number
  lastFixed: number
  lastModified: number

  constructor(
    id: number = 0,
    fullPath: string = '',
    filename: string = '',
    parentPath: string = '',
    dateTaken: number = 0,
    lastFixed: number = 0,
    lastModified: number = 0
  ) {
    this.id = id
    this.fullPath = fullPath
    this.filename = filename
    this.parentPath = parentPath
    this.dateTaken = dateTaken
    this.lastFixed = lastFixed
    this.lastModified = lastModified
  }
}
