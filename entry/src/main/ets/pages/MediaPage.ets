import { router } from '@kit.ArkUI'
import { common, Want } from '@kit.AbilityKit'
import { fileIo } from '@kit.CoreFileKit'
import { ShareUtils } from '../utils/ShareUtils'
import { FileOperations } from '../utils/FileOperations'
import { DeleteConfirmDialog, RenameDialog, CopyMoveDialog } from '../components/FileOpDialogs'
import { Medium } from '../common/models/Medium'
import { ThumbnailItem, ThumbnailSection } from '../common/models/ThumbnailItem'
import { MediaScanner } from '../media/MediaScanner'
import { MediaGrouper } from '../media/MediaGrouper'
import { ConfigManager } from '../datastore/ConfigManager'
import { FavoritesDao } from '../datastore/dao/FavoritesDao'
import { MediaItem } from '../components/MediaItem'
import { MediaDataSource } from '../viewmodel/MediaDataSource'
import {
  VIEW_TYPE_GRID, VIEW_TYPE_LIST, GROUP_SHOW_FILE_COUNT,
  TYPE_VIDEOS,
  SORT_BY_NAME, SORT_BY_DATE_MODIFIED, SORT_BY_SIZE,
  SORT_BY_DATE_TAKEN, SORT_DESCENDING,
  GROUP_BY_NONE, GROUP_BY_LAST_MODIFIED_DAILY,
  GROUP_BY_DATE_TAKEN_DAILY, GROUP_BY_FILE_TYPE,
  GROUP_BY_LAST_MODIFIED_MONTHLY, GROUP_BY_DATE_TAKEN_MONTHLY
} from '../common/constants/Constants'

interface ViewingPageParams {
  mediaListJson: string
  selectedIndex: number
  folderPath: string
}

// T-065: Menu item interface for CAB overflow menu
interface MediaMenuItem {
  value: string
  action: () => void
}

interface DialogButtonInfo {
  text: string
  color: string
}

interface ShowDialogSuccessResponse {
  index: number
}

@Entry
@Component
struct MediaPage {
  @State mediaItems: ThumbnailItem[] = []
  @State isLoading: boolean = true
  @State isRefreshing: boolean = false
  @State viewType: number = VIEW_TYPE_GRID
  @State columnCount: number = 3
  @State displayFileNames: boolean = false
  @State directoryName: string = ''
  @State currentGrouping: number = GROUP_BY_NONE
  @State isMultiSelectMode: boolean = false
  @State selectedPaths: Set<string> = new Set<string>()
  // T-081: Pagination state
  private allMediaCache: Medium[] = []  // full sorted list from scanner
  private pageSize: number = 100
  private loadedCount: number = 0
  private isLoadingMore: boolean = false
  // Track deleted URIs so they stay hidden after rescan (no WRITE_IMAGEVIDEO permission)
  private deletedUris: Set<string> = new Set<string>()

  private directoryPath: string = ''
  private currentSorting: number = SORT_BY_DATE_MODIFIED | SORT_DESCENDING
  private mediaDataSource: MediaDataSource = new MediaDataSource([])

  private deleteConfirmDialogController: CustomDialogController = new CustomDialogController({
    builder: DeleteConfirmDialog({
      fileCount: this.selectedPaths.size,
      onConfirm: (skipRecycleBin: boolean) => {
        this.deleteSelectedMedia(skipRecycleBin)
      }
    }),
    autoCancel: true,
    alignment: DialogAlignment.Center
  })

  private renameDialogController: CustomDialogController = new CustomDialogController({
    builder: RenameDialog({
      currentName: this.getSelectedMediumForRename()?.name ?? '',
      onConfirm: (newName: string) => {
        this.renameSelectedMedia(newName)
      }
    }),
    autoCancel: true,
    alignment: DialogAlignment.Center
  })

  private copyMoveTitle: string = ''
  private copyMoveIsCopy: boolean = true

  private copyMoveDialogController: CustomDialogController = new CustomDialogController({
    builder: CopyMoveDialog({
      title: this.copyMoveTitle,
      onFolderSelected: (folderPath: string) => {
        this.executeCopyMove(folderPath)
      }
    }),
    autoCancel: true,
    alignment: DialogAlignment.Center
  })

  private getStr(resId: number): string {
    try {
      return getContext(this).resourceManager.getStringSync(resId)
    } catch (e) {
      return ''
    }
  }

  aboutToAppear(): void {
    const params: Record<string, Object> = router.getParams() as Record<string, Object>
    if (params !== null && params !== undefined) {
      this.directoryPath = (params['directoryPath'] as string) || ''
      this.directoryName = (params['directoryName'] as string) || ''
    }
    const config: ConfigManager = ConfigManager.getInstance()
    this.viewType = config.getFolderViewType(this.directoryPath)
    this.columnCount = config.mediaColumnCnt
    this.displayFileNames = config.displayFileNames
    this.currentSorting = config.directorySorting
    this.currentGrouping = config.getFolderGrouping(this.directoryPath)
    this.loadMedia()
  }

