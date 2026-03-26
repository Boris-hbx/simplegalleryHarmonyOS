import { ThumbnailItem } from './ThumbnailItem'
import {
  TYPE_IMAGES,
  TYPE_VIDEOS,
  TYPE_GIFS,
  TYPE_RAWS,
  TYPE_SVGS,
  TYPE_PORTRAITS,
  SORT_BY_NAME,
  SORT_BY_PATH,
  SORT_BY_SIZE,
  SORT_BY_DATE_MODIFIED,
  SORT_BY_RANDOM,
  GROUP_BY_LAST_MODIFIED_DAILY,
  GROUP_BY_LAST_MODIFIED_MONTHLY,
  GROUP_BY_DATE_TAKEN_DAILY,
  GROUP_BY_DATE_TAKEN_MONTHLY,
  GROUP_BY_FILE_TYPE,
  GROUP_BY_EXTENSION,
  GROUP_BY_FOLDER,
} from '../constants/Constants'

export class Medium extends ThumbnailItem {
  id: number
  name: string
  path: string
  parentPath: string
  modified: number
  taken: number
  size: number
  type: number
  videoDuration: number
  isFavorite: boolean
  deletedTS: number
  mediaStoreId: number
  gridPosition: number = 0

  constructor(
    id: number = 0,
    name: string = '',
    path: string = '',
    parentPath: string = '',
    modified: number = 0,
    taken: number = 0,
    size: number = 0,
    type: number = 0,
    videoDuration: number = 0,
    isFavorite: boolean = false,
    deletedTS: number = 0,
    mediaStoreId: number = 0
  ) {
    super()
    this.id = id
    this.name = name
    this.path = path
    this.parentPath = parentPath
    this.modified = modified
    this.taken = taken
    this.size = size
    this.type = type
    this.videoDuration = videoDuration
    this.isFavorite = isFavorite
    this.deletedTS = deletedTS
    this.mediaStoreId = mediaStoreId
  }

  isImage(): boolean {
    return this.type === TYPE_IMAGES
  }

  isVideo(): boolean {
    return this.type === TYPE_VIDEOS
  }

  isGIF(): boolean {
    return this.type === TYPE_GIFS
  }

  isRaw(): boolean {
    return this.type === TYPE_RAWS
  }

  isSVG(): boolean {
    return this.type === TYPE_SVGS
  }

  isPortrait(): boolean {
    return this.type === TYPE_PORTRAITS
  }

  isWebP(): boolean {
    return this.name.toLowerCase().endsWith('.webp')
  }

  isApng(): boolean {
    return this.name.toLowerCase().endsWith('.apng')
  }

  isHidden(): boolean {
    return this.name.startsWith('.')
  }

  isHeic(): boolean {
    const lower: string = this.name.toLowerCase()
    return lower.endsWith('.heic') || lower.endsWith('.heif')
  }

  getIsInRecycleBin(): boolean {
    return this.deletedTS !== 0
  }

  getSignature(): string {
    const lastModified: number = this.modified > 1 ? this.modified : this.taken
    return `${this.path}-${lastModified}-${this.size}`
  }

  getBubbleText(sorting: number): string {
    if ((sorting & SORT_BY_NAME) !== 0) {
      return this.name
    } else if ((sorting & SORT_BY_PATH) !== 0) {
      return this.path
    } else if ((sorting & SORT_BY_SIZE) !== 0) {
      return Medium.formatSize(this.size)
    } else if ((sorting & SORT_BY_DATE_MODIFIED) !== 0) {
      return Medium.formatDate(this.modified)
    } else if ((sorting & SORT_BY_RANDOM) !== 0) {
      return this.name
    } else {
      return Medium.formatDate(this.taken)
    }
  }

  getGroupingKey(groupBy: number): string {
    if ((groupBy & GROUP_BY_LAST_MODIFIED_DAILY) !== 0) {
      return this.getDayStartTS(this.modified, false)
    } else if ((groupBy & GROUP_BY_LAST_MODIFIED_MONTHLY) !== 0) {
      return this.getDayStartTS(this.modified, true)
    } else if ((groupBy & GROUP_BY_DATE_TAKEN_DAILY) !== 0) {
      return this.getDayStartTS(this.taken, false)
    } else if ((groupBy & GROUP_BY_DATE_TAKEN_MONTHLY) !== 0) {
      return this.getDayStartTS(this.taken, true)
    } else if ((groupBy & GROUP_BY_FILE_TYPE) !== 0) {
      return this.type.toString()
    } else if ((groupBy & GROUP_BY_EXTENSION) !== 0) {
      return Medium.getFilenameExtension(this.name).toLowerCase()
    } else if ((groupBy & GROUP_BY_FOLDER) !== 0) {
      return this.parentPath
    } else {
      return ''
    }
  }

  private getDayStartTS(ts: number, resetDays: boolean): string {
    const date: Date = new Date(ts)
    date.setHours(0, 0, 0, 0)
    if (resetDays) {
      date.setDate(1)
    }
    return date.getTime().toString()
  }

  private static getFilenameExtension(filename: string): string {
    const dotIndex: number = filename.lastIndexOf('.')
    if (dotIndex === -1) {
      return ''
    }
    return filename.substring(dotIndex + 1)
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
