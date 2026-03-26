import { Medium } from '../common/models/Medium'
import { ThumbnailItem, ThumbnailSection } from '../common/models/ThumbnailItem'
import {
  GROUP_BY_NONE, GROUP_BY_LAST_MODIFIED_DAILY, GROUP_BY_DATE_TAKEN_DAILY,
  GROUP_BY_FILE_TYPE, GROUP_BY_EXTENSION, GROUP_BY_FOLDER,
  GROUP_BY_LAST_MODIFIED_MONTHLY, GROUP_BY_DATE_TAKEN_MONTHLY,
  GROUP_DESCENDING, GROUP_SHOW_FILE_COUNT,
  TYPE_IMAGES, TYPE_VIDEOS, TYPE_GIFS, TYPE_RAWS, TYPE_SVGS, TYPE_PORTRAITS
} from '../common/constants/Constants'

// Number of milliseconds in one day
const DAY_MS: number = 86400000

export class MediaGrouper {

  // Insert group section headers into a flat list of media items
  static insertGroupHeaders(
    items: Array<Medium>, groupBy: number, showFileCount: boolean
  ): Array<ThumbnailItem> {
    if ((groupBy & GROUP_BY_NONE) !== 0 || items.length === 0) {
      const result: Array<ThumbnailItem> = []
      for (let i: number = 0; i < items.length; i++) {
        result.push(items[i])
      }
      return result
    }

    // Build ordered groups using a key array + map to preserve insertion order
    const groupKeys: Array<string> = []
    const groupMap: Map<string, Array<Medium>> = new Map<string, Array<Medium>>()

    for (let i: number = 0; i < items.length; i++) {
      const medium: Medium = items[i]
      const key: string = medium.getGroupingKey(groupBy)

      if (groupMap.has(key)) {
        const existing: Array<Medium> = groupMap.get(key) as Array<Medium>
        existing.push(medium)
      } else {
        groupKeys.push(key)
        const newGroup: Array<Medium> = [medium]
        groupMap.set(key, newGroup)
      }
    }

    // Sort group keys
    const sortDescending: boolean = (groupBy & GROUP_DESCENDING) !== 0
    const isDateGroup: boolean = MediaGrouper.isDateBasedGrouping(groupBy)

    groupKeys.sort((a: string, b: string): number => {
      let result: number = 0
      if (isDateGroup) {
        const numA: number = MediaGrouper.parseNumericKey(a)
        const numB: number = MediaGrouper.parseNumericKey(b)
        result = numA - numB
      } else {
        result = a.localeCompare(b)
      }
      return sortDescending ? -result : result
    })

    // Build result with section headers
    const today: string = MediaGrouper.formatDateLabel(Date.now(), true)
    const yesterday: string = MediaGrouper.formatDateLabel(Date.now() - DAY_MS, true)
    const thumbnailItems: Array<ThumbnailItem> = []

    for (let k: number = 0; k < groupKeys.length; k++) {
      const key: string = groupKeys[k]
      const groupItems: Array<Medium> = groupMap.get(key) as Array<Medium>
      const title: string = MediaGrouper.formatGroupTitle(
        key, groupBy, today, yesterday, groupItems.length, showFileCount
      )

      thumbnailItems.push(new ThumbnailSection(title))

      let gridPosition: number = 0
      for (let m: number = 0; m < groupItems.length; m++) {
        const medium: Medium = groupItems[m]
        medium.gridPosition = gridPosition
        gridPosition = gridPosition + 1
        thumbnailItems.push(medium)
      }
    }

    return thumbnailItems
  }

  // Check if the grouping mode is date-based (keys are numeric timestamps)
  private static isDateBasedGrouping(groupBy: number): boolean {
    if ((groupBy & GROUP_BY_LAST_MODIFIED_DAILY) !== 0) {
      return true
    }
    if ((groupBy & GROUP_BY_LAST_MODIFIED_MONTHLY) !== 0) {
      return true
    }
    if ((groupBy & GROUP_BY_DATE_TAKEN_DAILY) !== 0) {
      return true
    }
    if ((groupBy & GROUP_BY_DATE_TAKEN_MONTHLY) !== 0) {
      return true
    }
    return false
  }