  onPageShow(): void {
    const config: ConfigManager = ConfigManager.getInstance()
    const newViewType: number = config.getFolderViewType(this.directoryPath)
    const newColumnCount: number = config.mediaColumnCnt
    const newDisplayFileNames: boolean = config.displayFileNames
    const newGrouping: number = config.getFolderGrouping(this.directoryPath)
    if (newViewType !== this.viewType || newColumnCount !== this.columnCount ||
      newDisplayFileNames !== this.displayFileNames || newGrouping !== this.currentGrouping) {
      this.viewType = newViewType
      this.columnCount = newColumnCount
      this.displayFileNames = newDisplayFileNames
      this.currentGrouping = newGrouping
      this.loadMedia()
    } else {
      // BUG-034: Refresh favorite states without full reload
      // When returning from ViewingPage, isFavorite may have changed
      this.refreshFavoriteStates()
    }
  }

  onBackPress(): boolean {
    if (this.isMultiSelectMode) {
      this.exitMultiSelectMode()
      return true
    }
    router.back()
    return true
  }

  private enterMultiSelectMode(medium: Medium): void {
    this.isMultiSelectMode = true
    const newSet: Set<string> = new Set<string>()
    newSet.add(medium.path)
    this.selectedPaths = newSet
    this.mediaDataSource.notifyAllChanged()
  }

  private exitMultiSelectMode(): void {
    this.isMultiSelectMode = false
    this.selectedPaths = new Set<string>()
    this.mediaDataSource.notifyAllChanged()
  }

  private selectAll(): void {
    const newSet: Set<string> = new Set<string>()
    for (let i: number = 0; i < this.mediaItems.length; i++) {
      if (this.mediaItems[i] instanceof Medium) {
        newSet.add((this.mediaItems[i] as Medium).path)
      }
    }
    this.selectedPaths = newSet
    this.mediaDataSource.notifyAllChanged()
  }

  private shareSelectedMedia(): void {
    if (this.selectedPaths.size === 0) {
      return
    }
    const paths: string[] = Array.from(this.selectedPaths)
    try {
      const context: common.UIAbilityContext = this.getUIContext().getHostContext()! as common.UIAbilityContext
      ShareUtils.shareMultipleMedia(context, paths).then((): void => {
        console.info('[MediaPage] shareSelectedMedia succeeded')
      }).catch((err: Error): void => {
        console.error('[MediaPage] shareSelectedMedia failed: ' + err.message)
      })
    } catch (e) {
      console.error('[MediaPage] shareSelectedMedia: failed to get context')
    }
  }

  private deleteSelectedMedia(skipRecycleBin: boolean): void {
    console.info('[MediaPage] deleteSelectedMedia called, selectedPaths.size=' + this.selectedPaths.size.toString())
    console.info('[MediaPage] mediaItems.length=' + this.mediaItems.length.toString())
    if (this.selectedPaths.size === 0) {
      console.warn('[MediaPage] deleteSelectedMedia: selectedPaths is EMPTY, returning')
      return
    }

    // BUG-R6B-9: Remove from current display list immediately (UI-level delete).
    // FileOperations.deleteFiles operates on internal DB which has no records for
    // photoAccessHelper media, so SQL matches 0 rows and nothing happens.
    // Fix: filter items out of the display list directly.
    const removedPaths: Set<string> = new Set<string>(this.selectedPaths)
    // Remember deleted URIs so rescan won't bring them back
    removedPaths.forEach((p: string) => { this.deletedUris.add(p) })
    const newItems: ThumbnailItem[] = []
    for (let i: number = 0; i < this.mediaItems.length; i++) {
      if (this.mediaItems[i] instanceof Medium) {
        if (!removedPaths.has((this.mediaItems[i] as Medium).path)) {
          newItems.push(this.mediaItems[i])
        }
      } else {
        newItems.push(this.mediaItems[i]) // keep section headers
      }
    }
    const removedCount: number = this.mediaItems.length - newItems.length
    this.mediaItems = newItems
    this.mediaDataSource.setItems(this.mediaItems)
    this.exitMultiSelectMode()
    // BUG-039 G-004: Toast feedback after delete
    this.getUIContext()?.getPromptAction()?.showToast({ message: removedCount.toString() + ' items deleted' })
    console.info('[MediaPage] deleteSelectedMedia: removed ' + removedCount.toString() + ' items from UI')

    // Best-effort: try to delete from system DB (may match 0 rows — that's OK)
    const paths: string[] = Array.from(removedPaths)
    const useRecycleBin: boolean = !skipRecycleBin
    let deleteContext: Context | undefined = undefined
    try {
      deleteContext = this.getUIContext().getHostContext()!
    } catch (e) {
      // Context unavailable
    }
    FileOperations.deleteFiles(paths, useRecycleBin, deleteContext).catch((): void => {
      console.warn('[MediaPage] deleteSelectedMedia: system delete failed (expected for photoAccessHelper media)')
    })
  }

