import { Medium } from '../common/models/Medium'
import { ThumbnailItem, ThumbnailSection } from '../common/models/ThumbnailItem'

// IDataSource implementation for mixed ThumbnailItem[] (Medium and ThumbnailSection)
export class MediaDataSource implements IDataSource {
  private items: Array<ThumbnailItem> = []
  private listeners: Array<DataChangeListener> = []

  constructor(items: Array<ThumbnailItem>) {
    this.items = items
  }

  totalCount(): number {
    return this.items.length
  }

  getData(index: number): ThumbnailItem {
    return this.items[index]
  }

  getItem(index: number): ThumbnailItem {
    return this.items[index]
  }

  // Check if the item at index is a section header
  isSection(index: number): boolean {
    if (index < 0 || index >= this.items.length) {
      return false
    }
    return this.items[index] instanceof ThumbnailSection
  }

  // Check if the item at index is a Medium
  isMedium(index: number): boolean {
    if (index < 0 || index >= this.items.length) {
      return false
    }
    return this.items[index] instanceof Medium
  }

  // Get item as ThumbnailSection (caller must verify with isSection first)
  getSection(index: number): ThumbnailSection {
    return this.items[index] as ThumbnailSection
  }

  // Get item as Medium (caller must verify with isMedium first)
  getMedium(index: number): Medium {
    return this.items[index] as Medium
  }

  // Replace all items and notify listeners
  setItems(items: Array<ThumbnailItem>): void {
    this.items = items
    this.notifyDataReload()
  }

  // Add item at the end
  addItem(item: ThumbnailItem): void {
    this.items.push(item)
    this.notifyDataAdd(this.items.length - 1)
  }

  // Remove item at index
  removeItem(index: number): void {
    if (index >= 0 && index < this.items.length) {
      this.items.splice(index, 1)
      this.notifyDataDelete(index)
    }
  }

  // Get a unique key for the item at the given index
  getKey(index: number): string {
    const item: ThumbnailItem = this.items[index]
    if (item instanceof Medium) {
      return (item as Medium).path
    } else if (item instanceof ThumbnailSection) {
      return 'section_' + index.toString()
    }
    return index.toString()
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) {
      this.listeners.push(listener)
    }
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    const pos: number = this.listeners.indexOf(listener)
    if (pos >= 0) {
      this.listeners.splice(pos, 1)
    }
  }

  // Round6-Fix8: Public method to notify LazyForEach to re-evaluate all items
  // (e.g., when selection state changes)
  notifyAllChanged(): void {
    this.notifyDataReload()
  }

  private notifyDataReload(): void {
    for (let i: number = 0; i < this.listeners.length; i++) {
      this.listeners[i].onDataReloaded()
    }
  }

  private notifyDataAdd(index: number): void {
    for (let i: number = 0; i < this.listeners.length; i++) {
      this.listeners[i].onDataAdd(index)
    }
  }

  private notifyDataDelete(index: number): void {
    for (let i: number = 0; i < this.listeners.length; i++) {
      this.listeners[i].onDataDelete(index)
    }
  }

  private notifyDataChange(index: number): void {
    for (let i: number = 0; i < this.listeners.length; i++) {
      this.listeners[i].onDataChange(index)
    }
  }
}
