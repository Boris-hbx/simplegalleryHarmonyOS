export class Favorite {
  id: number
  fullPath: string
  filename: string
  parentPath: string

  constructor(
    id: number = 0,
    fullPath: string = '',
    filename: string = '',
    parentPath: string = ''
  ) {
    this.id = id
    this.fullPath = fullPath
    this.filename = filename
    this.parentPath = parentPath
  }
}
