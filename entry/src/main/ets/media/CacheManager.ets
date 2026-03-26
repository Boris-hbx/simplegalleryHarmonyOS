import { Directory } from '../common/models/Directory'
import { DirectoryDao } from '../datastore/dao/DirectoryDao'
import { MediaScanner } from './MediaScanner'

interface DiffResult {
  added: Directory[]
  removed: string[]
  modified: Directory[]
}

export class CacheManager {
  private directoryDao: DirectoryDao

  constructor() {
    this.directoryDao = new DirectoryDao()
  }

  // Load cached directories from DB for fast first render
  async loadFromCache(): Promise<Directory[]> {
    return await this.directoryDao.getAll()
  }

  // Run full scan and compute diff against cached data
  async scanAndDiff(scanner: MediaScanner, cached: Directory[],
                    filterMedia: number, sorting: number): Promise<DiffResult> {
    const fresh: Directory[] = await scanner.getDirectories(filterMedia, sorting)
    const cachedMap: Map<string, Directory> = new Map<string, Directory>()
    for (let i: number = 0; i < cached.length; i++) {
      cachedMap.set(cached[i].path, cached[i])
    }

    const added: Directory[] = []
    const modified: Directory[] = []
    const freshPaths: Set<string> = new Set<string>()

    for (let i: number = 0; i < fresh.length; i++) {
      freshPaths.add(fresh[i].path)
      const old: Directory | undefined = cachedMap.get(fresh[i].path)
      if (old === undefined) {
        added.push(fresh[i])
      } else if (old.modified !== fresh[i].modified || old.mediaCnt !== fresh[i].mediaCnt) {
        modified.push(fresh[i])
      }
    }

    const removed: string[] = []
    for (let i: number = 0; i < cached.length; i++) {
      if (!freshPaths.has(cached[i].path)) {
        removed.push(cached[i].path)
      }
    }

    return { added: added, removed: removed, modified: modified } as DiffResult
  }

  // Apply diff to current directory list
  applyDiff(currentDirs: Directory[], diff: DiffResult): Directory[] {
    // Remove removed
    let result: Directory[] = []
    const removedSet: Set<string> = new Set<string>(diff.removed)
    for (let i: number = 0; i < currentDirs.length; i++) {
      if (!removedSet.has(currentDirs[i].path)) {
        result.push(currentDirs[i])
      }
    }
    // Update modified
    const modifiedMap: Map<string, Directory> = new Map<string, Directory>()
    for (let i: number = 0; i < diff.modified.length; i++) {
      modifiedMap.set(diff.modified[i].path, diff.modified[i])
    }
    for (let i: number = 0; i < result.length; i++) {
      const mod: Directory | undefined = modifiedMap.get(result[i].path)
      if (mod !== undefined) {
        result[i] = mod
      }
    }
    // Add new
    for (let i: number = 0; i < diff.added.length; i++) {
      result.push(diff.added[i])
    }
    return result
  }

  // Persist updated dirs to DB cache
  async persistCache(dirs: Directory[]): Promise<void> {
    await this.directoryDao.insertAll(dirs)
  }
}