  private getTotalMediaCount(): number {
    let count: number = 0
    for (let i: number = 0; i < this.mediaItems.length; i++) {
      if (this.mediaItems[i] instanceof Medium) {
        count++
      }
    }
    return count
  }

  private toggleSelection(medium: Medium): void {
    const newSet: Set<string> = new Set<string>(this.selectedPaths)
    if (newSet.has(medium.path)) {
      newSet.delete(medium.path)
      if (newSet.size === 0) {
        this.exitMultiSelectMode()
        return
      }
    } else {
      newSet.add(medium.path)
    }
    this.selectedPaths = newSet
    this.mediaDataSource.notifyAllChanged()
  }

  // FR-A05: Get single selected medium for rename
  private getSelectedMediumForRename(): Medium | null {
    if (this.selectedPaths.size !== 1) {
      return null
    }
    const selectedPath: string = Array.from(this.selectedPaths)[0]
    for (let i: number = 0; i < this.mediaItems.length; i++) {
      if (this.mediaItems[i] instanceof Medium) {
        const m: Medium = this.mediaItems[i] as Medium
        if (m.path === selectedPath) {
          return m
        }
      }
    }
    return null
  }

  private renameSelectedMedia(newName: string): void {
    const medium: Medium | null = this.getSelectedMediumForRename()
    if (medium === null) {
      return
    }
    FileOperations.renameFile(medium.path, newName).then((success: boolean): void => {
      if (success) {
        console.info('[MediaPage] renamed to ' + newName)
        this.getUIContext()?.getPromptAction()?.showToast({ message: 'Renamed' })
      } else {
        // D1-003: Toast on failure
        this.getUIContext()?.getPromptAction()?.showToast({ message: 'Rename failed' })
      }
      this.exitMultiSelectMode()
      this.loadMedia()
    })
  }

  private showCopyDialog(): void {
    this.copyMoveTitle = this.getStr($r('app.string.copy_to').id)
    this.copyMoveIsCopy = true
    this.copyMoveDialogController.open()
  }

  private showMoveDialog(): void {
    this.copyMoveTitle = this.getStr($r('app.string.move_to').id)
    this.copyMoveIsCopy = false
    this.copyMoveDialogController.open()
  }

  // Wave F T-072: Hide selected media's parent folder
  private hideSelectedMedia(): void {
    if (this.directoryPath.length > 0 && !this.directoryPath.startsWith('file://media')) {
      try {
        const nomediaPath: string = this.directoryPath + '/.nomedia'
        const file: fileIo.File = fileIo.openSync(nomediaPath, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY)
        fileIo.closeSync(file)
        this.getUIContext()?.getPromptAction()?.showToast({ message: '文件夹已隐藏' })
      } catch (e) {
        this.getUIContext()?.getPromptAction()?.showToast({ message: '隐藏失败' })
      }
    } else {
      this.getUIContext()?.getPromptAction()?.showToast({ message: '系统媒体库文件不支持隐藏' })
    }
    this.exitMultiSelectMode()
  }

  // Wave F T-072: Show properties of single selected media
  private showSelectedMediaProperties(): void {
    const medium: Medium | null = this.getSelectedMediumForRename()
    if (medium === null) { return }
    const lines: string[] = []
    lines.push('文件名：' + medium.name)
    lines.push('路径：' + medium.path)
    lines.push('类型：' + (medium.isVideo() ? '视频' : '图片'))
    if (medium.size > 0) {
      lines.push('大小：' + this.formatMediaSize(medium.size))
    }
    if (medium.modified > 0) {
      const d: Date = new Date(medium.modified)
      lines.push('修改时间：' + d.getFullYear().toString() + '/' +
        (d.getMonth() + 1).toString().padStart(2, '0') + '/' +
        d.getDate().toString().padStart(2, '0'))
    }
    if (medium.isVideo() && medium.videoDuration > 0) {
      const sec: number = Math.floor(medium.videoDuration / 1000)
      lines.push('时长：' + Math.floor(sec / 60).toString() + ':' + (sec % 60).toString().padStart(2, '0'))
    }
    this.getUIContext()?.getPromptAction()?.showDialog({
      title: '文件属性',
      message: lines.join('\n')
    })
  }

  private formatMediaSize(bytes: number): string {
    if (bytes < 1024) return bytes.toString() + ' B'
    if (bytes < 1048576) return (bytes / 1024).toFixed(1) + ' KB'
    if (bytes < 1073741824) return (bytes / 1048576).toFixed(1) + ' MB'
    return (bytes / 1073741824).toFixed(1) + ' GB'
  }

