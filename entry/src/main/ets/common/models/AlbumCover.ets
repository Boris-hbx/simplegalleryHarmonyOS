// Custom album cover — maps a folder path to a specific thumbnail image path
export class AlbumCover {
  path: string
  tmb: string

  constructor(path: string, tmb: string) {
    this.path = path
    this.tmb = tmb
  }
}
