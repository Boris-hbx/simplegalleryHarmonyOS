import { router } from '@kit.ArkUI'
import { Directory } from '../common/models/Directory'
import { Medium } from '../common/models/Medium'
import { VIEW_TYPE_GRID, VIEW_TYPE_LIST, MAX_COLUMN_COUNT, RECYCLE_BIN, FAVORITES } from '../common/constants/Constants'
import { MediaScanner } from '../media/MediaScanner'
import { ConfigManager } from '../datastore/ConfigManager'
import { DirectoryItem } from '../components/DirectoryItem'
import { DirectoryDataSource } from '../viewmodel/DirectoryDataSource'
import { MediaItem } from '../components/MediaItem'
import { SortDialog } from '../components/SortDialog'
import { FilterDialog } from '../components/FilterDialog'
import { DateGroup, groupMediaByDate } from '../common/utils/DateGroupUtils'
import { FileOperations } from '../utils/FileOperations'
import { DeleteConfirmDialog, RenameDialog, CopyMoveDialog } from '../components/FileOpDialogs'
import { fileIo } from '@kit.CoreFileKit'

interface MediaPageParams {
  directoryPath: string
  directoryName: string
}

// T-065: Menu item interface for CAB overflow menu
interface DirMenuItem {
  value: string
  action: () => void
}

interface ViewingPageParams {
  mediaListJson: string
  selectedIndex: number
  folderPath: string
}

@Entry
@Component
struct MainPage {
  @State directories: Directory[] = []
  @State filteredDirs: Directory[] = []
  @State isLoading: boolean = true
  @State viewType: number = VIEW_TYPE_GRID
  @State columnCount: number = 3
  @State isEmpty: boolean = false
  @State isSearching: boolean = false
  @State searchQuery: string = ''
  @State currentSorting: number = 0
  @State currentFilter: number = 0
  @State tempShowHidden: boolean = false
  @State tempShowExcluded: boolean = false
  @State showAllMode: boolean = false
  @State dateGroups: DateGroup[] = []
  @State allMedia: Medium[] = []
  @State isMultiSelectMode: boolean = false
  @State selectedPaths: Set<string> = new Set<string>()

  private scanner: MediaScanner | null = null
  private hasNavigatedToDefault: boolean = false
  private dirDataSource: DirectoryDataSource = new DirectoryDataSource()

  private getStr(resId: number): string {
    try {
      return getContext(this).resourceManager.getStringSync(resId)
    } catch (e) {
      return ''
    }
  }

  private sortDialogController: CustomDialogController = new CustomDialogController({
    builder: SortDialog({
      currentSorting: this.currentSorting,
      onSortChanged: (sorting: number) => {
        this.handleSortChanged(sorting)
      }
    }),
    autoCancel: true,
    alignment: DialogAlignment.Center
  })

  private filterDialogController: CustomDialogController = new CustomDialogController({
    builder: FilterDialog({
      currentFilter: this.currentFilter,
      onFilterChanged: (filter: number) => {
        this.handleFilterChanged(filter)
      }
    }),
    autoCancel: true,
    alignment: DialogAlignment.Center
  })

  private deleteConfirmDialogController: CustomDialogController = new CustomDialogController({
    builder: DeleteConfirmDialog({
      fileCount: this.selectedPaths.size,
      onConfirm: (skipRecycleBin: boolean) => {
        this.deleteSelectedFolders(skipRecycleBin)
      }
    }),
    autoCancel: true,
    alignment: DialogAlignment.Center
  })