  // Wave F T-072: Open selected media with system app
  private openSelectedMediaWith(): void {
    const medium: Medium | null = this.getSelectedMediumForRename()
    if (medium === null) { return }
    try {
      const ctx: common.UIAbilityContext = this.getUIContext().getHostContext()! as common.UIAbilityContext
      const want: Want = {
        action: 'ohos.want.action.viewData',
        uri: medium.path,
        type: medium.isVideo() ? 'video/*' : 'image/*'
      }
      ctx.startAbility(want).catch((): void => {
        this.getUIContext()?.getPromptAction()?.showToast({ message: '无法打开' })
      })
    } catch (e) {
      this.getUIContext()?.getPromptAction()?.showToast({ message: '无法打开' })
    }
    this.exitMultiSelectMode()
  }

  private executeCopyMove(destFolder: string): void {
    if (this.selectedPaths.size === 0) {
      return
    }
    const paths: string[] = Array.from(this.selectedPaths)
    if (this.copyMoveIsCopy) {
      FileOperations.copyFiles(paths, destFolder).then((count: number): void => {
        console.info('[MediaPage] copied ' + count.toString() + ' items')
        this.getUIContext()?.getPromptAction()?.showToast({ message: count.toString() + ' items copied' })
        this.exitMultiSelectMode()
        this.loadMedia()
      })
    } else {
      FileOperations.moveFiles(paths, destFolder).then((count: number): void => {
        console.info('[MediaPage] moved ' + count.toString() + ' items')
        this.getUIContext()?.getPromptAction()?.showToast({ message: count.toString() + ' items moved' })
        this.exitMultiSelectMode()
        this.loadMedia()
      })
    }
  }

  // FR-A05: Build overflow menu items for MediaPage multi-select CAB
  private buildMultiSelectMenu(): Array<MediaMenuItem> {
    const items: Array<MediaMenuItem> = []
    // Rename — only when single item selected
    if (this.selectedPaths.size === 1) {
      items.push({
        value: this.getStr($r('app.string.rename').id),
        action: (): void => {
          this.renameDialogController.open()
        }
      } as MediaMenuItem)
    }
    // Copy to
    items.push({
      value: this.getStr($r('app.string.copy_to').id),
      action: (): void => {
        this.showCopyDialog()
      }
    } as MediaMenuItem)
    // Move to
    items.push({
      value: this.getStr($r('app.string.move_to').id),
      action: (): void => {
        this.showMoveDialog()
      }
    } as MediaMenuItem)
    // Wave F T-072: Hide selected files' parent folder
    items.push({
      value: this.getStr($r('app.string.hide').id),
      action: (): void => {
        this.hideSelectedMedia()
      }
    } as MediaMenuItem)
    // Properties — single select only
    if (this.selectedPaths.size === 1) {
      items.push({
        value: this.getStr($r('app.string.details').id),
        action: (): void => {
          this.showSelectedMediaProperties()
        }
      } as MediaMenuItem)
      // Open with
      items.push({
        value: '打开方式',
        action: (): void => {
          this.openSelectedMediaWith()
        }
      } as MediaMenuItem)
    }
    return items
  }

  // BUG-034: Refresh only isFavorite states without full data reload.
  // Called on onPageShow to sync favorite changes made in ViewingPage.
  private refreshFavoriteStates(): void {
    try {
      const favDao: FavoritesDao = new FavoritesDao()
      let favContext: Context | undefined = undefined
      try { favContext = this.getUIContext().getHostContext()! } catch (e) { /* */ }
      if (favContext === undefined) { return }
      favDao.getValidatedPaths(favContext).then((favPaths: Array<string>): void => {
        const favSet: Set<string> = new Set<string>(favPaths)
        let changed: boolean = false
        // PAT-011b: Must replace items (not mutate) so @Prop detects change
        const newItems: ThumbnailItem[] = []
        for (let i: number = 0; i < this.mediaItems.length; i++) {
          if (this.mediaItems[i] instanceof Medium) {
            const old: Medium = this.mediaItems[i] as Medium
            const shouldBeFav: boolean = favSet.has(old.path)
            if (old.isFavorite !== shouldBeFav) {
              // Create new Medium with updated isFavorite
              const updated: Medium = new Medium(
                old.id, old.name, old.path, old.parentPath,
                old.modified, old.taken, old.size, old.type,
                old.videoDuration, shouldBeFav, old.deletedTS, old.mediaStoreId
              )
              newItems.push(updated)
              changed = true
            } else {
              newItems.push(old)
            }
          } else {
            newItems.push(this.mediaItems[i])
          }
        }
        if (changed) {
          this.mediaItems = newItems
          this.mediaDataSource.setItems(this.mediaItems)
        }
      })
    } catch (e) {
      // DB not ready — skip
    }
  }

