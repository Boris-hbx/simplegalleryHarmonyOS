import { Medium } from '../models/Medium'

export interface DateGroup {
  title: string
  items: Medium[]
}

export function groupMediaByDate(mediaList: Medium[], todayLabel: string, yesterdayLabel: string): DateGroup[] {
  // Sort by date_taken (or last_modified if date_taken is 0) descending
  const sorted: Medium[] = mediaList.slice()
  sorted.sort((a: Medium, b: Medium): number => {
    const dateA: number = a.taken > 0 ? a.taken : a.modified
    const dateB: number = b.taken > 0 ? b.taken : b.modified
    return dateB - dateA
  })

  const groups: DateGroup[] = []
  const now: Date = new Date()
  const todayStr: string = formatDateKey(now)
  const yesterday: Date = new Date(now.getTime() - 86400000)
  const yesterdayStr: string = formatDateKey(yesterday)

  let currentKey: string = ''
  let currentGroup: DateGroup | null = null

  for (let i: number = 0; i < sorted.length; i++) {
    const medium: Medium = sorted[i]
    const ts: number = medium.taken > 0 ? medium.taken : medium.modified
    const date: Date = new Date(ts)
    const key: string = formatDateKey(date)

    if (key !== currentKey) {
      let title: string = ''
      if (key === todayStr) {
        title = todayLabel
      } else if (key === yesterdayStr) {
        title = yesterdayLabel
      } else {
        title = formatDisplayDate(date)
      }
      currentGroup = { title: title, items: [] }
      groups.push(currentGroup)
      currentKey = key
    }
    if (currentGroup !== null) {
      currentGroup.items.push(medium)
    }
  }

  return groups
}

function formatDateKey(date: Date): string {
  const y: number = date.getFullYear()
  const m: string = (date.getMonth() + 1).toString().padStart(2, '0')
  const d: string = date.getDate().toString().padStart(2, '0')
  return y.toString() + '-' + m + '-' + d
}

function formatDisplayDate(date: Date): string {
  const y: number = date.getFullYear()
  const m: string = (date.getMonth() + 1).toString().padStart(2, '0')
  const d: string = date.getDate().toString().padStart(2, '0')
  return y.toString() + '-' + m + '-' + d
}