  private renameDialogController: CustomDialogController = new CustomDialogController({
    builder: RenameDialog({
      currentName: this.getSelectedDirForRename()?.name ?? '',
      onConfirm: (newName: string) => {
        this.renameSelectedFolder(newName)
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

  aboutToAppear(): void {
    const config: ConfigManager = ConfigManager.getInstance()
    this.viewType = config.viewTypeFolders
    this.columnCount = config.dirColumnCnt
    this.currentSorting = config.directorySorting
    this.currentFilter = config.filterMedia
    this.showAllMode = config.showAll
    if (this.showAllMode) {
      this.loadAllMedia()
    } else {
      this.loadDirectories()
    }

    // FR-039: Auto-navigate to default folder on cold start
    const defaultFolder: string = config.defaultFolder
    if (defaultFolder.length > 0 && !this.hasNavigatedToDefault) {
      this.hasNavigatedToDefault = true
      this.navigateToFolder(defaultFolder, defaultFolder)
    }
  }

  onPageShow(): void {
    // BUG-037: Incremental refresh — update counts/thumbnails for ALL folders
    // without changing order (prevents BUG-036 reorder + data mismatch).
    this.refreshAllDirCounts()
  }

  // BUG-037: Incremental refresh for ALL folders — update mediaCnt + tmb
  // without reordering. Scans fresh directories, matches by path, replaces changed ones.
  private refreshAllDirCounts(): void {
    let ctx: Context | undefined = undefined
    try { ctx = this.getUIContext().getHostContext()! } catch (e) { /* */ }
    if (ctx === undefined) { return }

    const config: ConfigManager = ConfigManager.getInstance()
    const scanner: MediaScanner = new MediaScanner(ctx)

    // Get fresh directory data (for counts/thumbnails) + favorites folder
    scanner.getDirectories(config.filterMedia, config.directorySorting).then(async (freshDirs: Directory[]): Promise<void> => {
      // Also get favorites folder
      const favDir: Directory | null = await scanner.getFavoritesFolder()

      // Build a lookup map: path → fresh Directory
      const freshMap: Map<string, Directory> = new Map<string, Directory>()
      for (let i: number = 0; i < freshDirs.length; i++) {
        freshMap.set(freshDirs[i].path, freshDirs[i])
      }
      if (favDir !== null) {
        favDir.name = '收藏'
        freshMap.set(favDir.path, favDir)
      }

      // Walk existing list, replace items whose count/tmb changed (PIT-033: new objects)
      let changed: boolean = false
      const newDirs: Directory[] = []
      for (let i: number = 0; i < this.filteredDirs.length; i++) {
        const old: Directory = this.filteredDirs[i]
        const fresh: Directory | undefined = freshMap.get(old.path)
        if (fresh !== undefined && (old.mediaCnt !== fresh.mediaCnt || old.tmb !== fresh.tmb)) {
          // Create replacement with fresh count/tmb but keep display name
          const updated: Directory = new Directory(
            old.id, old.path, fresh.tmb, old.name,
            fresh.mediaCnt, fresh.modified, fresh.taken, fresh.size,
            old.location, fresh.types, old.sortValue
          )
          newDirs.push(updated)
          changed = true
        } else if (fresh === undefined && old.areFavorites()) {
          // Favorites folder no longer has content — remove it
          changed = true
          // skip (don't push)
        } else {
          newDirs.push(old)
        }
      }

      // Check if favorites folder should be added (wasn't in list before)
      if (favDir !== null && favDir.mediaCnt > 0) {
        let hasFav: boolean = false
        for (let i: number = 0; i < newDirs.length; i++) {
          if (newDirs[i].areFavorites()) {
            hasFav = true
            break
          }
        }
        if (!hasFav) {
          newDirs.push(favDir)
          changed = true
        }
      }

      if (changed) {
        this.filteredDirs = newDirs
        this.dirDataSource.setData(newDirs)
      }
    }).catch((): void => {
      // Scan failed — keep current data
    })
  }

  onPageHide(): void {
    // FR-027: Auto-restore temp show hidden/excluded after leaving
    if (this.tempShowHidden || this.tempShowExcluded) {
      this.tempShowHidden = false
      this.tempShowExcluded = false
      const config: ConfigManager = ConfigManager.getInstance()
      config.temporarilyShowHidden = false
      config.temporarilyShowExcluded = false
    }
  }

  navigateToFolder(dirPath: string, dirName: string): void {
    try {
      const navParams: MediaPageParams = { directoryPath: dirPath, directoryName: dirName }
      router.pushUrl({ url: 'pages/MediaPage', params: navParams })
    } catch (e) {
      console.error('Navigation failed: ' + JSON.stringify(e))
    }
  }

  private enterMultiSelectMode(dir: Directory): void {
    this.isMultiSelectMode = true
    const newSet: Set<string> = new Set<string>()
    newSet.add(dir.path)
    this.selectedPaths = newSet
    // Round6-Fix8: Notify LazyForEach to re-evaluate items with new isSelected props
    this.dirDataSource.notifyAllChanged()
  }

  private exitMultiSelectMode(): void {
    this.isMultiSelectMode = false
    this.selectedPaths = new Set<string>()
    // Round6-Fix8: Notify LazyForEach to re-evaluate items with new isSelected props
    this.dirDataSource.notifyAllChanged()
  }

  private toggleDirSelection(dir: Directory): void {
    const newSet: Set<string> = new Set<string>(this.selectedPaths)
    if (newSet.has(dir.path)) {
      newSet.delete(dir.path)
      if (newSet.size === 0) {
        this.exitMultiSelectMode()
        return
      }
    } else {
      newSet.add(dir.path)
    }
    this.selectedPaths = newSet
    // Round6-Fix8: Notify LazyForEach to re-evaluate items with new isSelected props
    this.dirDataSource.notifyAllChanged()
  }

  private selectAllDirs(): void {
    const newSet: Set<string> = new Set<string>()
    for (let i: number = 0; i < this.filteredDirs.length; i++) {
      newSet.add(this.filteredDirs[i].path)
    }
    this.selectedPaths = newSet
    // Round6-Fix8: Notify LazyForEach to re-evaluate items with new isSelected props
    this.dirDataSource.notifyAllChanged()
  }

  private togglePinSelectedFolders(): void {
    if (this.selectedPaths.size === 0) {
      return
    }
    const config: ConfigManager = ConfigManager.getInstance()
    const currentPinned: Set<string> = config.pinnedFolders
    // Determine if we should pin or unpin: if ALL selected are already pinned, unpin them; otherwise pin them
    let allPinned: boolean = true
    this.selectedPaths.forEach((path: string) => {
      if (!currentPinned.has(path)) {
        allPinned = false
      }
    })
    if (allPinned) {
      config.removePinnedFolders(this.selectedPaths)
    } else {
      config.addPinnedFolders(this.selectedPaths)
    }
    this.exitMultiSelectMode()
    this.loadDirectories()
  }

  // FR-A04: Hide selected folders by creating .nomedia file (like Android)
  private hideSelectedFolders(): void {
    if (this.selectedPaths.size === 0) {
      return
    }
    this.selectedPaths.forEach((folderPath: string) => {
      try {
        const nomediaPath: string = folderPath + '/.nomedia'
        const file: fileIo.File = fileIo.openSync(nomediaPath, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY)
        fileIo.closeSync(file)
      } catch (e) {
        console.error('[MainPage] hideSelectedFolders: failed to create .nomedia in ' + folderPath)
      }
    })
    this.exitMultiSelectMode()
    this.loadDirectories()
  }

  private excludeSelectedFolders(): void {
    if (this.selectedPaths.size === 0) {
      return
    }
    const config: ConfigManager = ConfigManager.getInstance()
    config.addExcludedFolders(this.selectedPaths)
    this.exitMultiSelectMode()
    this.loadDirectories()
  }

  private getSelectedDirForRename(): Directory | null {
    if (this.selectedPaths.size !== 1) {
      return null
    }
    const selectedPath: string = Array.from(this.selectedPaths)[0]
    for (let i: number = 0; i < this.filteredDirs.length; i++) {
      if (this.filteredDirs[i].path === selectedPath) {
        return this.filteredDirs[i]
      }
    }
    return null
  }

  private renameSelectedFolder(newName: string): void {
    const dir: Directory | null = this.getSelectedDirForRename()
    if (dir === null) {
      return
    }
    FileOperations.renameFile(dir.path, newName).then((success: boolean): void => {
      if (success) {
        console.info('[MainPage] renameSelectedFolder: renamed to ' + newName)
      } else {
        console.error('[MainPage] renameSelectedFolder: rename failed')
      }
      this.exitMultiSelectMode()
      this.loadDirectories()
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

  private executeCopyMove(destFolder: string): void {
    if (this.selectedPaths.size === 0) {
      return
    }
    const paths: string[] = Array.from(this.selectedPaths)
    if (this.copyMoveIsCopy) {
      FileOperations.copyFiles(paths, destFolder).then((count: number): void => {
        console.info('[MainPage] copied ' + count.toString() + ' items')
        // OPT-004: Toast feedback
        this.getUIContext()?.getPromptAction()?.showToast({ message: count.toString() + ' items copied' })
        this.exitMultiSelectMode()
        this.loadDirectories()
      })
    } else {
      FileOperations.moveFiles(paths, destFolder).then((count: number): void => {
        console.info('[MainPage] moved ' + count.toString() + ' items')
        // OPT-004: Toast feedback
        this.getUIContext()?.getPromptAction()?.showToast({ message: count.toString() + ' items moved' })
        this.exitMultiSelectMode()
        this.loadDirectories()
      })
    }
  }

  private deleteSelectedFolders(skipRecycleBin: boolean): void {
    if (this.selectedPaths.size === 0) {
      return
    }

    // BUG-R6B-9: Remove from current display list immediately (UI-level delete).
    // Internal DB has no records for photoAccessHelper media, so SQL matches 0 rows.
    const removedPaths: Set<string> = new Set<string>(this.selectedPaths)
    const newFilteredDirs: Directory[] = []
    for (let i: number = 0; i < this.filteredDirs.length; i++) {
      if (!removedPaths.has(this.filteredDirs[i].path)) {
        newFilteredDirs.push(this.filteredDirs[i])
      }
    }
    const newDirectories: Directory[] = []
    for (let i: number = 0; i < this.directories.length; i++) {
      if (!removedPaths.has(this.directories[i].path)) {
        newDirectories.push(this.directories[i])
      }
    }
    this.filteredDirs = newFilteredDirs
    this.directories = newDirectories
    this.dirDataSource.setData(this.filteredDirs)
    this.exitMultiSelectMode()
    console.info('[MainPage] deleteSelectedFolders: removed ' + removedPaths.size.toString() + ' folders from UI')

    // Best-effort: try system DB delete (may match 0 rows — that's OK)
    const allMediaPaths: string[] = Array.from(removedPaths)
    const useRecycleBin: boolean = !skipRecycleBin
    let deleteContext: Context | undefined = undefined
    try {
      deleteContext = this.getUIContext().getHostContext()!
    } catch (e) {
      // Context unavailable
    }
    FileOperations.deleteFiles(allMediaPaths, useRecycleBin, deleteContext).catch((): void => {
      console.warn('[MainPage] deleteSelectedFolders: system delete failed (expected for photoAccessHelper media)')
    })
  }

  private getSelectedDirCount(): number {
    return this.selectedPaths.size
  }

  private getTotalDirCount(): number {
    return this.filteredDirs.length
  }

  async loadDirectories(): Promise<void> {
    this.isLoading = true
    try {
      this.scanner = new MediaScanner(this.getUIContext().getHostContext()!)
      const config: ConfigManager = ConfigManager.getInstance()
      let dirs: Directory[] = await this.scanner.getDirectories(
        config.filterMedia, config.directorySorting
      )

      // FR-024: Inject Favorites virtual folder with localized name
      const favDir: Directory | null = await this.scanner.getFavoritesFolder()
      if (favDir !== null) {
        favDir.name = '收藏'
        dirs.push(favDir)
      }

      // FR-024: Inject Recycle Bin virtual folder
      if (config.useRecycleBin && config.showRecycleBinAtFolders) {
        const recycleBinDir: Directory | null = await this.scanner.getRecycleBinFolder()
        if (recycleBinDir !== null) {
          if (config.showRecycleBinLast) {
            dirs.push(recycleBinDir)
          } else {
            dirs.unshift(recycleBinDir)
          }
        }
      }

      // FR-022: Sort pinned folders to top
      dirs = this.applyPinning(dirs)

      this.directories = dirs
      this.applySearchFilter()
      this.isEmpty = dirs.length === 0
    } catch (e) {
      console.error('Failed to load directories')
    }
    this.isLoading = false
  }

  applyPinning(dirs: Directory[]): Directory[] {
    const config: ConfigManager = ConfigManager.getInstance()
    const pinned: Set<string> = config.pinnedFolders
    const pinnedDirs: Directory[] = []
    const normalDirs: Directory[] = []
    for (let i: number = 0; i < dirs.length; i++) {
      const dir: Directory = dirs[i]
      if (pinned.has(dir.path) || dir.areFavorites() || dir.isRecycleBin()) {
        pinnedDirs.push(dir)
      } else {
        normalDirs.push(dir)
      }
    }
    const result: Directory[] = pinnedDirs.concat(normalDirs)
    return result
  }

  applySearchFilter(): void {
    if (this.searchQuery.length === 0) {
      this.filteredDirs = this.directories
    } else {
      const query: string = this.searchQuery.toLowerCase()
      const result: Directory[] = []
      for (let i: number = 0; i < this.directories.length; i++) {
        const dir: Directory = this.directories[i]
        if (dir.name.toLowerCase().includes(query)) {
          result.push(dir)
        }
      }
      this.filteredDirs = result
    }
    this.dirDataSource.setData(this.filteredDirs)
  }

  handleSortChanged(sorting: number): void {
    const config: ConfigManager = ConfigManager.getInstance()
    config.directorySorting = sorting
    this.currentSorting = sorting
    this.loadDirectories()
  }

  handleFilterChanged(filter: number): void {
    const config: ConfigManager = ConfigManager.getInstance()
    config.filterMedia = filter
    this.currentFilter = filter
    this.loadDirectories()
  }

  changeColumnCount(delta: number): void {
    let newCount: number = this.columnCount + delta
    if (newCount < 1) {
      newCount = 1
    }
    if (newCount > MAX_COLUMN_COUNT) {
      newCount = MAX_COLUMN_COUNT
    }
    this.columnCount = newCount
    const config: ConfigManager = ConfigManager.getInstance()
    config.dirColumnCnt = newCount
  }

  toggleViewType(): void {
    if (this.viewType === VIEW_TYPE_GRID) {
      this.viewType = VIEW_TYPE_LIST
    } else {
      this.viewType = VIEW_TYPE_GRID
    }
    const config: ConfigManager = ConfigManager.getInstance()
    config.viewTypeFolders = this.viewType
  }

  toggleTempShowHidden(): void {
    this.tempShowHidden = !this.tempShowHidden
    const config: ConfigManager = ConfigManager.getInstance()
    config.temporarilyShowHidden = this.tempShowHidden
    this.loadDirectories()
  }

  toggleTempShowExcluded(): void {
    this.tempShowExcluded = !this.tempShowExcluded
    const config: ConfigManager = ConfigManager.getInstance()
    config.temporarilyShowExcluded = this.tempShowExcluded
    this.loadDirectories()
  }

  toggleShowAllMode(): void {
    this.showAllMode = !this.showAllMode
    const config: ConfigManager = ConfigManager.getInstance()
    config.showAll = this.showAllMode
    if (this.showAllMode) {
      this.loadAllMedia()
    } else {
      this.loadDirectories()
    }
  }

  async loadAllMedia(): Promise<void> {
    this.isLoading = true
    try {
      this.scanner = new MediaScanner(this.getUIContext().getHostContext()!)
      const config: ConfigManager = ConfigManager.getInstance()
      const media: Medium[] = await this.scanner.getAllMedia(config.filterMedia)
      this.allMedia = media
      const todayLabel: string = this.getStr($r('app.string.today').id)
      const yesterdayLabel: string = this.getStr($r('app.string.yesterday').id)
      this.dateGroups = groupMediaByDate(media, todayLabel, yesterdayLabel)
      this.isEmpty = media.length === 0
    } catch (e) {
      console.error('Failed to load all media')
    }
    this.isLoading = false
  }

  private navigateToViewing(medium: Medium): void {
    // Find the index of this medium in allMedia
    let selectedIndex: number = 0
    for (let i: number = 0; i < this.allMedia.length; i++) {
      if (this.allMedia[i].path === medium.path) {
        selectedIndex = i
        break
      }
    }

    // Serialize media list for router params
    const serialized: Object[] = []
    for (let i: number = 0; i < this.allMedia.length; i++) {
      const m: Medium = this.allMedia[i]
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
      const navParams: ViewingPageParams = { mediaListJson: JSON.stringify(serialized), selectedIndex: selectedIndex, folderPath: '' }
      router.pushUrl({ url: 'pages/ViewingPage', params: navParams })
    } catch (e) {
      console.error('Navigation to ViewingPage failed')
    }
  }

  // FR-A04: Build overflow menu items for MainPage multi-select CAB
  private buildMultiSelectMenu(): Array<DirMenuItem> {
    const items: Array<DirMenuItem> = []
    // Exclude folder
    items.push({
      value: this.getStr($r('app.string.exclude').id),
      action: (): void => {
        this.excludeSelectedFolders()
      }
    } as DirMenuItem)
    // Hide folder (creates .nomedia)
    items.push({
      value: this.getStr($r('app.string.hide').id),
      action: (): void => {
        this.hideSelectedFolders()
      }
    } as DirMenuItem)
    // Rename — only when single item selected
    if (this.selectedPaths.size === 1) {
      items.push({
        value: this.getStr($r('app.string.rename').id),
        action: (): void => {
          this.renameDialogController.open()
        }
      } as DirMenuItem)
    }
    // Copy to
    items.push({
      value: this.getStr($r('app.string.copy_to').id),
      action: (): void => {
        this.showCopyDialog()
      }
    } as DirMenuItem)
    // Move to
    items.push({
      value: this.getStr($r('app.string.move_to').id),
      action: (): void => {
        this.showMoveDialog()
      }
    } as DirMenuItem)
    return items
  }

  onBackPress(): boolean {
    if (this.isMultiSelectMode) {
      this.exitMultiSelectMode()
      return true
    }
    if (this.isSearching) {
      this.isSearching = false
      this.searchQuery = ''
      this.applySearchFilter()
      return true
    }
    if (this.showAllMode) {
      this.showAllMode = false
      const config: ConfigManager = ConfigManager.getInstance()
      config.showAll = false
      this.loadDirectories()
      return true
    }
    return false
  }

  build() {
    Column() {
      // Title bar
      Row() {
        if (this.isMultiSelectMode) {
          // Multi-select toolbar: ← close + "已选择 N / total" + action buttons
          Image($r('sys.media.ohos_ic_back'))
            .width(24).height(24)
            .onClick(() => {
              this.exitMultiSelectMode()
            })
          Text(`已选择 ${this.getSelectedDirCount()} / ${this.getTotalDirCount()}`)
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.ohos_id_color_text_primary'))
            .margin({ left: 16 })
            .layoutWeight(1)

          // Pin/unpin button
          Button() {
            SymbolGlyph($r('sys.symbol.pin'))
              .fontSize(20)
              .fontColor([$r('sys.color.ohos_id_color_text_primary')])
          }
          .backgroundColor($r('sys.color.ohos_id_color_background_transparent'))
          .width(40)
          .height(40)
          .onClick(() => {
            this.togglePinSelectedFolders()
          })

          // Delete button — system createDeleteRequest shows its own confirmation UI,
          // so we skip our custom dialog to avoid double-popup (BUG-R7-1)
          Button() {
            SymbolGlyph($r('sys.symbol.trash'))
              .fontSize(20)
              .fontColor([$r('sys.color.ohos_id_color_text_primary')])
          }
          .backgroundColor($r('sys.color.ohos_id_color_background_transparent'))
          .width(40)
          .height(40)
          .onClick(() => {
            this.deleteSelectedFolders(false)
          })

          // Select all button
          Text('全选')
            .fontSize(16)
            .fontColor('#007DFF')
            .margin({ right: 4 })
            .onClick(() => {
              this.selectAllDirs()
            })

          // Overflow menu: exclude, rename (single), copy, move (FR-A04)
          Button() {
            SymbolGlyph($r('sys.symbol.dot_grid_2x2'))
              .fontSize(20)
              .fontColor([$r('sys.color.ohos_id_color_text_primary')])
          }
          .backgroundColor($r('sys.color.ohos_id_color_background_transparent'))
          .width(40)
          .height(40)
          .bindMenu(this.buildMultiSelectMenu())
        } else if (this.isSearching) {
          TextInput({ placeholder: $r('app.string.search_folders'), text: this.searchQuery })
            .layoutWeight(1)
            .height(40)
            .onChange((value: string) => {
              this.searchQuery = value
              this.applySearchFilter()
            })

          Button() {
            SymbolGlyph($r('sys.symbol.xmark'))
              .fontSize(20)
              .fontColor([$r('sys.color.ohos_id_color_text_primary')])
          }
          .backgroundColor($r('sys.color.ohos_id_color_background_transparent'))
          .width(40)
          .height(40)
          .onClick(() => {
            this.isSearching = false
            this.searchQuery = ''
            this.applySearchFilter()
          })
        } else {
          Text($r('app.string.app_name'))
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.ohos_id_color_text_primary'))
            .layoutWeight(1)

          // Search button — BUG-035: Navigate to SearchPage for media file search
          Button() {
            SymbolGlyph($r('sys.symbol.magnifyingglass'))
              .fontSize(20)
              .fontColor([$r('sys.color.ohos_id_color_text_primary')])
          }
          .backgroundColor($r('sys.color.ohos_id_color_background_transparent'))
          .width(40)
          .height(40)
          .onClick(() => {
            router.pushUrl({ url: 'pages/SearchPage' })
          })

          // Menu button
          Button() {
            SymbolGlyph($r('sys.symbol.dot_grid_2x2'))
              .fontSize(20)
              .fontColor([$r('sys.color.ohos_id_color_text_primary')])
          }
          .backgroundColor($r('sys.color.ohos_id_color_background_transparent'))
          .width(40)
          .height(40)
          .bindMenu([
            {
              value: this.getStr($r('app.string.show_all').id),
              action: () => {
                this.toggleShowAllMode()
              }
            },
            {
              value: this.getStr($r('app.string.sort').id),
              action: () => {
                this.sortDialogController.open()
              }
            },
            {
              value: this.getStr($r('app.string.filter').id),
              action: () => {
                this.filterDialogController.open()
              }
            },
            {
              value: this.viewType === VIEW_TYPE_GRID ? this.getStr($r('app.string.list_view').id) : this.getStr($r('app.string.grid_view').id),
              action: () => {
                this.toggleViewType()
              }
            },
            {
              value: this.getStr($r('app.string.column_plus').id),
              action: () => {
                this.changeColumnCount(1)
              }
            },
            {
              value: this.getStr($r('app.string.column_minus').id),
              action: () => {
                this.changeColumnCount(-1)
              }
            },
            {
              value: this.tempShowHidden ? this.getStr($r('app.string.hide_hidden_folders').id) : this.getStr($r('app.string.temporarily_show_hidden').id),
              action: () => {
                this.toggleTempShowHidden()
              }
            },
            {
              value: this.tempShowExcluded ? this.getStr($r('app.string.hide_excluded_folders').id) : this.getStr($r('app.string.temporarily_show_excluded').id),
              action: () => {
                this.toggleTempShowExcluded()
              }
            },
            {
              value: this.getStr($r('app.string.excluded_folders_menu').id),
              action: () => {
                router.pushUrl({ url: 'pages/ExcludedFoldersPage' })
              }
            },
            {
              value: this.getStr($r('app.string.settings').id),
              action: () => {
                router.pushUrl({ url: 'pages/SettingsPage' })
              }
            }
          ])
        }
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .alignItems(VerticalAlign.Center)

      if (this.isLoading) {
        LoadingProgress()
          .width(48)
          .height(48)
          .margin({ top: 100 })
      } else if (this.isEmpty) {
        Column() {
          Text($r('app.string.no_media'))
            .fontSize(16)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
            .margin({ top: 100 })
        }
        .width('100%')
      } else if (this.showAllMode) {
        // T-055: Timeline view — all media grouped by date
        Refresh({ refreshing: $$this.isLoading }) {
          List() {
            ForEach(this.dateGroups, (group: DateGroup) => {
              ListItem() {
                Column() {
                  Text(group.title)
                    .fontSize(16)
                    .fontWeight(FontWeight.Bold)
                    .fontColor($r('sys.color.ohos_id_color_text_primary'))
                    .padding({ left: 16, top: 12, bottom: 4 })
                    .width('100%')

                  Grid() {
                    ForEach(group.items, (medium: Medium) => {
                      GridItem() {
                        MediaItem({ medium: medium })
                      }
                      .onClick(() => {
                        this.navigateToViewing(medium)
                      })
                    }, (medium: Medium) => medium.path)
                  }
                  .columnsTemplate('1fr 1fr 1fr')
                  .columnsGap(2)
                  .rowsGap(2)
                  .width('100%')
                }
              }
            }, (group: DateGroup) => group.title)
          }
          .width('100%')
          .layoutWeight(1)
        }
        .onRefreshing(() => {
          this.loadAllMedia()
        })
      } else if (this.isSearching) {
        // During search, disable pull-to-refresh
        if (this.viewType === VIEW_TYPE_GRID) {
          Grid() {
            LazyForEach(this.dirDataSource, (item: Object) => {
              GridItem() {
                DirectoryItem({
                  directory: item as Directory,
                  isMultiSelectMode: this.isMultiSelectMode,
                  isSelected: this.selectedPaths.has((item as Directory).path)
                })
              }
              .gesture(
                GestureGroup(GestureMode.Exclusive,
                  LongPressGesture({ repeat: false, duration: 500 })
                    .onAction(() => {
                      if (!this.isMultiSelectMode) {
                        this.enterMultiSelectMode(item as Directory)
                      }
                    }),
                  TapGesture()
                    .onAction(() => {
                      if (this.isMultiSelectMode) {
                        this.toggleDirSelection(item as Directory)
                      } else {
                        this.navigateToFolder((item as Directory).path, (item as Directory).name)
                      }
                    })
                )
              )
            }, (item: Object) => (item as Directory).path + '_' + (item as Directory).mediaCnt.toString())
          }
          .columnsTemplate(this.buildColumnsTemplate())
          .columnsGap(2)
          .rowsGap(2)
          .width('100%')
          .layoutWeight(1)
          .cachedCount(3)
        } else {
          List() {
            LazyForEach(this.dirDataSource, (item: Object) => {
              ListItem() {
                DirectoryItem({
                  directory: item as Directory,
                  isListMode: true,
                  isMultiSelectMode: this.isMultiSelectMode,
                  isSelected: this.selectedPaths.has((item as Directory).path)
                })
              }
              .gesture(
                GestureGroup(GestureMode.Exclusive,
                  LongPressGesture({ repeat: false, duration: 500 })
                    .onAction(() => {
                      if (!this.isMultiSelectMode) {
                        this.enterMultiSelectMode(item as Directory)
                      }
                    }),
                  TapGesture()
                    .onAction(() => {
                      if (this.isMultiSelectMode) {
                        this.toggleDirSelection(item as Directory)
                      } else {
                        this.navigateToFolder((item as Directory).path, (item as Directory).name)
                      }
                    })
                )
              )
            }, (item: Object) => (item as Directory).path + '_' + (item as Directory).mediaCnt.toString())
          }
          .width('100%')
          .layoutWeight(1)
          .cachedCount(3)
        }
      } else {
        Refresh({ refreshing: $$this.isLoading }) {
          if (this.viewType === VIEW_TYPE_GRID) {
            Grid() {
              LazyForEach(this.dirDataSource, (item: Object) => {
                GridItem() {
                  DirectoryItem({
                    directory: item as Directory,
                    isMultiSelectMode: this.isMultiSelectMode,
                    isSelected: this.selectedPaths.has((item as Directory).path)
                  })
                }
                // PIT-039c: Use GestureGroup(Exclusive) to prevent child onClick from intercepting long press
                .gesture(
                  GestureGroup(GestureMode.Exclusive,
                    LongPressGesture({ repeat: false, duration: 500 })
                      .onAction(() => {
                        if (!this.isMultiSelectMode) {
                          this.enterMultiSelectMode(item as Directory)
                        }
                      }),
                    TapGesture()
                      .onAction(() => {
                        if (this.isMultiSelectMode) {
                          this.toggleDirSelection(item as Directory)
                        } else {
                          this.navigateToFolder((item as Directory).path, (item as Directory).name)
                        }
                      })
                  )
                )
              }, (item: Object) => (item as Directory).path + '_' + (item as Directory).mediaCnt.toString())
            }
            .columnsTemplate(this.buildColumnsTemplate())
            .columnsGap(2)
            .rowsGap(2)
            .width('100%')
            .layoutWeight(1)
            .cachedCount(3)
          } else {
            List() {
              LazyForEach(this.dirDataSource, (item: Object) => {
                ListItem() {
                  DirectoryItem({
                    directory: item as Directory,
                    isListMode: true,
                    isMultiSelectMode: this.isMultiSelectMode,
                    isSelected: this.selectedPaths.has((item as Directory).path)
                  })
                }
                // PIT-039c: Use GestureGroup(Exclusive) to prevent child onClick from intercepting long press
                .gesture(
                  GestureGroup(GestureMode.Exclusive,
                    LongPressGesture({ repeat: false, duration: 500 })
                      .onAction(() => {
                        if (!this.isMultiSelectMode) {
                          this.enterMultiSelectMode(item as Directory)
                        }
                      }),
                    TapGesture()
                      .onAction(() => {
                        if (this.isMultiSelectMode) {
                          this.toggleDirSelection(item as Directory)
                        } else {
                          this.navigateToFolder((item as Directory).path, (item as Directory).name)
                        }
                      })
                  )
                )
              }, (item: Object) => (item as Directory).path + '_' + (item as Directory).mediaCnt.toString())
            }
            .width('100%')
            .layoutWeight(1)
            .cachedCount(3)
          }
        }
        .onRefreshing(() => {
          this.loadDirectories()
        })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_background'))
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