  // Safely parse a string key as a number, returning 0 on failure
  private static parseNumericKey(key: string): number {
    const parsed: number = Number.parseInt(key)
    if (Number.isNaN(parsed)) {
      return 0
    }
    return parsed
  }

  // Format the group section title based on grouping type
  private static formatGroupTitle(
    key: string, groupBy: number,
    today: string, yesterday: string,
    count: number, showFileCount: boolean
  ): string {
    let title: string = ''

    if ((groupBy & GROUP_BY_LAST_MODIFIED_DAILY) !== 0 ||
        (groupBy & GROUP_BY_DATE_TAKEN_DAILY) !== 0) {
      const dateLabel: string = MediaGrouper.formatDateFromKey(key, true)
      title = MediaGrouper.resolveDayLabel(dateLabel, today, yesterday)
    } else if ((groupBy & GROUP_BY_LAST_MODIFIED_MONTHLY) !== 0 ||
               (groupBy & GROUP_BY_DATE_TAKEN_MONTHLY) !== 0) {
      title = MediaGrouper.formatDateFromKey(key, false)
    } else if ((groupBy & GROUP_BY_FILE_TYPE) !== 0) {
      title = MediaGrouper.getFileTypeLabel(key)
    } else if ((groupBy & GROUP_BY_EXTENSION) !== 0) {
      title = key.toUpperCase()
    } else if ((groupBy & GROUP_BY_FOLDER) !== 0) {
      title = MediaGrouper.extractFolderName(key)
    } else {
      title = key
    }

    if (title.length === 0) {
      title = 'Unknown'
    }

    if (showFileCount) {
      title = `${title} (${count})`
    }

    return title
  }

  // Format a timestamp key into a readable date string
  private static formatDateFromKey(key: string, showDay: boolean): string {
    const ts: number = Number.parseInt(key)
    if (Number.isNaN(ts) || ts <= 0) {
      return ''
    }
    const date: Date = new Date(ts)
    const year: number = date.getFullYear()
    const month: number = date.getMonth()
    const monthNames: Array<string> = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ]
    const monthName: string = monthNames[month]

    if (!showDay) {
      return `${monthName} ${year}`
    }

    const day: string = date.getDate().toString().padStart(2, '0')
    const monthStr: string = (month + 1).toString().padStart(2, '0')
    return `${year}-${monthStr}-${day}`
  }

  // Format a timestamp into a date label for today/yesterday comparison
  private static formatDateLabel(ts: number, showDay: boolean): string {
    const date: Date = new Date(ts)
    date.setHours(0, 0, 0, 0)
    const year: number = date.getFullYear()
    const month: number = date.getMonth()

    if (!showDay) {
      const monthNames: Array<string> = [
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
      ]
      return `${monthNames[month]} ${year}`
    }

    const monthStr: string = (month + 1).toString().padStart(2, '0')
    const day: string = date.getDate().toString().padStart(2, '0')
    return `${year}-${monthStr}-${day}`
  }

  // Replace date strings matching today/yesterday with friendly labels
  private static resolveDayLabel(
    dateStr: string, today: string, yesterday: string
  ): string {
    if (dateStr === today) {
      return 'Today'
    }
    if (dateStr === yesterday) {
      return 'Yesterday'
    }
    return dateStr
  }

  // Map file type constant to a human-readable label
  private static getFileTypeLabel(key: string): string {
    const typeVal: number = Number.parseInt(key)
    if (typeVal === TYPE_IMAGES) {
      return 'Images'
    } else if (typeVal === TYPE_VIDEOS) {
      return 'Videos'
    } else if (typeVal === TYPE_GIFS) {
      return 'GIFs'
    } else if (typeVal === TYPE_RAWS) {
      return 'RAW Images'
    } else if (typeVal === TYPE_SVGS) {
      return 'SVGs'
    } else if (typeVal === TYPE_PORTRAITS) {
      return 'Portraits'
    }
    return 'Other'
  }

  // Extract folder display name from a path
  private static extractFolderName(path: string): string {
    if (path.length === 0) {
      return ''
    }
    const lastSlash: number = path.lastIndexOf('/')
    if (lastSlash >= 0 && lastSlash < path.length - 1) {
      return path.substring(lastSlash + 1)
    }
    return path
  }
}