  // T-081: Two-phase loading — fast first page, then background full load
  async loadMedia(): Promise<void> {
    this.isLoading = true
    this.loadedCount = 0
    this.allMediaCache = []
    try {
      const scanner: MediaScanner = new MediaScanner(this.getUIContext().getHostContext()!)
      const config: ConfigManager = ConfigManager.getInstance()

      // Phase 1: Fast first page (limit=100)
      const firstPage: Medium[] = await scanner.getFilesFrom(
        this.directoryPath, config.filterMedia,
        this.currentSorting, this.pageSize
      )
      this.allMediaCache = firstPage
      this.loadPage(true)
      this.isLoading = false

      // Phase 2: Background full load (no limit)
      const allMedia: Medium[] = await scanner.getFilesFrom(
        this.directoryPath, config.filterMedia,
        this.currentSorting
      )
      this.allMediaCache = allMedia
      console.info('[MediaPage] loadMedia: total=' + allMedia.length.toString())
    } catch (e) {
      console.error('Failed to load media')
      this.isLoading = false
    }
    this.isRefreshing = false
  }

  // T-081: Load a page of items from allMediaCache into mediaItems
  private loadPage(isFirst: boolean): void {
    const end: number = Math.min(this.loadedCount + this.pageSize, this.allMediaCache.length)
    if (isFirst) {
      const firstPage: Medium[] = this.allMediaCache.slice(0, end)
      const groupBy: number = this.currentGrouping
      const showCount: boolean = (groupBy & GROUP_SHOW_FILE_COUNT) !== 0
      this.mediaItems = MediaGrouper.insertGroupHeaders(firstPage, groupBy, showCount)
      this.mediaDataSource.setItems(this.mediaItems)
    } else {
      // Append next page — add raw items without re-grouping for speed
      for (let i: number = this.loadedCount; i < end; i++) {
        this.mediaItems.push(this.allMediaCache[i])
      }
      this.mediaDataSource.setItems(this.mediaItems)
    }
    this.loadedCount = end
  }

  // T-081: Load more when scrolled to bottom
  private loadMore(): void {
    if (this.isLoadingMore || this.loadedCount >= this.allMediaCache.length) {
      return
    }
    this.isLoadingMore = true
    this.loadPage(false)
    this.isLoadingMore = false
  }

  showSortPicker(): void {
    const currentBase: number = this.currentSorting & ~SORT_DESCENDING
    const isDesc: boolean = (this.currentSorting & SORT_DESCENDING) !== 0

    const s1: string = currentBase === SORT_BY_NAME ? ' ✓' : ''
    const s2: string = currentBase === SORT_BY_DATE_MODIFIED ? ' ✓' : ''
    const s3: string = currentBase === SORT_BY_SIZE ? ' ✓' : ''
    const s4: string = currentBase === SORT_BY_DATE_TAKEN ? ' ✓' : ''
    const buttons: Array<DialogButtonInfo> = [
      { text: this.getStr($r('app.string.sort_name').id) + s1, color: '#007DFF' },
      { text: this.getStr($r('app.string.sort_date_modified').id) + s2, color: '#007DFF' },
      { text: this.getStr($r('app.string.sort_size').id) + s3, color: '#007DFF' },
      { text: this.getStr($r('app.string.sort_date_taken').id) + s4, color: '#007DFF' }
    ]
    const sortBases: number[] = [SORT_BY_NAME, SORT_BY_DATE_MODIFIED, SORT_BY_SIZE, SORT_BY_DATE_TAKEN]
    const defaultDescs: boolean[] = [false, true, true, true]

    this.getUIContext()?.getPromptAction()?.showDialog({
      title: this.getStr($r('app.string.sort_by').id),
      message: '',
      buttons: buttons
    }).then((result: ShowDialogSuccessResponse) => {
      const idx: number = result.index
      if (idx >= 0 && idx < sortBases.length) {
        const toggleDesc: boolean = currentBase === sortBases[idx] ? !isDesc : defaultDescs[idx]
        this.applySorting(sortBases[idx], toggleDesc)
      }
    })
  }

  applySorting(sortBase: number, descending: boolean): void {
    const newSorting: number = descending ? (sortBase | SORT_DESCENDING) : sortBase
    this.currentSorting = newSorting
    const config: ConfigManager = ConfigManager.getInstance()
    config.directorySorting = newSorting
    this.loadMedia()
  }

