import {
  FAVORITES,
  RECYCLE_BIN,
  SORT_BY_NAME,
  SORT_BY_PATH,
  SORT_BY_SIZE,
  SORT_BY_DATE_MODIFIED,
  SORT_BY_RANDOM,
  TYPE_VIDEOS,
  TYPE_IMAGES,
} from '../constants/Constants'

export class Directory {
  id: number
  path: string
  tmb: string
  name: string
  mediaCnt: number
  modified: number
  taken: number
  size: number
  location: number
  types: number
  sortValue: string
  subfoldersCount: number = 0
  subfoldersMediaCount: number = 0
  containsMediaFilesDirectly: boolean = true

  constructor(
    id: number = 0,
    path: string = '',
    tmb: string = '',
    name: string = '',
    mediaCnt: number = 0,
    modified: number = 0,
    taken: number = 0,
    size: number = 0,
    location: number = 0,
    types: number = 0,
    sortValue: string = ''
  ) {
    this.id = id
    this.path = path
    this.tmb = tmb
    this.name = name
    this.mediaCnt = mediaCnt
    this.modified = modified
    this.taken = taken
    this.size = size
    this.location = location
    this.types = types
    this.sortValue = sortValue
  }

  areFavorites(): boolean {
    return this.path === FAVORITES
  }

  isRecycleBin(): boolean {
    return this.path === RECYCLE_BIN
  }

  isVideoOnly(): boolean {
    return (this.types & TYPE_VIDEOS) !== 0 && (this.types & TYPE_IMAGES) === 0
  }

  getBubbleText(sorting: number): string {
    if ((sorting & SORT_BY_NAME) !== 0) {
      return this.name
    } else if ((sorting & SORT_BY_PATH) !== 0) {
      return this.path
    } else if ((sorting & SORT_BY_SIZE) !== 0) {
      return Directory.formatSize(this.size)
    } else if ((sorting & SORT_BY_DATE_MODIFIED) !== 0) {
      return Directory.formatDate(this.modified)
    } else if ((sorting & SORT_BY_RANDOM) !== 0) {
      return this.name
    } else {
      return Directory.formatDate(this.taken)
    }
  }

  private static formatSize(bytes: number): string {
    if (bytes < 1024) {
      return `${bytes} B`
    } else if (bytes < 1024 * 1024) {
      const kb: number = Math.round(bytes / 1024 * 100) / 100
      return `${kb} KB`
    } else if (bytes < 1024 * 1024 * 1024) {
      const mb: number = Math.round(bytes / (1024 * 1024) * 100) / 100
      return `${mb} MB`
    } else {
      const gb: number = Math.round(bytes / (1024 * 1024 * 1024) * 100) / 100
      return `${gb} GB`
    }
  }

  private static formatDate(ts: number): string {
    if (ts <= 0) {
      return ''
    }
    const date: Date = new Date(ts)
    const year: number = date.getFullYear()
    const month: string = (date.getMonth() + 1).toString().padStart(2, '0')
    const day: string = date.getDate().toString().padStart(2, '0')
    const hours: string = date.getHours().toString().padStart(2, '0')
    const minutes: string = date.getMinutes().toString().padStart(2, '0')
    return `${year}-${month}-${day} ${hours}:${minutes}`
  }
}
