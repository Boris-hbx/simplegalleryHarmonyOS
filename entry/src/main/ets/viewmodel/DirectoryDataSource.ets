import { Directory } from '../common/models/Directory'

export class DirectoryDataSource implements IDataSource {
  private directories: Directory[] = []
  private listeners: DataChangeListener[] = []

  totalCount(): number {
    return this.directories.length
  }

  getData(index: number): Directory {
    return this.directories[index]
  }

  setData(dirs: Directory[]): void {
    this.directories = dirs
    this.notifyReload()
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    this.listeners.push(listener)
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    const idx: number = this.listeners.indexOf(listener)
    if (idx >= 0) {
      this.listeners.splice(idx, 1)
    }
  }

  // Round6-Fix8: Notify LazyForEach that all items need re-evaluation
  // (e.g., when selection state changes and we need to update isSelected props)
  notifyAllChanged(): void {
    this.notifyReload()
  }

  private notifyReload(): void {
    for (let i: number = 0; i < this.listeners.length; i++) {
      this.listeners[i].onDataReloaded()
    }
  }
}