  showGroupPicker(): void {
    const baseGrouping: number = this.currentGrouping & ~GROUP_SHOW_FILE_COUNT

    const g1: string = baseGrouping === GROUP_BY_NONE ? ' ✓' : ''
    const g2: string = baseGrouping === GROUP_BY_LAST_MODIFIED_DAILY ? ' ✓' : ''
    const g3: string = baseGrouping === GROUP_BY_LAST_MODIFIED_MONTHLY ? ' ✓' : ''
    const g4: string = baseGrouping === GROUP_BY_DATE_TAKEN_DAILY ? ' ✓' : ''
    const g5: string = baseGrouping === GROUP_BY_DATE_TAKEN_MONTHLY ? ' ✓' : ''
    const g6: string = baseGrouping === GROUP_BY_FILE_TYPE ? ' ✓' : ''
    const buttons: Array<DialogButtonInfo> = [
      { text: this.getStr($r('app.string.no_grouping').id) + g1, color: '#007DFF' },
      { text: this.getStr($r('app.string.by_last_modified_daily').id) + g2, color: '#007DFF' },
      { text: this.getStr($r('app.string.by_last_modified_monthly').id) + g3, color: '#007DFF' },
      { text: this.getStr($r('app.string.by_date_taken_daily').id) + g4, color: '#007DFF' },
      { text: this.getStr($r('app.string.by_date_taken_monthly').id) + g5, color: '#007DFF' },
      { text: this.getStr($r('app.string.by_file_type').id) + g6, color: '#007DFF' }
    ]
    const groupBases: number[] = [GROUP_BY_NONE, GROUP_BY_LAST_MODIFIED_DAILY, GROUP_BY_LAST_MODIFIED_MONTHLY,
      GROUP_BY_DATE_TAKEN_DAILY, GROUP_BY_DATE_TAKEN_MONTHLY, GROUP_BY_FILE_TYPE]

    this.getUIContext()?.getPromptAction()?.showDialog({
      title: this.getStr($r('app.string.group_by').id),
      message: '',
      buttons: buttons
    }).then((result: ShowDialogSuccessResponse) => {
      const idx: number = result.index
      if (idx >= 0 && idx < groupBases.length) {
        this.applyGrouping(groupBases[idx])
      }
    })
  }

  applyGrouping(groupBase: number): void {
    this.currentGrouping = groupBase
    const config: ConfigManager = ConfigManager.getInstance()
    config.saveFolderGrouping(this.directoryPath, groupBase)
    this.loadMedia()
  }

  private navigateToViewing(index: number): void {
    // Videos and images both use the in-app ViewingPage (which contains VideoViewer)
    // PIT-053: system player can't handle photoAccessHelper URIs, so we always use in-app viewer

    // Build a lightweight list of media-only items (exclude ThumbnailSection headers)
    const mediaOnly: Medium[] = []
    for (let i: number = 0; i < this.mediaItems.length; i++) {
      if (this.mediaItems[i] instanceof Medium) {
        mediaOnly.push(this.mediaItems[i] as Medium)
      }
    }

    // Find the actual index in the media-only list
    let mediaIndex: number = 0
    let count: number = 0
    for (let i: number = 0; i < this.mediaItems.length; i++) {
      if (this.mediaItems[i] instanceof Medium) {
        if (i === index) {
          mediaIndex = count
          break
        }
        count++
      }
    }

    // Serialize for router params
    const serialized: Object[] = []
    for (let i: number = 0; i < mediaOnly.length; i++) {
      const m: Medium = mediaOnly[i]
      const obj: Record<string, Object> = {} as Record<string, Object>
      obj['id'] = m.id
      obj['name'] = m.name
      obj['path'] = m.path
      obj['parentPath'] = m.parentPath
      obj['modified'] = m.modified
      obj['taken'] = m.taken
      obj['size'] = m.size
      obj['type'] = m.type
      obj['videoDuration'] = m.videoDuration
      obj['isFavorite'] = m.isFavorite
      obj['deletedTS'] = m.deletedTS
      obj['mediaStoreId'] = m.mediaStoreId
      serialized.push(obj)
    }

    try {
      const navParams: ViewingPageParams = { mediaListJson: JSON.stringify(serialized), selectedIndex: mediaIndex, folderPath: this.directoryPath }
      router.pushUrl({ url: 'pages/ViewingPage', params: navParams })
    } catch (e) {
      console.error('Navigation to ViewingPage failed')
    }
  }

  private openVideoInSystemPlayer(medium: Medium): void {
    try {
      const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext
      // Try system Photos app directly to avoid chooser dialog
      const want: Want = {
        bundleName: 'com.huawei.hmos.photos',
        uri: medium.path,
        type: 'video/*'
      }
      context.startAbility(want).then(() => {
        console.info('[MediaPage] Opened video in system Photos app: ' + medium.path)
      }).catch((err: Error) => {
        console.warn('[MediaPage] System Photos app failed, trying viewData action: ' + err.message)
        // Fallback: use viewData action without bundleName
        this.openVideoWithViewDataAction(medium)
      })
    } catch (e) {
      console.error('[MediaPage] startAbility error: ' + (e as Error).message)
      this.openVideoWithViewDataAction(medium)
    }
  }

  private openVideoWithViewDataAction(medium: Medium): void {
    try {
      const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext
      const want: Want = {
        action: 'ohos.want.action.viewData',
        uri: medium.path,
        type: 'video/*',
        parameters: {
          'ability.want.params.CONTENT_TITLE': medium.name
        }
      }
      context.startAbility(want).then(() => {
        console.info('[MediaPage] Opened video with viewData action: ' + medium.path)
      }).catch((err: Error) => {
        console.error('[MediaPage] viewData action also failed: ' + err.message)
        // Final fallback: in-app player
        this.navigateToViewingForVideo(medium)
      })
    } catch (e) {
      console.error('[MediaPage] viewData startAbility error: ' + (e as Error).message)
      this.navigateToViewingForVideo(medium)
    }
  }

  private navigateToViewingForVideo(medium: Medium): void {
    const serialized: Object[] = []
    const obj: Record<string, Object> = {} as Record<string, Object>
    obj['id'] = medium.id
    obj['name'] = medium.name
    obj['path'] = medium.path
    obj['parentPath'] = medium.parentPath
    obj['modified'] = medium.modified
    obj['taken'] = medium.taken
    obj['size'] = medium.size
    obj['type'] = medium.type
    obj['videoDuration'] = medium.videoDuration
    obj['isFavorite'] = medium.isFavorite
    obj['deletedTS'] = medium.deletedTS
    obj['mediaStoreId'] = medium.mediaStoreId
    serialized.push(obj)
    try {
      const navParams: ViewingPageParams = { mediaListJson: JSON.stringify(serialized), selectedIndex: 0, folderPath: this.directoryPath }
      router.pushUrl({ url: 'pages/ViewingPage', params: navParams })
    } catch (e) {
      console.error('Fallback navigation to ViewingPage failed')
    }
  }

  build() {
    Column() {
      // Title bar with back button and menu
      Row() {
        if (this.isMultiSelectMode) {
          // Multi-select toolbar: ← close + "N / total" + share + delete + select all
          Image($r('sys.media.ohos_ic_back'))
            .width(24).height(24)
            .onClick(() => {
              this.exitMultiSelectMode()
            })
          Text(`已选择 ${this.selectedPaths.size} / ${this.getTotalMediaCount()}`)
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.ohos_id_color_text_primary'))
            .margin({ left: 16 })
            .layoutWeight(1)

          // Share button (FR-A05: always visible)
          Image($r('sys.media.ohos_ic_public_share'))
            .width(24).height(24)
            .margin({ right: 12 })
            .onClick(() => {
              this.shareSelectedMedia()
            })

          // Delete button — system createDeleteRequest shows its own confirmation UI,
          // so we skip our custom dialog to avoid double-popup (BUG-R7-1)
          Text('删除')
            .fontSize(14)
            .fontColor($r('sys.color.ohos_id_color_text_primary'))
            .margin({ right: 12 })
            .onClick(() => {
              this.deleteSelectedMedia(false)
            })

          // Select all button
          Text('全选')
            .fontSize(16)
            .fontColor('#007DFF')
            .margin({ right: 4 })
            .onClick(() => {
              this.selectAll()
            })

          // Overflow menu: rename (single), copy, move (FR-A05)
          Button() {
            Image($r('sys.media.ohos_ic_public_more'))
              .width(20).height(20)
          }
          .backgroundColor($r('sys.color.ohos_id_color_background_transparent'))
          .width(36)
          .height(36)
          .bindMenu(this.buildMultiSelectMenu())
        } else {
          Image($r('sys.media.ohos_ic_back'))
            .width(24).height(24)
            .onClick(() => {
              router.back()
            })
          Text(this.directoryName)
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .margin({ left: 16 })
            .layoutWeight(1)
          Image($r('sys.media.ohos_ic_public_more'))
            .width(24).height(24)
            .bindMenu(this.buildToolbarMenu())
        }
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })

      if (this.isLoading && !this.isRefreshing) {
        LoadingProgress().width(48).height(48).margin({ top: 100 })
      } else if (this.mediaItems.length === 0) {
        Text($r('app.string.no_media_in_folder'))
          .fontSize(16).margin({ top: 100 })
      } else {
        Refresh({ refreshing: $$this.isRefreshing }) {
          if (this.viewType === VIEW_TYPE_GRID) {
            this.buildGridView()
          } else {
            this.buildListView()
          }
        }
        .onRefreshing(() => {
          this.loadMedia()
        })
      }
    }
    .width('100%')
    .height('100%')
  }

  private buildToolbarMenu(): Array<MediaMenuItem> {
    const items: Array<MediaMenuItem> = []
    items.push({
      value: this.getStr($r('app.string.sort').id),
      action: (): void => {
        this.showSortPicker()
      }
    })
    items.push({
      value: this.getStr($r('app.string.group').id),
      action: (): void => {
        this.showGroupPicker()
      }
    })
    return items
  }

  @Builder
  buildGridView() {
    Grid() {
      LazyForEach(this.mediaDataSource, (item: Object, index: number) => {
        GridItem() {
          if (item instanceof ThumbnailSection) {
            Text((item as ThumbnailSection).title)
              .fontSize(14)
              .fontColor($r('sys.color.ohos_id_color_text_secondary'))
              .width('100%')
              .padding({ left: 8, top: 12, bottom: 4 })
          } else if (item instanceof Medium) {
            Stack() {
              MediaItem({
                medium: item as Medium,
                showFileName: this.displayFileNames
              })
              if (this.isMultiSelectMode && this.selectedPaths.has((item as Medium).path)) {
                // Selection checkmark overlay — top-right, only shown on selected items
                Stack({ alignContent: Alignment.Center }) {
                  Circle()
                    .width(24).height(24)
                    .fill('#007DFF')
                  Image($r('sys.media.ohos_ic_public_ok'))
                    .width(14).height(14)
                    .fillColor(Color.White)
                }
                .position({ right: 6, top: 6 })
              }
            }
            .priorityGesture(
              GestureGroup(GestureMode.Exclusive,
                LongPressGesture({ repeat: false, duration: 500 })
                  .onAction(() => {
                    if (!this.isMultiSelectMode) {
                      this.enterMultiSelectMode(item as Medium)
                    }
                  }),
                TapGesture()
                  .onAction(() => {
                    if (this.isMultiSelectMode) {
                      this.toggleSelection(item as Medium)
                    } else {
                      this.navigateToViewing(index)
                    }
                  })
              )
            )
          }
        }
      }, (item: Object, index: number): string => {
        if (item instanceof Medium) {
          return (item as Medium).path + '_fav' + (item as Medium).isFavorite.toString()
        } else if (item instanceof ThumbnailSection) {
          return 'section_' + index.toString()
        }
        return index.toString()
      })
    }
    .columnsTemplate(this.buildColumnsTemplate())
    .columnsGap(2)
    .rowsGap(2)
    .width('100%')
    .layoutWeight(1)
    .cachedCount(3)
    // T-081: Load more on scroll to bottom
    .onReachEnd((): void => {
      this.loadMore()
    })
  }

  @Builder
  buildListView() {
    List() {
      LazyForEach(this.mediaDataSource, (item: Object, index: number) => {
        ListItem() {
          if (item instanceof ThumbnailSection) {
            Text((item as ThumbnailSection).title)
              .fontSize(14)
              .fontColor($r('sys.color.ohos_id_color_text_secondary'))
              .width('100%')
              .padding({ left: 16, top: 12, bottom: 4 })
          } else if (item instanceof Medium) {
            Row() {
              if (this.isMultiSelectMode) {
                // Selection checkmark — only shown as blue check on selected, empty circle on unselected
                Stack({ alignContent: Alignment.Center }) {
                  if (this.selectedPaths.has((item as Medium).path)) {
                    Circle()
                      .width(24).height(24)
                      .fill('#007DFF')
                    Image($r('sys.media.ohos_ic_public_ok'))
                      .width(14).height(14)
                      .fillColor(Color.White)
                  }
                }
                .width(24).height(24)
                .margin({ left: 12, right: 4 })
              }
              MediaItem({
                medium: item as Medium,
                showFileName: this.displayFileNames,
                isListMode: true
              })
                .layoutWeight(1)
            }
            .width('100%')
            .priorityGesture(
              GestureGroup(GestureMode.Exclusive,
                LongPressGesture({ repeat: false, duration: 500 })
                  .onAction(() => {
                    if (!this.isMultiSelectMode) {
                      this.enterMultiSelectMode(item as Medium)
                    }
                  }),
                TapGesture()
                  .onAction(() => {
                    if (this.isMultiSelectMode) {
                      this.toggleSelection(item as Medium)
                    } else {
                      this.navigateToViewing(index)
                    }
                  })
              )
            )
          }
        }
      }, (item: Object, index: number): string => {
        if (item instanceof Medium) {
          return (item as Medium).path + '_fav' + (item as Medium).isFavorite.toString()
        }
        return 'section_' + index.toString()
      })
    }
    .width('100%')
    .layoutWeight(1)
    .cachedCount(3)
    .onReachEnd((): void => {
      this.loadMore()
    })
  }

  buildColumnsTemplate(): string {
    let template: string = ''
    for (let i: number = 0; i < this.columnCount; i++) {
      if (i > 0) {
        template += ' '
      }
      template += '1fr'
    }
    return template
  }
}
